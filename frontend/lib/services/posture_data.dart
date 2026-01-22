import 'package:flutter/foundation.dart';

/// 坐姿分析结果
class PostureAnalysis {
  final bool isCorrect;
  final double spineAngle;
  final double eyeScreenDistance;
  final double headTiltAngle;
  final bool isSpineCorrect;
  final bool isDistanceCorrect;
  final bool isHeadCorrect;
  final String feedback;

  PostureAnalysis({
    required this.isCorrect,
    required this.spineAngle,
    required this.eyeScreenDistance,
    required this.headTiltAngle,
    required this.isSpineCorrect,
    required this.isDistanceCorrect,
    required this.isHeadCorrect,
    required this.feedback,
  });

  @override
  String toString() {
    return 'PostureAnalysis(spine: ${spineAngle.toStringAsFixed(1)}°, '
        'distance: ${eyeScreenDistance.toStringAsFixed(1)}cm, '
        'tilt: ${headTiltAngle.toStringAsFixed(1)}°, '
        'correct: $isCorrect)';
  }

  /// 获取主要问题
  String getMainIssue() {
    if (!isSpineCorrect) {
      return '脊柱角度';
    }
    if (!isDistanceCorrect) {
      return '眼屏距离';
    }
    if (!isHeadCorrect) {
      return '头部倾斜';
    }
    return '';
  }

  /// 获取警告级别
  PostureWarningLevel get warningLevel {
    if (isCorrect) {
      return PostureWarningLevel.good;
    }

    var issueCount = 0;
    if (!isSpineCorrect) issueCount++;
    if (!isDistanceCorrect) issueCount++;
    if (!isHeadCorrect) issueCount++;

    if (issueCount >= 2) {
      return PostureWarningLevel.critical;
    } else if (issueCount == 1) {
      // 检查严重程度
      if (!isDistanceCorrect && eyeScreenDistance < minEyeScreenDistance * 0.7) {
        return PostureWarningLevel.critical;
      }
      if (!isSpineCorrect && spineAngle > PostureDetector.maxSpineAngle * 1.5) {
        return PostureWarningLevel.critical;
      }
      return PostureWarningLevel.warning;
    }

    return PostureWarningLevel.good;
  }

  static const double minEyeScreenDistance = 30.0;
}

/// 坐姿警告级别
enum PostureWarningLevel {
  good,
  warning,
  critical,
}

/// PostureDetector 常量引用
class PostureDetector {
  static const double maxSpineAngle = 15.0;
  static const double minEyeScreenDistance = 30.0;
  static const double maxHeadTilt = 20.0;
}
