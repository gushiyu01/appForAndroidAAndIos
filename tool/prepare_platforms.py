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


ANDROID_ACTIVITY = """package com.gushiyu01.app_for_android_a_and_ios

import android.content.Context
import android.hardware.Sensor
import android.hardware.SensorEvent
import android.hardware.SensorEventListener
import android.hardware.SensorManager
import io.flutter.embedding.android.FlutterFragmentActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.EventChannel

class MainActivity : FlutterFragmentActivity() {
    private var sensorManager: SensorManager? = null

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        sensorManager = getSystemService(Context.SENSOR_SERVICE) as SensorManager

        EventChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            "app_for_android_a_and_ios/accelerometer",
        ).setStreamHandler(sensorHandler(Sensor.TYPE_ACCELEROMETER))

        EventChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            "app_for_android_a_and_ios/gyroscope",
        ).setStreamHandler(sensorHandler(Sensor.TYPE_GYROSCOPE))
    }

    private fun sensorHandler(sensorType: Int): EventChannel.StreamHandler {
        return object : EventChannel.StreamHandler {
            private var listener: SensorEventListener? = null

            override fun onListen(arguments: Any?, events: EventChannel.EventSink?) {
                val manager = sensorManager
                val sensor = manager?.getDefaultSensor(sensorType)
                if (manager == null || sensor == null) {
                    events?.error("SENSOR_UNAVAILABLE", "The requested sensor is unavailable", null)
                    return
                }

                val newListener = object : SensorEventListener {
                    override fun onSensorChanged(event: SensorEvent) {
                        events?.success(
                            mapOf(
                                "x" to event.values[0].toDouble(),
                                "y" to event.values[1].toDouble(),
                                "z" to event.values[2].toDouble(),
                            ),
                        )
                    }

                    override fun onAccuracyChanged(sensor: Sensor?, accuracy: Int) {}
                }

                listener = newListener
                manager.registerListener(newListener, sensor, SensorManager.SENSOR_DELAY_UI)
            }

            override fun onCancel(arguments: Any?) {
                listener?.let { currentListener ->
                    sensorManager?.unregisterListener(currentListener)
                }
                listener = null
            }
        }
    }
}
"""


IOS_APP_DELEGATE = """import UIKit
import Flutter
import CoreMotion

@main
@objc class AppDelegate: FlutterAppDelegate {
    private let motionManager = CMMotionManager()

    override func application(
        _ application: UIApplication,
        didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
    ) -> Bool {
        guard let controller = window?.rootViewController as? FlutterViewController else {
            return super.application(application, didFinishLaunchingWithOptions: launchOptions)
        }

        GeneratedPluginRegistrant.register(with: self)
        registerMotionChannels(with: controller.binaryMessenger)
        return super.application(application, didFinishLaunchingWithOptions: launchOptions)
    }

    private func registerMotionChannels(with messenger: FlutterBinaryMessenger) {
        let gravityScale = 9.80665
        motionManager.deviceMotionUpdateInterval = 1.0 / 30.0

        EventChannel(name: "app_for_android_a_and_ios/accelerometer", binaryMessenger: messenger)
            .setStreamHandler(MotionStreamHandler { motion in
                [
                    "x": motion.gravity.x * gravityScale,
                    "y": motion.gravity.y * gravityScale,
                    "z": motion.gravity.z * gravityScale,
                ]
            })

        EventChannel(name: "app_for_android_a_and_ios/gyroscope", binaryMessenger: messenger)
            .setStreamHandler(MotionStreamHandler { motion in
                [
                    "x": motion.rotationRate.x,
                    "y": motion.rotationRate.y,
                    "z": motion.rotationRate.z,
                ]
            })

        motionManager.startDeviceMotionUpdates(to: .main) { _, _ in }
    }
}

private final class MotionStreamHandler: NSObject, FlutterStreamHandler {
    private let values: (CMDeviceMotion) -> [String: Double]
    private var listening = false

    init(values: @escaping (CMDeviceMotion) -> [String: Double]) {
        self.values = values
    }

    func onListen(
        withArguments arguments: Any?,
        eventSink events: @escaping FlutterEventSink
    ) -> FlutterError? {
        listening = true

        if let appDelegate = UIApplication.shared.delegate as? AppDelegate {
            appDelegate.motionManager.startDeviceMotionUpdates(to: .main) { motion, error in
                guard error == nil, let motion else { return }
                events(self.values(motion))
            }
        }

        return nil
    }

    func onCancel(withArguments arguments: Any?) -> FlutterError? {
        if let appDelegate = UIApplication.shared.delegate as? AppDelegate {
            appDelegate.motionManager.stopDeviceMotionUpdates()
        }
        listening = false
        return nil
    }
}
"""


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
    activity_path.write_text(ANDROID_ACTIVITY, encoding="utf-8")

    app_delegate_path = ROOT / "ios" / "Runner" / "AppDelegate.swift"
    app_delegate_path.write_text(IOS_APP_DELEGATE, encoding="utf-8")


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
    write_motion_channels()
    add_ios_usage_descriptions()


if __name__ == "__main__":
    main()
