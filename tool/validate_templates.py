from pathlib import Path


ROOT = Path(__file__).resolve().parent.parent


def require(path: Path, fragments: list[str]) -> None:
    source = path.read_text(encoding="utf-8")
    for fragment in fragments:
        if fragment not in source:
            raise ValueError(f"{path.relative_to(ROOT)} is missing: {fragment}")


def main() -> None:
    require(
        ROOT / "tool" / "templates" / "android" / "MainActivity.kt",
        [
            "io.flutter.embedding.android.FlutterFragmentActivity",
            "io.flutter.plugin.common.EventChannel",
            "app_for_android_a_and_ios/accelerometer",
            "app_for_android_a_and_ios/gyroscope",
            "Sensor.TYPE_ACCELEROMETER",
            "Sensor.TYPE_GYROSCOPE",
        ],
    )
    require(
        ROOT / "tool" / "templates" / "ios" / "AppDelegate.swift",
        [
            "@main",
            "import Flutter",
            "import CoreMotion",
            "FlutterEventChannel",
            "FlutterStreamHandler",
            "CMMotionManager",
            "app_for_android_a_and_ios/accelerometer",
            "app_for_android_a_and_ios/gyroscope",
            "motion.gravity",
            "motion.rotationRate",
        ],
    )
    require(
        ROOT / "lib" / "services" / "motion_service.dart",
        [
            "app_for_android_a_and_ios/accelerometer",
            "app_for_android_a_and_ios/gyroscope",
        ],
    )


if __name__ == "__main__":
    main()
