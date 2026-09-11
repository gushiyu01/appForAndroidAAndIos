import 'dart:async';

import 'package:flutter/material.dart';

import '../services/camera_service.dart';
import 'camera_page.dart';
import 'level_test_page.dart';
import 'maze_game_page.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key, this.cameraService});

  final CameraService? cameraService;

  static const String routeName = '/home';

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) unawaited(_showRecoveredPhoto());
    });
  }

  Future<void> _showRecoveredPhoto() async {
    final CameraService service =
        widget.cameraService ?? CameraService.instance;
    await service.recover();
    if (!mounted ||
        !service.hasPendingRecovery ||
        ModalRoute.of(context)?.isCurrent != true) {
      return;
    }
    service.hasPendingRecovery = false;
    await Navigator.of(context).push<void>(
      MaterialPageRoute<void>(
        builder: (_) => CameraPage(cameraService: service),
      ),
    );
  }

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
