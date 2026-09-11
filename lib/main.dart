import 'dart:async';

import 'package:flutter/material.dart';

import 'pages/camera_page.dart';
import 'pages/home_page.dart';
import 'pages/level_test_page.dart';
import 'pages/login_page.dart';
import 'pages/maze_game_page.dart';
import 'services/camera_service.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  unawaited(CameraService.instance.recover());
  runApp(const AppForAndroidAAndIosApp());
}

class AppForAndroidAAndIosApp extends StatelessWidget {
  const AppForAndroidAAndIosApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: '生物识别应用',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF2563EB)),
      ),
      initialRoute: LoginPage.routeName,
      routes: {
        LoginPage.routeName: (_) => const LoginPage(),
        HomePage.routeName: (_) => const HomePage(),
        LevelTestPage.routeName: (_) => const LevelTestPage(),
        MazeGamePage.routeName: (_) => const MazeGamePage(),
        CameraPage.routeName: (_) => const CameraPage(),
      },
    );
  }
}
