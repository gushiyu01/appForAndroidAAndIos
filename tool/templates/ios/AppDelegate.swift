import UIKit
import Flutter
import CoreMotion

@main
@objc class AppDelegate: FlutterAppDelegate {
    override func application(
        _ application: UIApplication,
        didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
    ) -> Bool {
        guard let controller = window?.rootViewController as? FlutterViewController else {
            return super.application(
                application,
                didFinishLaunchingWithOptions: launchOptions,
            )
        }

        GeneratedPluginRegistrant.register(with: self)
        registerMotionChannels(with: controller.binaryMessenger)
        return super.application(
            application,
            didFinishLaunchingWithOptions: launchOptions,
        )
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
        motionManager.deviceMotionUpdateInterval = 1.0 / 30.0
        motionManager.startDeviceMotionUpdates(to: .main) { motion, error in
            guard error == nil, let motion else { return }
            events(self.values(motion))
        }

        return nil
    }

    func onCancel(withArguments arguments: Any?) -> FlutterError? {
        motionManager.stopDeviceMotionUpdates()
        return nil
    }
}
