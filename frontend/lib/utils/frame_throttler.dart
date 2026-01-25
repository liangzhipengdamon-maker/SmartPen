/// 帧节流器，限制帧处理频率
class FrameThrottler {
  Stopwatch? _stopwatch;
  static const Duration _minInterval = Duration(milliseconds: 100); // 10 FPS

  /// 判断是否应该处理当前帧
  /// 返回 true 表示应该处理，false 表示应该跳过
  bool shouldProcess() {
    if (_stopwatch == null) {
      _stopwatch = Stopwatch()..start();
      return true; // 首次调用总是允许
    }

    final elapsed = _stopwatch!.elapsedMilliseconds;
    if (elapsed < _minInterval.inMilliseconds) {
      return false; // 跳过此帧
    }
    _stopwatch!.reset();
    return true; // 处理此帧
  }
}
