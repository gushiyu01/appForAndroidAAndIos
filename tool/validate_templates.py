"""Fast template contract checks; optionally validate CI-generated projects."""
import argparse
from pathlib import Path
import plistlib
import xml.etree.ElementTree as ET

ROOT = Path(__file__).resolve().parent.parent


def require(path: Path, fragments: list[str]) -> None:
    source = path.read_text(encoding="utf-8")
    for fragment in fragments:
        if fragment not in source:
            raise ValueError(f"{path} is missing: {fragment}")


def validate(root: Path = ROOT, *, generated: bool = False) -> None:
    android = root / "tool/templates/android/MainActivity.kt"
    ios = root / "tool/templates/ios/AppDelegate.swift"
    channels = ["app_for_android_a_and_ios/accelerometer",
                "app_for_android_a_and_ios/gyroscope"]
    require(android, channels + [
        "io.flutter.embedding.android.FlutterFragmentActivity",
        "io.flutter.plugin.common.EventChannel", "Sensor.TYPE_ACCELEROMETER",
        "Sensor.TYPE_GRAVITY", "Sensor.TYPE_GYROSCOPE", "-values[axis]",
        "SENSOR_UNAVAILABLE", "unregisterListener",
    ])
    require(ios, channels + [
        "@main", "import Flutter", "import CoreMotion", "FlutterEventChannel",
        "FlutterStreamHandler", "CMMotionManager", "motion.gravity",
        "motion.rotationRate", "FlutterImplicitEngineDelegate",
        "didInitializeImplicitFlutterEngine", "engineBridge.pluginRegistry",
        "engineBridge.applicationRegistrar.messenger()", "isDeviceMotionAvailable",
        "SENSOR_UNAVAILABLE", "SENSOR_ERROR", "stopDeviceMotionUpdates",
    ])
    if "rootViewController" in ios.read_text(encoding="utf-8"):
        raise ValueError("Do not register iOS channels through the launch-time window")
    require(root / "lib/services/motion_service.dart", channels)
    if not generated:
        return

    copies = [
        (android, root / "android/app/src/main/kotlin/com/gushiyu01/app_for_android_a_and_ios/MainActivity.kt"),
        (ios, root / "ios/Runner/AppDelegate.swift"),
    ]
    for template, output in copies:
        if template.read_bytes() != output.read_bytes():
            raise ValueError(f"Generated file differs from template: {output}")

    document = ET.parse(root / "android/app/src/main/AndroidManifest.xml").getroot()
    names = [item.get("{http://schemas.android.com/apk/res/android}name")
             for item in document.findall("uses-permission")]
    for name in ["android.permission.USE_BIOMETRIC", "android.permission.USE_FINGERPRINT"]:
        if names.count(name) != 1:
            raise ValueError(f"Expected exactly one permission: {name}")
    require(root / "android/gradle.properties",
            ["android.builtInKotlin=false", "android.newDsl=false"])
    with (root / "ios/Runner/Info.plist").open("rb") as file:
        info = plistlib.load(file)
    for key in ["NSCameraUsageDescription", "NSFaceIDUsageDescription", "NSMotionUsageDescription"]:
        if not isinstance(info.get(key), str) or not info[key].strip():
            raise ValueError(f"Missing iOS usage description: {key}")
    configurations = info.get("UIApplicationSceneManifest", {}).get("UISceneConfigurations", {})
    scenes = configurations.get("UIWindowSceneSessionRoleApplication", [])
    if not any(item.get("UISceneDelegateClassName") == "$(PRODUCT_MODULE_NAME).SceneDelegate"
               for item in scenes):
        raise ValueError("Expected the Flutter UIScene configuration")
    require(root / "ios/Runner/SceneDelegate.swift", ["FlutterSceneDelegate"])


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--generated", action="store_true",
                        help="Also check native projects created by flutter create")
    args = parser.parse_args()
    validate(generated=args.generated)
    print("Platform validation passed" + (" (including generated files)" if args.generated else ""))


if __name__ == "__main__":
    main()
