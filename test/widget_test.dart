import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:app_for_android_a_and_ios/pages/home_page.dart';
import 'package:app_for_android_a_and_ios/pages/login_page.dart';

void main() {
  testWidgets('login page exposes biometric retry', (WidgetTester tester) async {
    await tester.pumpWidget(
      const MaterialApp(home: LoginPage(autoStart: false)),
    );

    expect(find.text('指纹登录'), findsOneWidget);
    expect(find.byIcon(Icons.fingerprint), findsWidgets);
  });

  testWidgets('home page shows the two feature actions', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(const MaterialApp(home: HomePage()));

    expect(find.text('水平测试'), findsOneWidget);
    expect(find.text('打开相机'), findsOneWidget);
    expect(find.text('重力迷宫'), findsOneWidget);
  });
}
