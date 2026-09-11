import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image_picker/image_picker.dart';
import 'package:app_for_android_a_and_ios/pages/camera_page.dart';
import 'package:app_for_android_a_and_ios/pages/home_page.dart';
import 'package:app_for_android_a_and_ios/pages/login_page.dart';
import 'package:app_for_android_a_and_ios/services/camera_service.dart';

import 'camera_service_test.dart' show FakePicker;

void main() {
  testWidgets(
    'recovered camera state is not shown on login; home opens it once',
    (tester) async {
      final FakePicker picker = FakePicker()
        ..lost = LostDataResponse(files: <XFile>[XFile('recovered.jpg')]);
      final CameraService service = CameraService(
        picker: picker,
        isAndroid: true,
      );
      await service.recover();
      await tester.pumpWidget(
        const MaterialApp(home: LoginPage(autoStart: false)),
      );
      expect(find.byType(CameraPage), findsNothing);
      expect(service.hasPendingRecovery, isTrue);
      await tester.pumpWidget(
        MaterialApp(home: HomePage(cameraService: service)),
      );
      await tester.pumpAndSettle();
      expect(find.byType(CameraPage), findsOneWidget);
      expect(find.text('重新拍摄'), findsOneWidget);
      expect(service.hasPendingRecovery, isFalse);
      await tester.tap(find.byTooltip('Back'));
      await tester.pumpAndSettle();
      expect(find.byType(CameraPage), findsNothing);
      expect(find.byType(HomePage), findsOneWidget);
    },
  );
}
