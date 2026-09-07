import 'package:flutter_test/flutter_test.dart';

import 'package:app_for_android_a_and_ios/services/motion_service.dart';

void main() {
  test('parses numeric native motion events', () {
    final MotionSample sample = MotionSample.fromEvent(<Object?, Object?>{
      'x': 1,
      'y': 2.5,
      'z': -0.25,
    });

    expect(sample.x, 1);
    expect(sample.y, 2.5);
    expect(sample.z, -0.25);
  });

  test('rejects invalid native motion events', () {
    expect(
      () => MotionSample.fromEvent(<String>[]),
      throwsFormatException,
    );
  });
}
