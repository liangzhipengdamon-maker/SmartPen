import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';

class CameraPermissionDialog extends StatelessWidget {
  final VoidCallback onOpenSettings;

  const CameraPermissionDialog({
    Key? key,
    required this.onOpenSettings,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('需要相机权限'),
      content: const Text(
        'SmartPen 需要相机权限来检测您的书写姿态。\n\n'
        '请点击下方按钮前往设置开启相机权限。',
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('取消'),
        ),
        ElevatedButton(
          onPressed: () {
            Navigator.of(context).pop();
            onOpenSettings();
          },
          child: const Text('去设置'),
        ),
      ],
    );
  }

  /// 显示权限对话框
  static Future<void> show(BuildContext context) {
    return showDialog(
      context: context,
      builder: (context) => CameraPermissionDialog(
        onOpenSettings: () async {
          await openAppSettings();
        },
      ),
    );
  }
}
