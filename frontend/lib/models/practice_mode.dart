/// 练习模式枚举
enum PracticeMode {
  basic,
  expert,
  custom,
  timed;

  String get value {
    switch (this) {
      case PracticeMode.basic:
        return 'basic';
      case PracticeMode.expert:
        return 'expert';
      case PracticeMode.custom:
        return 'custom';
      case PracticeMode.timed:
        return 'timed';
    }
  }

  String get displayName {
    switch (this) {
      case PracticeMode.basic:
        return '基础模式';
      case PracticeMode.expert:
        return '专家模式';
      case PracticeMode.custom:
        return '自定义模式';
      case PracticeMode.timed:
        return '计时模式';
    }
  }

  String get description {
    switch (this) {
      case PracticeMode.basic:
        return '适合初学者，提供详细指导';
      case PracticeMode.expert:
        return '高标准要求，挑战满分';
      case PracticeMode.custom:
        return '使用教师提供的范字';
      case PracticeMode.timed:
        return '限时完成，提升书写速度';
    }
  }

  static PracticeMode fromValue(String value) {
    switch (value) {
      case 'basic':
        return PracticeMode.basic;
      case 'expert':
        return PracticeMode.expert;
      case 'custom':
        return PracticeMode.custom;
      case 'timed':
        return PracticeMode.timed;
      default:
        return PracticeMode.basic;
    }
  }
}

/// 练习模式配置
class PracticeModeConfig {
  final PracticeMode mode;
  final bool showStrokeHint;
  final double scoreThreshold; // 及格分数线
  final int? timeLimit; // 秒，null 表示无限制
  final bool strictOrder; // 是否严格检查笔顺
  final bool enablePostureAlert; // 是否启用姿态提醒
  final bool enableGripAlert; // 是否启用握笔提醒

  const PracticeModeConfig({
    required this.mode,
    this.showStrokeHint = true,
    this.scoreThreshold = 60.0,
    this.timeLimit,
    this.strictOrder = false,
    this.enablePostureAlert = true,
    this.enableGripAlert = true,
  });

  /// 获取各模式的默认配置
  static PracticeModeConfig getConfig(PracticeMode mode) {
    switch (mode) {
      case PracticeMode.basic:
        return const PracticeModeConfig(
          mode: PracticeMode.basic,
          showStrokeHint: true,
          scoreThreshold: 60.0,
          strictOrder: false,
          enablePostureAlert: true,
          enableGripAlert: true,
        );

      case PracticeMode.expert:
        return const PracticeModeConfig(
          mode: PracticeMode.expert,
          showStrokeHint: false,
          scoreThreshold: 90.0,
          strictOrder: true,
          enablePostureAlert: true,
          enableGripAlert: true,
        );

      case PracticeMode.custom:
        return const PracticeModeConfig(
          mode: PracticeMode.custom,
          showStrokeHint: true,
          scoreThreshold: 70.0,
          strictOrder: true,
          enablePostureAlert: true,
          enableGripAlert: true,
        );

      case PracticeMode.timed:
        return const PracticeModeConfig(
          mode: PracticeMode.timed,
          showStrokeHint: false,
          scoreThreshold: 70.0,
          timeLimit: 30, // 30 秒
          strictOrder: false,
          enablePostureAlert: false,
          enableGripAlert: false,
        );
    }
  }
}

/// 练习会话状态
class PracticeSession {
  final String characterId;
  final String character;
  final PracticeMode mode;
  final DateTime startTime;
  final List<Stroke> userStrokes;
  final bool isCompleted;
  final int? finalScore;
  final Duration? timeSpent;

  const PracticeSession({
    required this.characterId,
    required this.character,
    required this.mode,
    required this.startTime,
    this.userStrokes = const [],
    this.isCompleted = false,
    this.finalScore,
    this.timeSpent,
  });

  PracticeSession copyWith({
    String? characterId,
    String? character,
    PracticeMode? mode,
    DateTime? startTime,
    List<Stroke>? userStrokes,
    bool? isCompleted,
    int? finalScore,
    Duration? timeSpent,
  }) {
    return PracticeSession(
      characterId: characterId ?? this.characterId,
      character: character ?? this.character,
      mode: mode ?? this.mode,
      startTime: startTime ?? this.startTime,
      userStrokes: userStrokes ?? this.userStrokes,
      isCompleted: isCompleted ?? this.isCompleted,
      finalScore: finalScore ?? this.finalScore,
      timeSpent: timeSpent ?? this.timeSpent,
    );
  }
}

/// 笔画数据
class Stroke {
  final List<PointD> points;
  final int order;

  const Stroke({
    required this.points,
    required this.order,
  });

  double get length {
    if (points.isEmpty) return 0;
    double total = 0;
    for (int i = 1; i < points.length; i++) {
      final dx = points[i].x - points[i - 1].x;
      final dy = points[i].y - points[i - 1].y;
      total += (dx * dx + dy * dy);
    }
    return total;
  }
}

/// 二维点（double）
class PointD {
  final double x;
  final double y;

  const PointD(this.x, this.y);

  factory PointD.fromJson(Map<String, dynamic> json) {
    return PointD(
      (json['x'] as num).toDouble(),
      (json['y'] as num).toDouble(),
    );
  }

  Map<String, dynamic> toJson() {
    return {'x': x, 'y': y};
  }

  PointD operator -(PointD other) {
    return PointD(x - other.x, y - other.y);
  }

  PointD operator +(PointD other) {
    return PointD(x + other.x, y + other.y);
  }

  double distanceTo(PointD other) {
    final dx = x - other.x;
    final dy = y - other.y;
    return (dx * dx + dy * dy);
  }
}
