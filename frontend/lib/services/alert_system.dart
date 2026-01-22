import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:vibration/vibration.dart';

import 'posture_data.dart';

/// 警报系统服务
///
/// 当检测到不良坐姿时触发警报（声音、振动、视觉）
class AlertSystem {
  static final AlertSystem _instance = AlertSystem._internal();
  factory AlertSystem() => _instance;
  AlertSystem._internal();

  final AudioPlayer _audioPlayer = AudioPlayer();
  bool _isEnabled = true;
  bool _isVibrationEnabled = true;
  bool _isSoundEnabled = true;

  // 警报抑制（防止频繁触发）
  DateTime? _lastAlertTime;
  static const Duration alertCooldown = Duration(seconds: 5);

  // 持续不良姿势计数
  int _consecutiveBadPostureCount = 0;
  static const int badPostureThreshold = 3; // 连续 3 次不良姿势触发警报

  // Getters
  bool get isEnabled => _isEnabled;
  bool get isVibrationEnabled => _isVibrationEnabled;
  bool get isSoundEnabled => _isSoundEnabled;

  /// 启用/禁用警报系统
  void setEnabled(bool enabled) {
    _isEnabled = enabled;
    debugPrint('AlertSystem: ${enabled ? "Enabled" : "Disabled"}');
  }

  /// 启用/禁用振动
  void setVibrationEnabled(bool enabled) {
    _isVibrationEnabled = enabled;
    debugPrint('AlertSystem: Vibration ${enabled ? "enabled" : "disabled"}');
  }

  /// 启用/禁用声音
  void setSoundEnabled(bool enabled) {
    _isSoundEnabled = enabled;
    debugPrint('AlertSystem: Sound ${enabled ? "enabled" : "disabled"}');
  }

  /// 处理姿态分析结果并决定是否触发警报
  ///
  /// 返回是否触发了警报
  Future<bool> processPostureAnalysis(PostureAnalysis analysis) async {
    if (!_isEnabled) {
      _consecutiveBadPostureCount = 0;
      return false;
    }

    // 检查冷却时间
    if (_lastAlertTime != null) {
      final timeSinceLastAlert = DateTime.now().difference(_lastAlertTime!);
      if (timeSinceLastAlert < alertCooldown) {
        // 仍在冷却期内
        return false;
      }
    }

    // 判断是否需要警报
    if (analysis.isCorrect) {
      _consecutiveBadPostureCount = 0;
      return false;
    }

    _consecutiveBadPostureCount++;

    // 根据警告级别和连续不良姿势次数决定是否触发警报
    bool shouldAlert = false;

    switch (analysis.warningLevel) {
      case PostureWarningLevel.good:
        _consecutiveBadPostureCount = 0;
        break;

      case PostureWarningLevel.warning:
        // 警告级别：连续 3 次不良姿势触发
        if (_consecutiveBadPostureCount >= badPostureThreshold) {
          shouldAlert = true;
        }
        break;

      case PostureWarningLevel.critical:
        // 严重级别：立即触发
        shouldAlert = true;
        break;
    }

    if (shouldAlert) {
      await _triggerAlert(analysis.warningLevel);
      _lastAlertTime = DateTime.now();
      _consecutiveBadPostureCount = 0;
      return true;
    }

    return false;
  }

  /// 触发警报
  Future<void> _triggerAlert(PostureWarningLevel level) async {
    debugPrint('AlertSystem: Triggering alert for $level');

    // 振动模式
    VibrationPattern vibrationPattern;
    int soundResourceId;

    switch (level) {
      case PostureWarningLevel.warning:
        vibrationPattern = VibrationPattern.warning;
        soundResourceId = _getWarningSoundResource();
        break;

      case PostureWarningLevel.critical:
        vibrationPattern = VibrationPattern.critical;
        soundResourceId = _getCriticalSoundResource();
        break;

      case PostureWarningLevel.good:
        return; // 不触发警报
    }

    // 执行振动
    if (_isVibrationEnabled) {
      await _vibrate(vibrationPattern);
    }

    // 播放声音
    if (_isSoundEnabled) {
      await _playSound(soundResourceId);
    }
  }

  /// 振动
  Future<void> _vibrate(VibrationPattern pattern) async {
    final hasVibrator = await Vibration.hasVibrator() ?? false;
    if (!hasVibrator) {
      debugPrint('AlertSystem: No vibrator available');
      return;
    }

    final hasAmplitudeControl = await Vibration.hasAmplitudeControl() ?? false;

    switch (pattern) {
      case VibrationPattern.warning:
        // 轻微震动：短-短-短
        if (hasAmplitudeControl) {
          await Vibration.vibrate(duration: 100, amplitude: 80);
          await Future.delayed(const Duration(milliseconds: 100));
          await Vibration.vibrate(duration: 100, amplitude: 80);
          await Future.delayed(const Duration(milliseconds: 100));
          await Vibration.vibrate(duration: 100, amplitude: 80);
        } else {
          await Vibration.vibrate(duration: 100);
          await Future.delayed(const Duration(milliseconds: 100));
          await Vibration.vibrate(duration: 100);
          await Future.delayed(const Duration(milliseconds: 100));
          await Vibration.vibrate(duration: 100);
        }
        break;

      case VibrationPattern.critical:
        // 强烈震动：长-长-长
        if (hasAmplitudeControl) {
          await Vibration.vibrate(duration: 300, amplitude: 255);
          await Future.delayed(const Duration(milliseconds: 150));
          await Vibration.vibrate(duration: 300, amplitude: 255);
          await Future.delayed(const Duration(milliseconds: 150));
          await Vibration.vibrate(duration: 300, amplitude: 255);
        } else {
          await Vibration.vibrate(duration: 300);
          await Future.delayed(const Duration(milliseconds: 150));
          await Vibration.vibrate(duration: 300);
          await Future.delayed(const Duration(milliseconds: 150));
          await Vibration.vibrate(duration: 300);
        }
        break;
    }
  }

  /// 播放声音
  Future<void> _playSound(int resourceId) async {
    try {
      await _audioPlayer.play(AssetSource('sounds/alert_$resourceId.mp3'));
    } catch (e) {
      debugPrint('AlertSystem: Failed to play sound - $e');
    }
  }

  /// 获取警告级别声音资源 ID
  int _getWarningSoundResource() => 1;

  /// 获取严重级别声音资源 ID
  int _getCriticalSoundResource() => 2;

  /// 释放资源
  Future<void> dispose() async {
    await _audioPlayer.dispose();
  }

  /// 重置警报状态
  void reset() {
    _lastAlertTime = null;
    _consecutiveBadPostureCount = 0;
  }
}

/// 振动模式
enum VibrationPattern {
  warning,
  critical,
}
