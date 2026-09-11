import importlib.util
from pathlib import Path
import plistlib
import shutil
import tempfile
import unittest
from unittest.mock import patch

ROOT = Path(__file__).resolve().parents[2]


def load(name):
    spec = importlib.util.spec_from_file_location(name, ROOT / "tool" / f"{name}.py")
    module = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(module)
    return module


prepare = load("prepare_platforms")
validator = load("validate_templates")


class PlatformTests(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory()
        self.addCleanup(self.temp.cleanup)
        self.root = Path(self.temp.name)
        shutil.copytree(ROOT / "tool/templates", self.root / "tool/templates")
        service = self.root / "lib/services"
        service.mkdir(parents=True)
        shutil.copyfile(ROOT / "lib/services/motion_service.dart", service / "motion_service.dart")
        self.write("android/app/src/main/AndroidManifest.xml",
                   '<manifest xmlns:android="http://schemas.android.com/apk/res/android">\n'
                   '\t<application android:label="test"/>\n</manifest>')
        self.write("android/gradle.properties",
                   "android.builtInKotlin=true\nandroid.newDsl=true\norg.gradle.jvmargs=-Xmx4G\n")
        self.write("android/app/src/main/kotlin/com/gushiyu01/app_for_android_a_and_ios/MainActivity.kt", "")
        self.write("ios/Runner/AppDelegate.swift", "")
        self.write("ios/Runner/SceneDelegate.swift", "class SceneDelegate: FlutterSceneDelegate {}")
        self.info = {
            "CFBundleName": "fixture",
            "UIApplicationSceneManifest": {"UISceneConfigurations": {
                "UIWindowSceneSessionRoleApplication": [
                    {"UISceneDelegateClassName": "$(PRODUCT_MODULE_NAME).SceneDelegate"}
                ]
            }}
        }
        self.write_info()

    def write(self, name, text):
        path = self.root / name
        path.parent.mkdir(parents=True, exist_ok=True)
        path.write_text(text, encoding="utf-8")

    def write_info(self):
        with (self.root / "ios/Runner/Info.plist").open("wb") as file:
            plistlib.dump(self.info, file)

    def prepare(self):
        with patch.object(prepare, "ROOT", self.root), patch.object(prepare, "TEMPLATES", self.root / "tool/templates"):
            prepare.main()

    def test_preparation_is_idempotent_and_validates_generated_files(self):
        self.prepare()
        before = {str(p.relative_to(self.root)): p.read_bytes()
                  for p in self.root.rglob("*") if p.is_file()}
        self.prepare()
        after = {str(p.relative_to(self.root)): p.read_bytes()
                 for p in self.root.rglob("*") if p.is_file()}
        self.assertEqual(before, after)
        validator.validate(self.root, generated=True)
        properties = (self.root / "android/gradle.properties").read_text()
        self.assertNotIn("=true", properties)
        self.assertIn("org.gradle.jvmargs=-Xmx4G", properties)
        with (self.root / "ios/Runner/Info.plist").open("rb") as file:
            self.assertEqual(plistlib.load(file)["CFBundleName"], "fixture")

    def test_rejects_stale_native_copy(self):
        self.prepare()
        self.write("ios/Runner/AppDelegate.swift", "old launch code")
        with self.assertRaisesRegex(ValueError, "differs from template"):
            validator.validate(self.root, generated=True)

    def test_rejects_missing_scene_configuration(self):
        self.info.pop("UIApplicationSceneManifest")
        self.write_info()
        self.prepare()
        with self.assertRaisesRegex(ValueError, "UIScene"):
            validator.validate(self.root, generated=True)

    def test_rejects_missing_usage_description(self):
        self.prepare()
        self.write_info()
        with self.assertRaisesRegex(ValueError, "usage description"):
            validator.validate(self.root, generated=True)

    def test_rejects_missing_application(self):
        self.write("android/app/src/main/AndroidManifest.xml", "<manifest/>")
        with self.assertRaisesRegex(ValueError, "application"):
            self.prepare()

    def test_rejects_legacy_window_registration(self):
        path = self.root / "tool/templates/ios/AppDelegate.swift"
        path.write_text(path.read_text() + "\n// rootViewController", encoding="utf-8")
        with self.assertRaisesRegex(ValueError, "launch-time window"):
            validator.validate(self.root)


if __name__ == "__main__":
    unittest.main()
