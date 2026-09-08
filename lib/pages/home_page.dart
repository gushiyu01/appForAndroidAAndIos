import 'package:flutter/material.dart';

import 'camera_page.dart';
import 'level_test_page.dart';
import 'maze_game_page.dart';

class HomePage extends StatelessWidget {
  const HomePage({super.key});

  static const String routeName = '/home';

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('功能首页')),
      body: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(28),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              spacing: 20,
              children: [
                FilledButton.icon(
                  onPressed: () =>
                      Navigator.of(context).pushNamed(LevelTestPage.routeName),
                  icon: const Icon(Icons.vertical_align_center),
                  label: const Text('水平测试'),
                ),
                FilledButton.icon(
                  onPressed: () =>
                      Navigator.of(context).pushNamed(MazeGamePage.routeName),
                  icon: const Icon(Icons.route),
                  label: const Text('重力迷宫'),
                ),
                OutlinedButton.icon(
                  onPressed: () =>
                      Navigator.of(context).pushNamed(CameraPage.routeName),
                  icon: const Icon(Icons.photo_camera),
                  label: const Text('打开相机'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
