import 'package:flutter/material.dart';
import 'package:google_mlkit_pose_detection/google_mlkit_pose_detection.dart';

/// 姿态绘制器 - 在相机预览上绘制 ML Kit 检测到的关键点
///
/// 用于可视化调试，显示 ML Kit 实际检测到的位置
class PosePainter extends CustomPainter {
  final List<Pose> poses;
  final Size imageSize;

  PosePainter({
    required this.poses,
    required this.imageSize,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (poses.isEmpty) {
      // 没有检测到姿态时，显示提示文本
      _drawNoPoseText(canvas, size);
      return;
    }

    final pose = poses.first;
    final paint = Paint()
      ..color = Colors.green
      ..strokeWidth = 3
      ..strokeCap = StrokeCap.round
      ..style = PaintingStyle.fill;

    // 绘制所有关键点
    pose.landmarks.forEach((type, landmark) {
      // 将归一化坐标转换为屏幕坐标
      final x = landmark.x * size.width;
      final y = landmark.y * size.height;

      // 根据关键点类型使用不同颜色
      final color = _getLandmarkColor(type);
      paint.color = color;

      // 绘制关键点（圆点）
      canvas.drawCircle(
        Offset(x, y),
        _getLandmarkSize(type),
        paint,
      );

      // 绘制关键点标签（仅重要关键点）
      if (_isImportantLandmark(type)) {
        _drawLandmarkLabel(canvas, x, y, type, size);
      }
    });

    // 绘制关键点之间的连接线（用于可视化骨架）
    _drawSkeleton(canvas, size, pose, paint);
  }

  /// 绘制"无姿态"提示文本
  void _drawNoPoseText(Canvas canvas, Size size) {
    final textPainter = TextPainter(
      text: const TextSpan(
        text: '❌ 未检测到姿态\n请确保人脸在画面中',
        style: TextStyle(
          color: Colors.red,
          fontSize: 20,
          fontWeight: FontWeight.bold,
        ),
      ),
      textDirection: TextDirection.ltr,
      textAlign: TextAlign.center,
    );

    textPainter.layout();
    textPainter.paint(
      canvas,
      Offset(
        (size.width - textPainter.width) / 2,
        (size.height - textPainter.height) / 2,
      ),
    );
  }

  /// 获取关键点颜色
  Color _getLandmarkColor(PoseLandmarkType type) {
    // 人脸关键点 - 红色
    if ([
      PoseLandmarkType.nose,
      PoseLandmarkType.leftEye,
      PoseLandmarkType.rightEye,
      PoseLandmarkType.leftEar,
      PoseLandmarkType.rightEar,
      PoseLandmarkType.leftMouth,
      PoseLandmarkType.rightMouth,
    ].contains(type)) {
      return Colors.red;
    }

    // 手部关键点 - 蓝色
    if ([
      PoseLandmarkType.leftWrist,
      PoseLandmarkType.rightWrist,
      PoseLandmarkType.leftThumb,
      PoseLandmarkType.rightThumb,
      PoseLandmarkType.leftPinky,
      PoseLandmarkType.rightPinky,
    ].contains(type)) {
      return Colors.blue;
    }

    // 肩膀关键点 - 黄色
    if ([
      PoseLandmarkType.leftShoulder,
      PoseLandmarkType.rightShoulder,
    ].contains(type)) {
      return Colors.yellow;
    }

    // 肘部关键点 - 橙色
    if ([
      PoseLandmarkType.leftElbow,
      PoseLandmarkType.rightElbow,
    ].contains(type)) {
      return Colors.orange;
    }

    // 其他 - 绿色
    return Colors.green;
  }

  /// 获取关键点大小
  double _getLandmarkSize(PoseLandmarkType type) {
    // 重要关键点更大
    if ([
      PoseLandmarkType.nose,
      PoseLandmarkType.leftWrist,
      PoseLandmarkType.rightWrist,
      PoseLandmarkType.leftShoulder,
      PoseLandmarkType.rightShoulder,
    ].contains(type)) {
      return 8.0;
    }

    return 5.0;
  }

  /// 是否为重要关键点
  bool _isImportantLandmark(PoseLandmarkType type) {
    return [
      PoseLandmarkType.nose,
      PoseLandmarkType.leftWrist,
      PoseLandmarkType.rightWrist,
    ].contains(type);
  }

  /// 绘制关键点标签
  void _drawLandmarkLabel(Canvas canvas, double x, double y, PoseLandmarkType type, Size size) {
    final label = _getLandmarkLabel(type);
    final textPainter = TextPainter(
      text: TextSpan(
        text: label,
        style: const TextStyle(
          color: Colors.white,
          fontSize: 12,
          fontWeight: FontWeight.bold,
        ),
      ),
      textDirection: TextDirection.ltr,
    );

    textPainter.layout();

    // 在关键点下方绘制标签背景
    final bgPaint = Paint()
      ..color = Colors.black.withOpacity(0.7)
      ..style = PaintingStyle.fill;

    final bgRect = Rect.fromLTWH(
      x - textPainter.width / 2 - 4,
      y + 10,
      textPainter.width + 8,
      textPainter.height + 4,
    );

    canvas.drawRect(bgRect, bgPaint);

    // 绘制标签文本
    textPainter.paint(
      canvas,
      Offset(
        x - textPainter.width / 2,
        y + 12,
      ),
    );
  }

  /// 获取关键点标签
  String _getLandmarkLabel(PoseLandmarkType type) {
    switch (type) {
      case PoseLandmarkType.nose:
        return 'nose';
      case PoseLandmarkType.leftWrist:
        return 'L手腕';
      case PoseLandmarkType.rightWrist:
        return 'R手腕';
      case PoseLandmarkType.leftShoulder:
        return 'L肩';
      case PoseLandmarkType.rightShoulder:
        return 'R肩';
      default:
        return '';
    }
  }

  /// 绘制骨架连接线
  void _drawSkeleton(Canvas canvas, Size size, Pose pose, Paint paint) {
    final linePaint = Paint()
      ..color = Colors.white.withOpacity(0.5)
      ..strokeWidth = 2
      ..style = PaintingStyle.stroke;

    // 绘制肩膀连接线
    final leftShoulder = pose.landmarks[PoseLandmarkType.leftShoulder];
    final rightShoulder = pose.landmarks[PoseLandmarkType.rightShoulder];
    if (leftShoulder != null && rightShoulder != null) {
      canvas.drawLine(
        Offset(leftShoulder.x * size.width, leftShoulder.y * size.height),
        Offset(rightShoulder.x * size.width, rightShoulder.y * size.height),
        linePaint,
      );
    }

    // 绘制左臂（肩膀到手腕）
    final leftElbow = pose.landmarks[PoseLandmarkType.leftElbow];
    final leftWrist = pose.landmarks[PoseLandmarkType.leftWrist];
    if (leftShoulder != null && leftElbow != null) {
      canvas.drawLine(
        Offset(leftShoulder.x * size.width, leftShoulder.y * size.height),
        Offset(leftElbow.x * size.width, leftElbow.y * size.height),
        linePaint,
      );
    }
    if (leftElbow != null && leftWrist != null) {
      canvas.drawLine(
        Offset(leftElbow.x * size.width, leftElbow.y * size.height),
        Offset(leftWrist.x * size.width, leftWrist.y * size.height),
        linePaint,
      );
    }

    // 绘制右臂
    final rightElbow = pose.landmarks[PoseLandmarkType.rightElbow];
    final rightWrist = pose.landmarks[PoseLandmarkType.rightWrist];
    if (rightShoulder != null && rightElbow != null) {
      canvas.drawLine(
        Offset(rightShoulder.x * size.width, rightShoulder.y * size.height),
        Offset(rightElbow.x * size.width, rightElbow.y * size.height),
        linePaint,
      );
    }
    if (rightElbow != null && rightWrist != null) {
      canvas.drawLine(
        Offset(rightElbow.x * size.width, rightElbow.y * size.height),
        Offset(rightWrist.x * size.width, rightWrist.y * size.height),
        linePaint,
      );
    }
  }

  @override
  bool shouldRepaint(PosePainter oldDelegate) {
    return oldDelegate.poses != poses;
  }
}

/// 校准引导绘制器 - 绘制静态引导轮廓
class CalibrationGuidePainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.white
      ..strokeWidth = 2
      ..style = PaintingStyle.stroke;

