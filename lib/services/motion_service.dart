import 'package:flutter/services.dart';

class MotionSample {
  const MotionSample({required this.x, required this.y, required this.z});

  final double x;
  final double y;
  final double z;

  factory MotionSample.fromEvent(Object? event) {
    if (event is! Map<Object?, Object?>) {
      throw const FormatException('Invalid motion event');
    }

    double axis(String name) {
      final Object? value = event[name];
      if (value is! num || !value.toDouble().isFinite) {
        throw FormatException('Invalid motion axis: $name');
      }
      return value.toDouble();
    }

    return MotionSample(x: axis('x'), y: axis('y'), z: axis('z'));
  }
}

/// Physical gravity in m/s²: +X right, +Y device top, +Z out of screen.
/// A stationary, face-up phone reports approximately (0, 0, -9.80665).
/// The legacy channel name is retained for native compatibility.
Stream<MotionSample> accelerometerEventStream() {
  return const EventChannel(
    'app_for_android_a_and_ios/accelerometer',
  ).receiveBroadcastStream().map(MotionSample.fromEvent);
}

Stream<MotionSample> gyroscopeEventStream() {
  return const EventChannel(
    'app_for_android_a_and_ios/gyroscope',
  ).receiveBroadcastStream().map(MotionSample.fromEvent);
}
