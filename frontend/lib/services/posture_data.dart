import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

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
  final bool hasVisibleHands;  // 是否检测到手部
  final bool isFaceDetected;   // 是否检测到人脸
  final GripState gripState;   // 握笔状态

  PostureAnalysis({
    required this.isCorrect,
    required this.spineAngle,
    required this.eyeScreenDistance,
    required this.headTiltAngle,
    required this.isSpineCorrect,
    required this.isDistanceCorrect,
    required this.isHeadCorrect,
    required this.feedback,
    this.hasVisibleHands = false,  // 新增，默认 false
    this.isFaceDetected = false,   // 新增，默认 false
    this.gripState = GripState.unknown,  // 新增，默认 unknown
  });

  @override
  String toString() {
    return 'PostureAnalysis(spine: ${spineAngle.toStringAsFixed(1)}°, '
        'distance: ${eyeScreenDistance.toStringAsFixed(1)}cm, '
        'tilt: ${headTiltAngle.toStringAsFixed(1)}°, '
        'correct: $isCorrect, '
        'hands: $hasVisibleHands, '
        'face: $isFaceDetected, '
        'grip: $gripState)';
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

  /// 获取校准状态
  ///
  /// 简化版：只检查人脸和手部，忽略不可靠的姿态指标（spine/tilt/distance）
  /// 这些指标的计算算法当前存在问题，导致误报
  CalibrationState get calibrationState {
    if (!isFaceDetected) {
      return CalibrationState.noFace;
    }
    if (!hasVisibleHands) {
      return CalibrationState.noHands;
    }
    return CalibrationState.aligned;
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

/// 校准状态枚举
enum CalibrationState {
  noFace,      // 无人脸 - 红色
  badPosture,  // 姿态不佳 - 橙色
  noHands,     // 无手部 - 橙色
  aligned,     // 对齐完成 - 绿色
}

/// 校准状态扩展方法
extension CalibrationStateExtension on CalibrationState {
  String get message {
    switch (this) {
      case CalibrationState.noFace:
        return 'No face detected';
      case CalibrationState.badPosture:
        return 'Sit up straight';
      case CalibrationState.noHands:
        return 'Show your hand';
      case CalibrationState.aligned:
        return 'Perfect!';
    }
  }

  String get buttonLabel {
    switch (this) {
      case CalibrationState.noFace:
        return '请坐正';
      case CalibrationState.badPosture:
        return '请坐正';
      case CalibrationState.noHands:
        return '请亮出手部';
      case CalibrationState.aligned:
        return '开始练习';
    }
  }

  Color get color {
    switch (this) {
      case CalibrationState.noFace:
        return Colors.red;
      case CalibrationState.badPosture:
        return Colors.orange;
      case CalibrationState.noHands:
        return Colors.orange;
      case CalibrationState.aligned:
        return Colors.green;
    }
  }

  bool get isReadyForPractice {
    return this == CalibrationState.aligned;
  }

  String get name => toString().split('.').last;
}

/// 握笔状态枚举
enum GripState {
  unknown,      // 未知状态
  holdingPen,   // 正在握笔
  noHand,       // 无手部可见
  badGrip,      // 握笔姿势不佳（Sprint 6 实现）
}

/// 握笔状态扩展方法
extension GripStateExtension on GripState {
  String get message {
    switch (this) {
      case GripState.unknown:
        return '检测中...';
      case GripState.holdingPen:
        return '握笔正确';
      case GripState.noHand:
        return '请亮出手部';
      case GripState.badGrip:
        return '请调整握笔方式';
    }
  }

  String get icon {
    switch (this) {
      case GripState.unknown:
        return '❓';
      case GripState.holdingPen:
        return '✍️';
      case GripState.noHand:
        return '🖐️';
      case GripState.badGrip:
        return '⚠️';
    }
  }

  Color get color {
    switch (this) {
      case GripState.unknown:
        return Colors.grey;
      case GripState.holdingPen:
        return Colors.green;
      case GripState.noHand:
        return Colors.orange;
      case GripState.badGrip:
        return Colors.red;
    }
  }
}

