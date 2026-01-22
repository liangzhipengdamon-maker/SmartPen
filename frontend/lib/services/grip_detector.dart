import 'dart:math' as math;

import 'package:google_mlkit_pose_detection/google_mlkit_pose_detection.dart';

/// 握笔方式检测服务
///
/// 通过手部关键点检测握笔是否正确
class GripDetector {
  /// 握笔检测阈值
  static const double maxThumbIndexAngle = 60.0; // 拇指与食指最大夹角
  static const double minFingerExtension = 0.7; // 手指伸展度

  /// 分析握笔方式
  ///
  /// 注意：ML Kit Pose 主要检测身体姿态，不直接检测手部细节
  /// 这里提供框架，实际实现可能需要 ML Kit Hand Detection
  static GripAnalysis analyzeGrip(Pose pose) {
    // ML Kit Pose 不包含手部关键点
    // 这里提供框架，实际需要使用 ML Kit Hand Detection API
    // 或者简化为基于手臂位置的推断

    final hasVisibleHands = _hasVisibleHands(pose);

    if (!hasVisibleHands) {
      return GripAnalysis(
        isCorrect: false,
        gripType: GripType.unknown,
        confidence: 0.0,
        feedback: '未检测到手部，请确保手在摄像头视野内',
      );
    }

    // 简化版本：假设标准握笔
    return GripAnalysis(
      isCorrect: true,
      gripType: GripType.standard,
      confidence: 0.5,
      feedback: '握笔良好',
    );
  }

  /// 检测是否有可见的手部
  static bool _hasVisibleHands(Pose pose) {
    // 通过检查手腕位置判断
    final leftWrist = pose.landmarks[PoseLandmarkType.leftWrist];
    final rightWrist = pose.landmarks[PoseLandmarkType.rightWrist];

    return leftWrist != null || rightWrist != null;
  }

  /// 计算手指伸展度
  ///
  /// 需要 Hand Detection API
  static double? _calculateFingerExtension() {
    // TODO: 实现 Hand Detection 后补充
    return null;
  }

  /// 计算拇指-食指角度
  ///
  /// 需要 Hand Detection API
  static double? _calculateThumbIndexAngle() {
    // TODO: 实现 Hand Detection 后补充
    return null;
  }

  /// 生成握笔反馈
  static String _generateGripFeedback(GripAnalysis analysis) {
    switch (analysis.gripType) {
      case GripType.standard:
        return '握笔正确';
      case GripType.incorrect:
        return '请调整握笔方式：拇指和食指轻轻捏住笔杆';
      case GripType.unknown:
        return analysis.feedback;
    }
  }
}

/// 握笔分析结果
class GripAnalysis {
  final bool isCorrect;
  final GripType gripType;
  final double confidence;
  final String feedback;

  GripAnalysis({
    required this.isCorrect,
    required this.gripType,
    required this.confidence,
    required this.feedback,
  });

  @override
  String toString() {
    return 'GripAnalysis(type: $gripType, correct: $isCorrect, '
        'confidence: ${(confidence * 100).toStringAsFixed(0)}%)';
  }
}

/// 握笔类型
enum GripType {
  standard,    // 标准握笔
  incorrect,   // 错误握笔
  unknown,     // 未知
}

/// 扩展 GripDetector 添加反馈生成方法
extension GripDetectorExtension on GripDetector {
  static String generateGripFeedback(GripAnalysis analysis) {
    return GripDetector._generateGripFeedback(analysis);
  }
}
