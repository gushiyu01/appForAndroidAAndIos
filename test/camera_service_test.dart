import 'dart:async';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image_picker/image_picker.dart';
import 'package:app_for_android_a_and_ios/services/camera_service.dart';

class FakePicker extends ImagePicker {
  LostDataResponse lost = LostDataResponse.empty();
  XFile? next;
  bool failRecovery = false;
  bool failCapture = false;
  int recoveries = 0;
  Completer<LostDataResponse>? pendingRecovery;

  @override
  Future<LostDataResponse> retrieveLostData() async {
    recoveries++;
    if (failRecovery) throw PlatformException(code: 'recovery_failed');
    return pendingRecovery == null ? lost : await pendingRecovery!.future;
  }

  @override
  Future<XFile?> pickImage({
    required ImageSource source,
    double? maxWidth,
    double? maxHeight,
    int? imageQuality,
    CameraDevice preferredCameraDevice = CameraDevice.rear,
    bool requestFullMetadata = true,
  }) async {
    if (failCapture) throw PlatformException(code: 'camera_denied');
    return next;
  }
}

void main() {
  test(
    'recovers once and retains results until authenticated UI consumes them',
    () async {
      final FakePicker picker = FakePicker()
        ..lost = LostDataResponse(files: <XFile>[XFile('recovered.jpg')]);
      final CameraService service = CameraService(
        picker: picker,
        isAndroid: true,
      );
      await Future.wait(<Future<void>>[service.recover(), service.recover()]);
      expect(picker.recoveries, 1);
      expect(service.photo!.path, 'recovered.jpg');
      expect(service.hasPendingRecovery, isTrue);
    },
  );

  test(
    'capture waits for startup recovery, then preserves preview on cancellation',
    () async {
      final FakePicker picker = FakePicker()
        ..pendingRecovery = Completer<LostDataResponse>();
      final CameraService service = CameraService(
        picker: picker,
        isAndroid: true,
      );
      final Future<void> capture = service.capture();
      picker.pendingRecovery!.complete(
        LostDataResponse(files: <XFile>[XFile('old.jpg')]),
      );
      await capture;
      expect(service.photo!.path, 'old.jpg');
      picker.next = XFile('new.jpg');
      await service.capture();
      expect(service.photo!.path, 'new.jpg');
      picker.failCapture = true;
      await service.capture();
      expect(service.photo!.path, 'new.jpg');
      expect(service.errorMessage, contains('相机打开失败'));
    },
  );

  test(
    'recovery failures become visible state rather than uncaught startup errors',
    () async {
      for (final bool throws in <bool>[false, true]) {
        final FakePicker picker = FakePicker()
          ..failRecovery = throws
          ..lost = LostDataResponse(exception: PlatformException(code: 'lost'));
        final CameraService service = CameraService(
          picker: picker,
          isAndroid: true,
        );
        await service.recover();
        expect(service.hasPendingRecovery, isTrue);
        expect(service.errorMessage, isNotNull);
      }
    },
  );

  test('iOS never calls the Android-only recovery method', () async {
    final FakePicker picker = FakePicker();
    await CameraService(picker: picker, isAndroid: false).recover();
    expect(picker.recoveries, 0);
  });
}
