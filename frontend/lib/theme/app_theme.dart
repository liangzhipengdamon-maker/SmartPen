import 'package:flutter/material.dart';

/// 应用主题配置
class AppTheme {
  /// 亮色主题
  static ThemeData get lightTheme {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.light,
      colorScheme: ColorScheme.fromSeed(
        seedColor: const Color(0xFF2196F3), // 智笔蓝
        brightness: Brightness.light,
      ),
      // 字体
      fontFamily: 'PingFang SC',

      // AppBar 主题
      appBarTheme: const AppBarTheme(
        centerTitle: true,
        elevation: 0,
        backgroundColor: Color(0xFF2196F3),
        foregroundColor: Colors.white,
      ),

      // Card 主题
      cardTheme: CardTheme(
        elevation: 2,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
      ),

      // 按钮主题
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          elevation: 2,
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(8),
          ),
        ),
      ),

      // 输入框主题
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
        ),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 12,
        ),
      ),

      // 分数颜色
      extensions: [
        _ScoreColors(
          excellent: const Color(0xFF4CAF50), // 绿色
          good: const Color(0xFF2196F3), // 蓝色
          pass: const Color(0xFFFF9800), // 橙色
          fail: const Color(0xFFF44336), // 红色
        ),
      ],
    );
  }

  /// 暗色主题
  static ThemeData get darkTheme {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      colorScheme: ColorScheme.fromSeed(
        seedColor: const Color(0xFF2196F3),
        brightness: Brightness.dark,
      ),
      fontFamily: 'PingFang SC',

      appBarTheme: const AppBarTheme(
        centerTitle: true,
        elevation: 0,
        backgroundColor: Color(0xFF1565C0),
        foregroundColor: Colors.white,
      ),

      cardTheme: CardTheme(
        elevation: 2,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
      ),

      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          elevation: 2,
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(8),
          ),
        ),
      ),

      extensions: [
        _ScoreColors(
          excellent: const Color(0xFF66BB6A),
          good: const Color(0xFF42A5F5),
          pass: const Color(0xFFFFA726),
          fail: const Color(0xFFEF5350),
        ),
      ],
    );
  }

  /// 根据分数获取颜色
  static Color getScoreColor(BuildContext context, int score) {
    final scoreColors = context.dependOnInheritedWidgetOfExactType<_ScoreColors>();
    if (scoreColors == null) return Colors.grey;

    if (score >= 90) return scoreColors.excellent;
    if (score >= 80) return scoreColors.good;
    if (score >= 60) return scoreColors.pass;
    return scoreColors.fail;
  }

  /// 根据分数获取等级文本
  static String getScoreLevel(int score) {
    if (score >= 90) return '优秀';
    if (score >= 80) return '良好';
    if (score >= 60) return '及格';
    return '需努力';
  }

  /// 根据分数获取等级图标
  static IconData getScoreIcon(int score) {
    if (score >= 90) return Icons.emoji_events;
    if (score >= 80) return Icons.thumb_up;
    if (score >= 60) return Icons.check_circle;
    return Icons.arrow_upward;
  }
}

/// 分数颜色主题扩展
@immutable
class _ScoreColors extends ThemeExtension<_ScoreColors> {
  final Color excellent;
  final Color good;
  final Color pass;
  final Color fail;

  const _ScoreColors({
    required this.excellent,
    required this.good,
    required this.pass,
    required this.fail,
  });

  @override
  _ScoreColors copyWith({
    Color? excellent,
    Color? good,
    Color? pass,
    Color? fail,
  }) {
    return _ScoreColors(
      excellent: excellent ?? this.excellent,
      good: good ?? this.good,
      pass: pass ?? this.pass,
      fail: fail ?? this.fail,
    );
  }

  @override
  _ScoreColors lerp(ThemeExtension<_ScoreColors>? other, double t) {
    if (other is! _ScoreColors) return this;
    return _ScoreColors(
      excellent: Color.lerp(excellent, other.excellent, t)!,
      good: Color.lerp(good, other.good, t)!,
      pass: Color.lerp(pass, other.pass, t)!,
      fail: Color.lerp(fail, other.fail, t)!,
    );
  }
}

/// 常用间距
class AppSpacing {
  static const double xs = 4.0;
  static const double sm = 8.0;
  static const double md = 16.0;
  static const double lg = 24.0;
  static const double xl = 32.0;
  static const double xxl = 48.0;
}

/// 常用动画时长
class AppDuration {
  static const Duration fast = Duration(milliseconds: 150);
  static const Duration normal = Duration(milliseconds: 250);
  static const Duration slow = Duration(milliseconds: 350);
}
