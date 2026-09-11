import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:app_for_android_a_and_ios/models/play_clock.dart';
import 'package:app_for_android_a_and_ios/pages/maze_game_page.dart';
import 'package:app_for_android_a_and_ios/services/motion_service.dart';

void main() {
  testWidgets(
    'settings and background pause the clock without undoing user pause',
    (tester) async {
      Duration now = Duration.zero;
      final PlayClock clock = PlayClock(now: () => now);
      final StreamController<MotionSample> stream =
          StreamController<MotionSample>();
      await tester.pumpWidget(
        MaterialApp(
          home: MazeGamePage(accelerometerStream: stream.stream, clock: clock),
        ),
      );
      await tester.pump(const Duration(milliseconds: 300));
      expect(clock.isRunning, isFalse);
      await tester.tap(find.text('开始游戏'));
      await tester.pump(const Duration(milliseconds: 300));
      expect(clock.isRunning, isTrue);
      now += const Duration(seconds: 10);
      await tester.tap(find.byIcon(Icons.settings_rounded));
      await tester.pump(const Duration(milliseconds: 300));
      expect(clock.isRunning, isFalse);
      now += const Duration(seconds: 60);
      await tester.tap(find.text('取消'));
      await tester.pump(const Duration(milliseconds: 300));
      expect(clock.elapsed, const Duration(seconds: 10));
      expect(clock.isRunning, isTrue);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
      await tester.pump();
      now += const Duration(seconds: 30);
      expect(clock.isRunning, isFalse);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await tester.pump();
      now += const Duration(seconds: 1);
      expect(clock.elapsed, const Duration(seconds: 11));
      await tester.ensureVisible(find.text('暂停'));
      await tester.tap(find.text('暂停'));
      await tester.pump();
      expect(clock.isRunning, isFalse);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await tester.pump();
      expect(clock.isRunning, isFalse);
      await tester.pumpWidget(const SizedBox.shrink());
      unawaited(stream.close());
      await tester.pump();
    },
  );
}
