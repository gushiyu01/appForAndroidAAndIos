import 'dart:io';

import 'package:image_picker/image_picker.dart';

/// App-owned recovery state. Results are only displayed by authenticated pages.
class CameraService {
  CameraService({ImagePicker? picker, bool? isAndroid})
    : _picker = picker ?? ImagePicker(),
      _isAndroid = isAndroid ?? Platform.isAndroid;

  static final CameraService instance = CameraService();
  final ImagePicker _picker;
  final bool _isAndroid;
  Future<void>? _recovery;
  XFile? photo;
  String? errorMessage;
  bool hasPendingRecovery = false;

  Future<void> recover() => _recovery ??= _recover();

  Future<void> _recover() async {
    if (!_isAndroid) return;
    try {
      final LostDataResponse response = await _picker.retrieveLostData();
      final List<XFile>? files = response.files;
      final XFile? recovered = files != null && files.isNotEmpty
          ? files.first
          : response.file;
      if (recovered != null) {
        photo = recovered;
        hasPendingRecovery = true;
      } else if (response.exception != null) {
        errorMessage = '未能恢复上次拍摄的照片，请重新拍摄';
        hasPendingRecovery = true;
      }
    } catch (_) {
      errorMessage = '未能恢复上次拍摄的照片，请重新拍摄';
      hasPendingRecovery = true;
    }
  }

  Future<void> capture() async {
    await recover();
    errorMessage = null;
    try {
      final XFile? result = await _picker.pickImage(
        source: ImageSource.camera,
        imageQuality: 90,
      );
      // Cancelling a retake must not discard the existing preview.
      if (result != null) photo = result;
    } catch (_) {
      errorMessage = '相机打开失败，请检查相机权限后重试';
    }
  }
}
