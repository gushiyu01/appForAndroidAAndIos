import 'dart:io';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

class CameraPage extends StatefulWidget {
  const CameraPage({super.key});

  static const String routeName = '/camera';

  @override
  State<CameraPage> createState() => _CameraPageState();
}

class _CameraPageState extends State<CameraPage> {
  final ImagePicker _picker = ImagePicker();
  XFile? _photo;
  bool _isLaunching = false;
  String? _errorMessage;

  Future<void> _openCamera() async {
    if (_isLaunching) {
      return;
    }

    setState(() {
      _isLaunching = true;
      _errorMessage = null;
    });

    try {
      final XFile? photo = await _picker.pickImage(
        source: ImageSource.camera,
        imageQuality: 90,
      );

      if (!mounted) {
        return;
      }

      setState(() {
        _photo = photo;
      });
    } catch (_) {
      if (!mounted) {
        return;
      }
      setState(() {
        _errorMessage = '相机打开失败';
      });
    } finally {
      if (mounted) {
        setState(() {
          _isLaunching = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final ColorScheme colorScheme = Theme.of(context).colorScheme;
    final XFile? photo = _photo;

    return Scaffold(
      appBar: AppBar(title: const Text('相机')),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            spacing: 20,
            children: [
              Expanded(
                child: Center(
                  child: photo == null
                      ? Icon(
                          Icons.photo_camera_outlined,
                          size: 120,
                          color: colorScheme.onSurfaceVariant,
                        )
                      : ClipRRect(
                          borderRadius: BorderRadius.circular(8),
                          child: Image.file(
                            File(photo.path),
                            fit: BoxFit.cover,
                            errorBuilder: (_, _, _) => Icon(
                              Icons.broken_image_outlined,
                              size: 120,
                              color: colorScheme.onSurfaceVariant,
                            ),
                          ),
                        ),
                ),
              ),
              if (_errorMessage != null)
                Text(
                  _errorMessage!,
                  textAlign: TextAlign.center,
                  style: TextStyle(color: colorScheme.error),
                ),
              FilledButton.icon(
                onPressed: _isLaunching ? null : _openCamera,
                icon: _isLaunching
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.photo_camera),
                label: Text(photo == null ? '打开相机' : '重新拍摄'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
