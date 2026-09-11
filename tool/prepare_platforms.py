from pathlib import Path
import plistlib
import re
import xml.etree.ElementTree as ET


ROOT = Path(__file__).resolve().parent.parent
TEMPLATES = ROOT / "tool" / "templates"


def add_android_permissions() -> None:
    manifest_path = (
        ROOT
        / "android"
        / "app"
        / "src"
        / "main"
        / "AndroidManifest.xml"
    )
    manifest = manifest_path.read_text(encoding="utf-8")
    namespace = "{http://schemas.android.com/apk/res/android}"
    document = ET.fromstring(manifest)
    existing = {
        item.get(namespace + "name")
        for item in document.findall("uses-permission")
    }
    permissions = [
        "android.permission.USE_BIOMETRIC",
        "android.permission.USE_FINGERPRINT",
    ]
    additions = "".join(
        f'    <uses-permission android:name="{permission}" />\n'
        for permission in permissions if permission not in existing
    )
    if additions:
        manifest, count = re.subn(r"(?m)^[ \t]*<application\b",
                                  additions + "    <application", manifest, count=1)
        if count != 1:
            raise ValueError("Generated manifest has no application element")
        ET.fromstring(manifest)
        manifest_path.write_text(manifest, encoding="utf-8")


def ensure_legacy_kotlin_settings() -> None:
    # Keep the template's compatibility switches explicit for Flutter
    # versions that may enable built-in Kotlin by default.
    properties_path = ROOT / "android" / "gradle.properties"
    properties = properties_path.read_text(encoding="utf-8")
    required_properties = {
        "android.builtInKotlin": "false",
        "android.newDsl": "false",
    }
    lines = properties.splitlines()
    for name, value in required_properties.items():
        pattern = re.compile(r"^\s*" + re.escape(name) + r"\s*[=:]")
        lines = [line for line in lines if not pattern.match(line)]
        lines.append(f"{name}={value}")
    properties_path.write_text("\n".join(lines) + "\n", encoding="utf-8")


def write_motion_channels() -> None:
    activity_path = (
        ROOT
        / "android"
        / "app"
        / "src"
        / "main"
        / "kotlin"
        / "com"
        / "gushiyu01"
        / "app_for_android_a_and_ios"
        / "MainActivity.kt"
    )
    activity_path.write_text(
        (TEMPLATES / "android" / "MainActivity.kt").read_text(
            encoding="utf-8",
        ),
        encoding="utf-8",
    )

    app_delegate_path = ROOT / "ios" / "Runner" / "AppDelegate.swift"
    app_delegate_path.write_text(
        (TEMPLATES / "ios" / "AppDelegate.swift").read_text(
            encoding="utf-8",
        ),
        encoding="utf-8",
    )


def add_ios_usage_descriptions() -> None:
    info_plist_path = ROOT / "ios" / "Runner" / "Info.plist"
    with info_plist_path.open("rb") as file:
        info_plist = plistlib.load(file)

    info_plist["NSCameraUsageDescription"] = "需要访问相机以拍摄照片。"
    info_plist["NSFaceIDUsageDescription"] = "需要使用系统生物识别解锁应用。"
    info_plist["NSMotionUsageDescription"] = "需要读取运动传感器以进行水平测试和重力迷宫游戏。"

    with info_plist_path.open("wb") as file:
        plistlib.dump(info_plist, file, fmt=plistlib.FMT_XML)


def main() -> None:
    add_android_permissions()
    ensure_legacy_kotlin_settings()
    write_motion_channels()
    add_ios_usage_descriptions()


if __name__ == "__main__":
    main()
