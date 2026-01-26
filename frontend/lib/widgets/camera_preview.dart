import 'package:flutter/material.dart';
import 'package:camera/camera.dart';
import '../providers/posture_provider.dart';

/// 相机预览组件
class CameraPreviewWidget extends StatelessWidget {
  final PostureProvider provider;

  const CameraPreviewWidget({
    Key? key,
    required this.provider,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    // 获取自定义 CameraController 实例
    final customController = provider.cameraController;

    if (customController == null ||
        !customController!.isInitialized ||
        customController!.controller == null) {
      return Container(
        color: Colors.black,
        child: const Center(
          child: CircularProgressIndicator(
            valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
          ),
        ),
      );
    }

    // 使用相机包的 CameraPreview
    return CameraPreview(customController!.controller!);
  }
}
