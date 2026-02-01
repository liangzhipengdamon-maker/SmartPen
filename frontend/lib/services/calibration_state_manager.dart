import 'dart:async';
import 'package:flutter/foundation.dart';
import 'posture_data.dart';

/// 校准状态变化事件
///
/// 用于 TTS 语音合成等外部服务监听状态变化
class CalibrationStateChangeEvent {
  final CalibrationState from;
  final CalibrationState to;
  final DateTime timestamp;

  CalibrationStateChangeEvent({
    required this.from,
    required this.to,
    DateTime? timestamp,
  }) : timestamp = timestamp ?? DateTime.now();

  @override
  String toString() =>
      'CalibrationStateChangeEvent($from -> $to at $timestamp)';
}

/// 校准状态管理器
///
/// 负责：
/// 1. 管理稳定检测计时器（1秒要求）
/// 2. 手部检测缓冲期（1秒容错）
/// 3. 决定是否启用"开始练习"按钮
/// 4. 发出状态变化事件（为 TTS 集成预留）
class CalibrationStateManager extends ChangeNotifier {
  CalibrationState _currentState = CalibrationState.noFace;
  CalibrationState _lastStableState = CalibrationState.noFace;

  Timer? _stabilityTimer;
  DateTime? _handLostTime; // 记录手部消失的时间点
  bool _isHandBufferActive = false;

  // 状态变化回调（为 TTS 集成预留）
  final List<Function(CalibrationStateChangeEvent)> _stateChangeListeners = [];

  static const Duration _stabilityThreshold = Duration(seconds: 1);
  static const Duration _handBufferDuration = Duration(seconds: 1);

  CalibrationState get currentState => _currentState;
  CalibrationState get lastStableState => _lastStableState;
  bool get isReadyForPractice => _lastStableState == CalibrationState.aligned;

  /// 注册状态变化监听器（用于 TTS 等外部服务）
  void addStateChangeListener(Function(CalibrationStateChangeEvent) listener) {
    _stateChangeListeners.add(listener);
  }

  /// 移除状态变化监听器
  void removeStateChangeListener(
      Function(CalibrationStateChangeEvent) listener) {
    _stateChangeListeners.remove(listener);
  }

  /// 处理新的姿态分析结果
  void processAnalysis(PostureAnalysis analysis) {
    final rawState = analysis.calibrationState;
    final oldState = _currentState;

    debugPrint('🎯 CalibrationState: $oldState -> $rawState');
    debugPrint('🖐️  Has hands: ${analysis.hasVisibleHands}, '
        'Face: ${analysis.isFaceDetected}');

    _handleHandDetectionBuffer(analysis);

    // 计算实际状态：在手部缓冲期内，如果是 noHands，保持为 aligned
    CalibrationState newState = rawState;
    if (_isHandBufferActive &&
        rawState == CalibrationState.noHands &&
        oldState == CalibrationState.aligned) {
      newState = CalibrationState.aligned;
      debugPrint('⏳ Hand buffer: keeping state as aligned');
    }

    _handleStabilityTimer(newState, analysis);

    _currentState = newState;

    // 如果状态发生变化，发出事件
    if (oldState != newState) {
      _notifyStateChange(oldState, newState);
    }

    notifyListeners();
  }

  /// 手部检测缓冲期处理
  /// 避免手部短暂消失导致误报
  void _handleHandDetectionBuffer(PostureAnalysis analysis) {
    if (analysis.hasVisibleHands) {
      // 检测到手部，清除缓冲期
      _handLostTime = null;
      _isHandBufferActive = false;
    } else {
      // 未检测到手部
      if (_handLostTime == null) {
        // 第一次检测到手部消失，记录时间点
        _handLostTime = DateTime.now();
      }

      // 检查是否在缓冲期内
      final timeSinceLost = DateTime.now().difference(_handLostTime!);

      if (timeSinceLost < _handBufferDuration) {
        _isHandBufferActive = true;
        debugPrint('⏳ Hand buffer active: '
            '${timeSinceLost.inMilliseconds}ms / ${_handBufferDuration.inMilliseconds}ms');
      } else {
        _isHandBufferActive = false;
        _handLostTime = null;
      }
    }
  }

  /// 稳定性计时器处理
  /// 只有在 aligned 状态持续1秒后才真正启用按钮
  void _handleStabilityTimer(
      CalibrationState newState, PostureAnalysis analysis) {
    // 仅在 aligned 且满足稳定 1 秒时放行
    final hasFace = analysis.isFaceDetected;
    final hasHand = analysis.hasVisibleHands || _isHandBufferActive;
    final hasAlignment = analysis.alignmentOk;
    final postureOk = analysis.isCorrect;

    debugPrint('🧪 Gate flags: face=$hasFace hand=$hasHand '
        'alignment=$hasAlignment posture=$postureOk state=$newState');

    if (newState == CalibrationState.aligned) {
      // 满足条件，启动或继续计时
      if (_stabilityTimer == null || !_stabilityTimer!.isActive) {
        debugPrint('⏱️  Starting stability timer...');
        _stabilityTimer?.cancel();
        final stableTarget = newState;
        _stabilityTimer = Timer(_stabilityThreshold, () {
          debugPrint('✅ Stability threshold reached!');
          _lastStableState = stableTarget;
          notifyListeners();
        });
      }
    } else {
      // 条件不满足，取消计时
      if (_stabilityTimer != null && _stabilityTimer!.isActive) {
        debugPrint('❌ Stability condition broken, cancelling timer');
        _stabilityTimer?.cancel();
        _lastStableState = newState;
      }
    }
  }

  /// 通知状态变化（为 TTS 集成预留）
  void _notifyStateChange(CalibrationState from, CalibrationState to) {
    final event = CalibrationStateChangeEvent(from: from, to: to);
    for (final listener in _stateChangeListeners) {
      try {
        listener(event);
      } catch (e) {
        debugPrint('⚠️  State change listener error: $e');
      }
    }
  }

  /// 重置状态（用于重新进入校准模式）
  void reset() {
    _stabilityTimer?.cancel();
    _handLostTime = null;
    _isHandBufferActive = false;
    _currentState = CalibrationState.noFace;
    _lastStableState = CalibrationState.noFace;
    notifyListeners();
  }

  @override
  void dispose() {
    _stabilityTimer?.cancel();
    _stateChangeListeners.clear();
    super.dispose();
  }
}
