import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:app_for_android_a_and_ios/pages/level_test_page.dart';
import 'package:app_for_android_a_and_ios/services/motion_service.dart';

void main() {
  testWidgets(
    'waiting, fresh, stale and recovered gravity states',
    (tester) async {
      final StreamController<MotionSample> gravity =
          StreamController<MotionSample>();
      final StreamController<MotionSample> gyro =
          StreamController<MotionSample>();
      await tester.pumpWidget(
        MaterialApp(
          home: LevelTestPage(
            accelerometerStream: gravity.stream,
            gyroscopeStream: gyro.stream,
          ),
        ),
      );
      expect(find.text('水平'), findsNothing);
      expect(find.text('等待传感器数据'), findsOneWidget);
      FilledButton calibration() => tester.widget<FilledButton>(
        find.widgetWithText(FilledButton, '校准当前位置'),
      );
      expect(calibration().onPressed, isNull);
      gravity.add(const MotionSample(x: 0, y: 0, z: -9.80665));
      await tester.pump();
      expect(find.text('水平'), findsOneWidget);
      expect(calibration().onPressed, isNotNull);
      gyro.addError(StateError('no gyroscope'));
      await tester.pump();
      expect(find.text('水平'), findsOneWidget);
      await tester.pump(const Duration(seconds: 3));
      expect(find.text('水平'), findsNothing);
      expect(find.text('传感器不可用'), findsOneWidget);
      expect(calibration().onPressed, isNull);
      gravity.add(const MotionSample(x: 3, y: 0, z: -9));
      await tester.pump();
      expect(find.text('未水平'), findsOneWidget);
      await tester.tap(find.text('校准当前位置'));
      await tester.pump();
      expect(find.text('水平'), findsOneWidget);
      gravity.addError(StateError('disconnected'));
      await tester.pump();
      expect(find.text('水平'), findsNothing);
      await tester.pumpWidget(const SizedBox.shrink());
      unawaited(gravity.close());
      unawaited(gyro.close());
      await tester.pump();
    },
    timeout: const Timeout(Duration(seconds: 15)),
  );

  testWidgets(
    'no initial sample times out without reporting level',
    (tester) async {
      final StreamController<MotionSample> stream =
          StreamController<MotionSample>.broadcast();
      await tester.pumpWidget(
        MaterialApp(
          home: LevelTestPage(
            accelerometerStream: stream.stream,
            gyroscopeStream: stream.stream,
          ),
        ),
      );
      await tester.pump(const Duration(seconds: 3));
      expect(find.text('水平'), findsNothing);
      expect(find.text('传感器不可用'), findsOneWidget);
      await tester.pumpWidget(const SizedBox.shrink());
      unawaited(stream.close());
      await tester.pump();
    },
    timeout: const Timeout(Duration(seconds: 15)),
  );
}
