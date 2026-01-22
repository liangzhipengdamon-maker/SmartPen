import 'dart:async';
import 'package:flutter/foundation.dart';

/// 性能监控服务
///
/// 监控姿态检测和图像处理的性能指标
class PerformanceMonitor {
  static final PerformanceMonitor _instance = PerformanceMonitor._internal();
  factory PerformanceMonitor() => _instance;
  PerformanceMonitor._internal();

  final _frameTimings = <double>[];
  final _detectionTimings = <double>[];
  final _processingTimings = <double>[];

  int _totalFrames = 0;
  int _droppedFrames = 0;
  double _maxFrameTime = 0.0;

  // 性能阈值
  static const double targetFrameTime = 100.0; // ms (10 FPS)
  static const double warningFrameTime = 150.0; // ms
  static const double criticalFrameTime = 200.0; // ms

  // Getters
  int get totalFrames => _totalFrames;
  int get droppedFrames => _droppedFrames;
  double get dropRate =>
      _totalFrames > 0 ? (_droppedFrames / _totalFrames * 100) : 0.0;
  double get averageFrameTime =>
      _frameTimings.isNotEmpty ? _frameTimings.reduce((a, b) => a + b) / _frameTimings.length : 0.0;
  double get averageDetectionTime =>
      _detectionTimings.isNotEmpty ? _detectionTimings.reduce((a, b) => a + b) / _detectionTimings.length : 0.0;
  double get averageProcessingTime =>
      _processingTimings.isNotEmpty ? _processingTimings.reduce((a, b) => a + b) / _processingTimings.length : 0.0;
  double get maxFrameTime => _maxFrameTime;

  /// 开始新的帧测量
  Stopwatch startFrame() {
    _totalFrames++;
    return Stopwatch()..start();
  }

  /// 结束帧测量
  void endFrame(Stopwatch stopwatch, {double? detectionTime, double? processingTime}) {
    stopwatch.stop();
    final frameTime = stopwatch.elapsedMilliseconds.toDouble();

    _frameTimings.add(frameTime);
    if (frameTime > _maxFrameTime) {
      _maxFrameTime = frameTime;
    }

    if (detectionTime != null) {
      _detectionTimings.add(detectionTime);
    }

    if (processingTime != null) {
      _processingTimings.add(processingTime);
    }

    if (frameTime > criticalFrameTime) {
      _droppedFrames++;
      debugPrint('PerformanceMonitor: Dropped frame (${frameTime.toStringAsFixed(1)}ms)');
    }

    // 保持最近 100 帧的数据
    if (_frameTimings.length > 100) {
      _frameTimings.removeAt(0);
    }
    if (_detectionTimings.length > 100) {
      _detectionTimings.removeAt(0);
    }
    if (_processingTimings.length > 100) {
      _processingTimings.removeAt(0);
    }
  }

  /// 获取性能级别
  PerformanceLevel get performanceLevel {
    final avgTime = averageFrameTime;
    if (avgTime < targetFrameTime) {
      return PerformanceLevel.excellent;
    } else if (avgTime < warningFrameTime) {
      return PerformanceLevel.good;
    } else if (avgTime < criticalFrameTime) {
      return PerformanceLevel.warning;
    } else {
      return PerformanceLevel.critical;
    }
  }

  /// 获取性能建议
  String getPerformanceRecommendation() {
    final level = performanceLevel;
    final avgDetection = averageDetectionTime;
    final avgProcessing = averageProcessingTime;

    switch (level) {
      case PerformanceLevel.excellent:
        return '性能优秀，检测流畅';
      case PerformanceLevel.good:
        return '性能良好，可适当降低检测频率';
      case PerformanceLevel.warning:
        if (avgDetection > 100) {
          return '检测耗时较长，建议降低图像分辨率';
        } else {
          return '处理耗时较长，建议启用 GPU 加速';
        }
      case PerformanceLevel.critical:
        if (avgDetection > 150) {
          return '检测严重超时，必须降低图像分辨率或使用 Lite 模型';
        } else {
          return '处理严重超时，建议启用 Isolate 并行处理';
        }
    }
  }

  /// 重置统计数据
  void reset() {
    _frameTimings.clear();
    _detectionTimings.clear();
    _processingTimings.clear();
    _totalFrames = 0;
    _droppedFrames = 0;
    _maxFrameTime = 0.0;
  }

  /// 获取性能报告
  PerformanceReport getReport() {
    return PerformanceReport(
      totalFrames: _totalFrames,
      droppedFrames: _droppedFrames,
      dropRate: dropRate,
      averageFrameTime: averageFrameTime,
      averageDetectionTime: averageDetectionTime,
      averageProcessingTime: averageProcessingTime,
      maxFrameTime: _maxFrameTime,
      performanceLevel: performanceLevel,
      recommendation: getPerformanceRecommendation(),
    );
  }
}

/// 性能级别
enum PerformanceLevel {
  excellent,  // < 100ms
  good,       // < 150ms
  warning,    // < 200ms
  critical,   // >= 200ms
}

/// 性能报告
class PerformanceReport {
  final int totalFrames;
  final int droppedFrames;
  final double dropRate;
  final double averageFrameTime;
  final double averageDetectionTime;
  final double averageProcessingTime;
  final double maxFrameTime;
  final PerformanceLevel performanceLevel;
  final String recommendation;

  PerformanceReport({
    required this.totalFrames,
    required this.droppedFrames,
    required this.dropRate,
    required this.averageFrameTime,
    required this.averageDetectionTime,
    required this.averageProcessingTime,
    required this.maxFrameTime,
    required this.performanceLevel,
    required this.recommendation,
  });

  @override
  String toString() {
    return 'PerformanceReport('
        'frames: $totalFrames, '
        'dropped: $droppedFrames (${dropRate.toStringAsFixed(1)}%), '
        'avgFrame: ${averageFrameTime.toStringAsFixed(1)}ms, '
        'avgDetect: ${averageDetectionTime.toStringAsFixed(1)}ms, '
        'avgProcess: ${averageProcessingTime.toStringAsFixed(1)}ms, '
        'maxFrame: ${maxFrameTime.toStringAsFixed(1)}ms, '
        'level: $performanceLevel, '
        'recommendation: $recommendation)';
  }
}
