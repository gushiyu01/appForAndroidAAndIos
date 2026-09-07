from pathlib import Path
import plistlib


ROOT = Path(__file__).resolve().parent.parent


def add_android_permissions() -> None:
    manifest_path = ROOT / "android" / "app" / "src" / "main" / "AndroidManifest.xml"
    manifest = manifest_path.read_text(encoding="utf-8")
    permissions = [
        "android.permission.USE_BIOMETRIC",
        "android.permission.USE_FINGERPRINT",
    ]
    additions = "".join(
        f'    <uses-permission android:name="{permission}" />\n'
        for permission in permissions
        if permission not in manifest
    )
    if additions:
        manifest = manifest.replace("    <application", additions + "    <application", 1)
        manifest_path.write_text(manifest, encoding="utf-8")


def use_fragment_activity() -> None:
    for activity_path in (ROOT / "android").rglob("MainActivity.kt"):
        source = activity_path.read_text(encoding="utf-8")
        source = source.replace(
            "io.flutter.embedding.android.FlutterActivity",
            "io.flutter.embedding.android.FlutterFragmentActivity",
        )
        activity_path.write_text(source, encoding="utf-8")


def disable_built_in_kotlin() -> None:
    # sensors_plus 7.1 still applies KGP, which is incompatible with
    # Flutter 3.47's experimental built-in Kotlin Android setup.
    properties_path = ROOT / "android" / "gradle.properties"
    properties = properties_path.read_text(encoding="utf-8")
    required_properties = {
        "android.builtInKotlin": "false",
        "android.newDsl": "false",
    }
    updates = []
    for name, value in required_properties.items():
        prefix = f"{name}="
        if any(line.startswith(prefix) for line in properties.splitlines()):
            continue
        updates.append(f"{prefix}{value}")

    if updates:
        if properties and not properties.endswith("\n"):
            properties += "\n"
        properties += "\n".join(updates) + "\n"
        properties_path.write_text(properties, encoding="utf-8")


def add_ios_usage_descriptions() -> None:
    info_plist_path = ROOT / "ios" / "Runner" / "Info.plist"
    with info_plist_path.open("rb") as file:
        info_plist = plistlib.load(file)

    info_plist["NSCameraUsageDescription"] = "需要访问相机以拍摄照片。"
    info_plist["NSFaceIDUsageDescription"] = "需要使用系统生物识别解锁应用。"

    with info_plist_path.open("wb") as file:
        plistlib.dump(info_plist, file, fmt=plistlib.FMT_XML)


def main() -> None:
    add_android_permissions()
    use_fragment_activity()
    disable_built_in_kotlin()
    add_ios_usage_descriptions()


if __name__ == "__main__":
    main()
