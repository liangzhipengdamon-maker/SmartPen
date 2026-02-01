import 'package:flutter/material.dart';
import 'character.dart';

/// 姿态分析结果 (API 模型)
class ApiPostureAnalysis {
  final bool isCorrect; // 姿态是否正确
  final double score; // 姿态得分 0-100
  final String level; // 等级: good, warning, critical
  final List<String> issues; // 检测到的问题列表
  final String feedback; // 反馈文本
  final double spineAngle; // 脊柱角度
  final double eyeScreenDistance; // 眼屏距离
  final double headTilt; // 头部倾斜

  ApiPostureAnalysis({
    required this.isCorrect,
    required this.score,
    required this.level,
    required this.issues,
    required this.feedback,
    required this.spineAngle,
    required this.eyeScreenDistance,
    required this.headTilt,
  });

  factory ApiPostureAnalysis.fromJson(Map<String, dynamic> json) {
    return ApiPostureAnalysis(
      isCorrect: json['is_correct'] ?? false,
      score: (json['score'] ?? 0.0).toDouble(),
      level: json['level'] ?? 'unknown',
      issues: (json['issues'] as List?)?.cast<String>() ?? [],
      feedback: json['feedback'] ?? '',
      spineAngle: (json['spine_angle'] ?? 0.0).toDouble(),
      eyeScreenDistance: (json['eye_screen_distance'] ?? 0.0).toDouble(),
      headTilt: (json['head_tilt'] ?? 0.0).toDouble(),
    );
  }

  /// 获取等级对应的颜色
  Color get levelColor {
    switch (level) {
      case 'good':
        return Colors.green;
      case 'warning':
        return Colors.orange;
      case 'critical':
        return Colors.red;
      default:
        return Colors.grey;
    }
  }

  /// 获取等级对应的图标
  IconData get levelIcon {
    switch (level) {
      case 'good':
        return Icons.check_circle;
      case 'warning':
        return Icons.warning;
      case 'critical':
        return Icons.error;
      default:
        return Icons.help;
    }
  }
}

/// 笔画分析结果
class StrokeAnalysisResult {
  final int strokeIndex; // 笔画索引
  final double similarity; // 相似度 0-1
  final double score; // 得分 0-100
  final List<String> issues; // 问题列表

  StrokeAnalysisResult({
    required this.strokeIndex,
    required this.similarity,
    required this.score,
    required this.issues,
  });

  factory StrokeAnalysisResult.fromJson(Map<String, dynamic> json) {
    return StrokeAnalysisResult(
      strokeIndex: json['stroke_index'] ?? 0,
      similarity: (json['similarity'] ?? 0.0).toDouble(),
      score: (json['score'] ?? 0.0).toDouble(),
      issues: (json['issues'] as List?)?.cast<String>() ?? [],
    );
  }
}

/// 综合评分结果 - 结合书写质量和姿态评分
class ComprehensiveScoreResult {
  final double totalScore; // 总分 0-100
  final double handwritingScore; // 书写得分 (70% 权重)
  final double postureScore; // 姿态得分 (30% 权重)
  final String grade; // 等级
  final List<StrokeAnalysisResult> strokeAnalysis; // 各笔画分析
  final ApiPostureAnalysis? postureAnalysis; // 姿态分析 (API 模型)
  final String feedback; // 综合反馈
  final String? errorType; // 错误类型（可选）
  final String? message; // 错误信息（可选）

  ComprehensiveScoreResult({
    required this.totalScore,
    required this.handwritingScore,
    required this.postureScore,
    required this.grade,
    required this.strokeAnalysis,
    this.postureAnalysis,
    required this.feedback,
    this.errorType,
    this.message,
  });

  factory ComprehensiveScoreResult.fromJson(Map<String, dynamic> json) {
    return ComprehensiveScoreResult(
      totalScore: (json['total_score'] ?? 0.0).toDouble(),
      handwritingScore: (json['handwriting_score'] ?? 0.0).toDouble(),
      postureScore: (json['posture_score'] ?? 0.0).toDouble(),
      grade: json['grade'] ?? '需练习',
      strokeAnalysis: (json['stroke_analysis'] as List?)
              ?.map((s) => StrokeAnalysisResult.fromJson(s))
              .toList() ??
          [],
      postureAnalysis: json['posture_analysis'] != null
          ? ApiPostureAnalysis.fromJson(json['posture_analysis'])
          : null,
      feedback: json['feedback'] ?? '',
      errorType: json['error_type'],
      message: json['message'],
    );
  }

  /// 获取等级颜色
  Color get gradeColor {
    if (totalScore >= 90) return Colors.green;
    if (totalScore >= 80) return Colors.blue;
    if (totalScore >= 60) return Colors.orange;
    return Colors.red;
  }

  /// 获取完美的笔画数量
  int get perfectStrokes {
    return strokeAnalysis.where((s) => s.score >= 95).length;
  }

  /// 获取有问题的笔画
  List<StrokeAnalysisResult> get problemStrokes {
    return strokeAnalysis.where((s) => s.score < 60).toList();
  }
}

/// 姿态数据 - 用于提交到后端
class PostureData {
  final double spineAngle; // 脊柱角度
  final double eyeScreenDistance; // 眼屏距离
  final double headTilt; // 头部倾斜
  final DateTime? timestamp; // 时间戳

  PostureData({
    required this.spineAngle,
    required this.eyeScreenDistance,
    required this.headTilt,
    this.timestamp,
  });

  Map<String, dynamic> toJson() {
    return {
      'spine_angle': spineAngle,
      'eye_screen_distance': eyeScreenDistance,
      'head_tilt': headTilt,
      if (timestamp != null) 'timestamp': timestamp!.toIso8601String(),
    };
  }
}
