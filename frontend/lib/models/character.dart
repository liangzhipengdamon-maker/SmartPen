import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

/// 字符数据模型
class CharacterData {
  final String character;
  final List<StrokeData> strokes;
  final String? imageUrl;
  final int? strokeCount;

  CharacterData({
    required this.character,
    required this.strokes,
    this.imageUrl,
    this.strokeCount,
  });

  factory CharacterData.fromJson(Map<String, dynamic> json) {
    return CharacterData(
      character: json['character'] ?? '',
      strokes: (json['strokes'] as List?)
              ?.map((s) => StrokeData.fromJson(s))
              .toList() ??
          [],
      imageUrl: json['image_url'],
      strokeCount: json['stroke_count'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'character': character,
      'strokes': strokes.map((s) => s.toJson()).toList(),
      'image_url': imageUrl,
      'stroke_count': strokeCount,
    };
  }

  /// 创建空字符数据（用于书写）
  factory CharacterData.empty(String character) {
    return CharacterData(
      character: character,
      strokes: [],
      strokeCount: 0,
    );
  }
}

/// 单个笔画数据
class StrokeData {
  final String path; // SVG path data
  final List<PointData> points; // 原始点坐标（0-1 归一化）

  StrokeData({
    required this.path,
    required this.points,
  });

  factory StrokeData.fromJson(Map<String, dynamic> json) {
    final pointsList = json['points'];
    final parsedPoints = (pointsList as List?)
            ?.map((p) => PointData.fromJson(p as Map<String, dynamic>))
            .toList() ??
        [];

    return StrokeData(
      path: json['path'] ?? '',
      points: parsedPoints,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'path': path,
      'points': points.map((p) => p.toJson()).toList(),
    };
  }
}

/// 笔画点数据（归一化坐标 0-1）
class PointData {
  final double x;
  final double y;

  PointData({
    required this.x,
    required this.y,
  });

  factory PointData.fromJson(Map<String, dynamic> json) {
    return PointData(
      x: (json['x'] ?? 0.0).toDouble(),
      y: (json['y'] ?? 0.0).toDouble(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'x': x,
      'y': y,
    };
  }

  /// 从 1024 网格坐标转换为归一化坐标
  factory PointData.fromHanzi1024(int x, int y) {
    return PointData(
      x: x / 1024.0,
      y: y / 1024.0,
    );
  }

  /// 转换为 1024 网格坐标
  (int, int) toHanzi1024() {
    return (x.round() * 1024, y.round() * 1024);
  }
}

/// 评分结果
class ScoreResult {
  final double totalScore; // 0-100
  final int strokeCount;
  final int perfectStrokes;
  final double averageScore;
  final String? feedback;

  ScoreResult({
    required this.totalScore,
    required this.strokeCount,
    required this.perfectStrokes,
    required this.averageScore,
    this.feedback,
  });

  factory ScoreResult.fromJson(Map<String, dynamic> json) {
    return ScoreResult(
      totalScore: (json['total_score'] ?? 0.0).toDouble(),
      strokeCount: json['stroke_count'] ?? 0,
      perfectStrokes: json['perfect_strokes'] ?? 0,
      averageScore: (json['average_score'] ?? 0.0).toDouble(),
      feedback: json['feedback'],
    );
  }

  /// 获取等级描述
  String get grade {
    if (totalScore >= 90) return '优秀';
    if (totalScore >= 70) return '良好';
    if (totalScore >= 50) return '及格';
    return '需练习';
  }

  /// 获取等级颜色
  Color get gradeColor {
    if (totalScore >= 90) return Colors.green;
    if (totalScore >= 70) return Colors.blue;
    if (totalScore >= 50) return Colors.orange;
    return Colors.red;
  }
}
