import 'dart:async';

/// 帧节流器，限制帧处理频率
class FrameThrottler {
  DateTime _lastProcessTime = DateTime.now();
  static const Duration _minInterval = Duration(milliseconds: 100); // 10 FPS

  /// 判断是否应该处理当前帧
  /// 返回 true 表示应该处理，false 表示应该跳过
  bool shouldProcess() {
    final now = DateTime.now();
    if (now.difference(_lastProcessTime) < _minInterval) {
      return false; // 跳过此帧
    }
    _lastProcessTime = now;
    return true; // 处理此帧
  }
}
