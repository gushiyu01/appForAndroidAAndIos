import UIKit
import Flutter
import CoreMotion

@main
@objc class AppDelegate: FlutterAppDelegate, FlutterImplicitEngineDelegate {
    func didInitializeImplicitFlutterEngine(_ engineBridge: FlutterImplicitEngineBridge) {
        GeneratedPluginRegistrant.register(with: engineBridge.pluginRegistry)
        registerMotionChannels(with: engineBridge.applicationRegistrar.messenger())
    }

    private func registerMotionChannels(with messenger: FlutterBinaryMessenger) {
        let gravityScale = 9.80665

        FlutterEventChannel(
            name: "app_for_android_a_and_ios/accelerometer",
            binaryMessenger: messenger,
        ).setStreamHandler(
            MotionStreamHandler { motion in
                [
                    "x": motion.gravity.x * gravityScale,
                    "y": motion.gravity.y * gravityScale,
                    "z": motion.gravity.z * gravityScale,
                ]
            },
        )

        FlutterEventChannel(
            name: "app_for_android_a_and_ios/gyroscope",
            binaryMessenger: messenger,
        ).setStreamHandler(
            MotionStreamHandler { motion in
                [
                    "x": motion.rotationRate.x,
                    "y": motion.rotationRate.y,
                    "z": motion.rotationRate.z,
                ]
            },
        )
    }
}

private final class MotionStreamHandler: NSObject, FlutterStreamHandler {
    private let values: (CMDeviceMotion) -> [String: Double]
    private let motionManager = CMMotionManager()

    init(values: @escaping (CMDeviceMotion) -> [String: Double]) {
        self.values = values
    }

    func onListen(
        withArguments arguments: Any?,
        eventSink events: @escaping FlutterEventSink
    ) -> FlutterError? {
        guard motionManager.isDeviceMotionAvailable else {
            return FlutterError(
                code: "SENSOR_UNAVAILABLE",
                message: "Device motion is unavailable",
                details: nil
            )
        }
        motionManager.deviceMotionUpdateInterval = 1.0 / 30.0
        motionManager.startDeviceMotionUpdates(to: .main) { [weak self] motion, error in
            guard let self else { return }
            if let error {
                events(FlutterError(
                    code: "SENSOR_ERROR",
                    message: error.localizedDescription,
                    details: nil
                ))
                self.motionManager.stopDeviceMotionUpdates()
                return
            }
            guard let motion else { return }
            events(self.values(motion))
        }

        return nil
    }

    func onCancel(withArguments arguments: Any?) -> FlutterError? {
        motionManager.stopDeviceMotionUpdates()
        return nil
    }
}