    final dashedPaint = Paint()
      ..color = Colors.white.withOpacity(0.6)
      ..strokeWidth = 2
      ..style = PaintingStyle.stroke;

    // ========== 1. 人脸区域引导（中心椭圆轮廓）==========
    final faceCenter = Offset(size.width / 2, size.height * 0.35);
    final faceWidth = size.width * 0.5;
    final faceHeight = size.height * 0.35;

    // 绘制虚线椭圆轮廓（人脸区域）
    canvas.drawOval(
      Rect.fromCenter(
        center: faceCenter,
        width: faceWidth,
        height: faceHeight,
      ),
      dashedPaint,
    );

    // 绘制"人脸"标签
    _drawLabel(canvas, faceCenter, '请将面部放在此处', size);

    // ========== 2. 手部区域引导（底部矩形）==========
    final handAreaY = size.height * 0.6;  // y > 0.6 为书写区域
    final handAreaRect = Rect.fromLTWH(
      size.width * 0.1,
      handAreaY,
      size.width * 0.8,
      size.height * 0.35,
    );

    // 绘制虚线矩形（手部区域）
    canvas.drawRect(handAreaRect, dashedPaint);

    // 绘制"手部"标签
    _drawLabel(
      canvas,
      Offset(size.width / 2, handAreaY + handAreaRect.height / 2),
      '请将手放在此区域',
      size,
    );

    // ========== 3. 绘制中心十字线（辅助对齐）==========
    final centerLinePaint = Paint()
      ..color = Colors.white.withOpacity(0.3)
      ..strokeWidth = 1
      ..style = PaintingStyle.stroke;

    // 垂直中心线
    canvas.drawLine(
      Offset(size.width / 2, 0),
      Offset(size.width / 2, size.height),
      centerLinePaint,
    );

    // 水平中心线
    canvas.drawLine(
      Offset(0, size.height / 2),
      Offset(size.width, size.height / 2),
      centerLinePaint,
    );
  }

  /// 绘制标签（带背景）
  void _drawLabel(Canvas canvas, Offset position, String text, Size size) {
    final textPainter = TextPainter(
      text: TextSpan(
        text: text,
        style: const TextStyle(
          color: Colors.white,
          fontSize: 14,
          fontWeight: FontWeight.bold,
        ),
      ),
      textDirection: TextDirection.ltr,
    );

    textPainter.layout();

    // 绘制背景
    final bgPaint = Paint()
      ..color = Colors.black.withOpacity(0.7)
      ..style = PaintingStyle.fill;

    final bgRect = Rect.fromLTWH(
      position.dx - textPainter.width / 2 - 8,
      position.dy - textPainter.height / 2 - 4,
      textPainter.width + 16,
      textPainter.height + 8,
    );

    canvas.drawRect(bgRect, bgPaint);

    // 绘制文本
    textPainter.paint(
      canvas,
      Offset(
        position.dx - textPainter.width / 2,
        position.dy - textPainter.height / 2,
      ),
    );
  }

  @override
  bool shouldRepaint(CalibrationGuidePainter oldDelegate) => false;
}
