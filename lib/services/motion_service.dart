import 'package:flutter/services.dart';

class MotionSample {
  const MotionSample({
    required this.x,
    required this.y,
    required this.z,
  });

  final double x;
  final double y;
  final double z;

  factory MotionSample.fromEvent(Object? event) {
    if (event is! Map<Object?, Object?>) {
      throw const FormatException('Invalid motion event');
    }

    return MotionSample(
      x: (event['x'] as num?)?.toDouble() ?? 0,
      y: (event['y'] as num?)?.toDouble() ?? 0,
      z: (event['z'] as num?)?.toDouble() ?? 0,
    );
  }
}

Stream<MotionSample> accelerometerEventStream() {
  return const EventChannel('app_for_android_a_and_ios/accelerometer')
      .receiveBroadcastStream()
      .map(MotionSample.fromEvent);
}

Stream<MotionSample> gyroscopeEventStream() {
  return const EventChannel('app_for_android_a_and_ios/gyroscope')
      .receiveBroadcastStream()
      .map(MotionSample.fromEvent);
}
