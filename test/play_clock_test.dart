import 'package:flutter_test/flutter_test.dart';
import 'package:app_for_android_a_and_ios/models/play_clock.dart';

void main() {
  test('excludes paused time and does not double-count repeated pauses', () {
    Duration now = Duration.zero;
    final PlayClock clock = PlayClock(now: () => now);
    clock.resume();
    now += const Duration(seconds: 10);
    clock.pause();
    now += const Duration(seconds: 60);
    clock.pause();
    expect(clock.elapsed, const Duration(seconds: 10));
    clock.resume();
    clock.resume();
    now += const Duration(seconds: 1);
    expect(clock.elapsed, const Duration(seconds: 11));
    clock.reset();
    expect(clock.elapsed, Duration.zero);
    expect(clock.isRunning, isFalse);
  });
}
