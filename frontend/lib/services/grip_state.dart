import 'package:flutter/material.dart';

/// 握笔状态枚举
enum GripState {
  /// 未知状态
  unknown,

  /// 正在握笔
  holdingPen,

  /// 无手部可见
  noHand,

  /// 握笔姿势不佳（Sprint 6 实现）
  badGrip,
}

/// 握笔状态扩展方法
extension GripStateExtension on GripState {
  /// 获取状态消息
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

  /// 获取状态图标
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

  /// 获取状态颜色
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
