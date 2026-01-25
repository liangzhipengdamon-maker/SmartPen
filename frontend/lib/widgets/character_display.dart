import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../models/character.dart';

/// 字符显示组件 - 显示范字
class CharacterDisplay extends StatelessWidget {
  final CharacterData character;

  const CharacterDisplay({
    super.key,
    required this.character,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.all(16.0),
      decoration: BoxDecoration(
        border: Border.all(color: Colors.grey.shade300),
        borderRadius: BorderRadius.circular(8.0),
        color: Colors.grey.shade50,
      ),
      child: Column(
        children: [
          // 标题栏
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            decoration: BoxDecoration(
              color: Colors.blue.shade100,
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(8.0),
                topRight: Radius.circular(8.0),
              ),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  '范字',
                  style: Theme.of(context).textTheme.titleSmall,
                ),
                Text(
                  '笔画: ${character.strokeCount ?? character.strokes.length}',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ],
            ),
          ),

          // 字符显示区域
          Expanded(
            child: Center(
              child: _buildCharacterContent(),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCharacterContent() {
    // 如果有 SVG path，使用 flutter_svg 渲染
    if (character.strokes.isNotEmpty) {
      return _buildSvgCharacter();
    }

    // 否则显示文字
    return _buildTextCharacter();
  }

  Widget _buildSvgCharacter() {
    // 使用 CustomPaint 直接绘制 SVG 路径
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(color: Colors.grey.shade300),
        borderRadius: BorderRadius.circular(8.0),
      ),
      child: Transform(
        alignment: Alignment.center,
        transform: Matrix4.identity()..scale(1.0, -1.0, 1.0),
        child: CustomPaint(
          size: const Size(200, 200),
          painter: _SvgPathPainter(strokes: character.strokes),
        ),
      ),
    );
  }

  Widget _buildTextCharacter() {
    return Container(
      width: 200,
      height: 200,
      decoration: BoxDecoration(
        border: Border.all(color: Colors.grey.shade300),
        borderRadius: BorderRadius.circular(8.0),
      ),
      child: Center(
        child: Text(
          character.character,
          style: const TextStyle(
            fontSize: 120,
            fontFamily: 'Courier',
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
    );
  }
}

/// 笔画绘制器
class _StrokePainter extends CustomPainter {
  final List<StrokeData> strokes;

  _StrokePainter({required this.strokes});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.black
      ..strokeWidth = 8.0
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    final strokePaint = Paint()
      ..color = Colors.black
      ..strokeWidth = 8.0
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    // DEBUG: 打印笔画信息
    debugPrint('=== StrokePainter DEBUG ===');
    debugPrint('Total strokes: ${strokes.length}');
    debugPrint('Canvas size: ${size.width} x ${size.height}');

    // 绘制每个笔画
    for (final stroke in strokes) {
      debugPrint('Stroke ${strokes.indexOf(stroke)}: points.length = ${stroke.points.length}');
      if (stroke.points.isEmpty) {
        debugPrint('  -> Skipping: points is empty!');
        continue;
      }

      final path = Path();

      for (int i = 0; i < stroke.points.length; i++) {
        final point = stroke.points[i];
        final offset = Offset(
          point.x * size.width,
          point.y * size.height,
        );

        if (i == 0) {
          path.moveTo(offset.dx, offset.dy);
          debugPrint('  -> MoveTo: (${offset.dx.toStringAsFixed(2)}, ${offset.dy.toStringAsFixed(2)})');
        } else {
          path.lineTo(offset.dx, offset.dy);
        }
      }

      canvas.drawPath(path, strokePaint);
      debugPrint('  -> Drew path with ${stroke.points.length} points');
    }
    debugPrint('=== END DEBUG ===');
  }

  @override
  bool shouldRepaint(_StrokePainter oldDelegate) {
    return strokes != oldDelegate.strokes;
  }
}

/// SVG 路径绘制器 - 直接解析 SVG path 字符串并绘制
class _SvgPathPainter extends CustomPainter {
  final List<StrokeData> strokes;

  _SvgPathPainter({required this.strokes});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.black
      ..strokeWidth = 3.0  // 减小笔画宽度
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round
      ..style = PaintingStyle.stroke;

    for (final stroke in strokes) {
      final path = _parseSvgPath(stroke.path, size);
      if (path != null) {
        canvas.drawPath(path, paint);
      }
    }
  }

  Path? _parseSvgPath(String pathString, Size size) {
    try {
      final path = Path();
      final commands = pathString.replaceAll('  ', ' ').trim().split(' ');

      double x = 0, y = 0;
      double startX = 0, startY = 0;

      for (int i = 0; i < commands.length; i++) {
        final cmd = commands[i];

        if (cmd == 'M' || cmd == 'm') {
          i++;
          final num1 = double.parse(commands[i]) / 1024 * size.width;
          i++;
          final num2 = double.parse(commands[i]) / 1024 * size.height;
          x = num1;
          y = num2;
          startX = x;
          startY = y;
          path.moveTo(x, y);
        } else if (cmd == 'L' || cmd == 'l') {
          i++;
          final num1 = double.parse(commands[i]) / 1024 * size.width;
          i++;
          final num2 = double.parse(commands[i]) / 1024 * size.height;
          x = num1;
          y = num2;
          path.lineTo(x, y);
        } else if (cmd == 'Q' || cmd == 'q') {
          i++;
          final cx = double.parse(commands[i]) / 1024 * size.width;
          i++;
          final cy = double.parse(commands[i]) / 1024 * size.height;
          i++;
          final ex = double.parse(commands[i]) / 1024 * size.width;
          i++;
          final ey = double.parse(commands[i]) / 1024 * size.height;
          x = ex;
          y = ey;
          path.quadraticBezierTo(cx, cy, ex, ey);
        } else if (cmd == 'Z' || cmd == 'z') {
          path.close();
          x = startX;
          y = startY;
        }
      }
      return path;
    } catch (e) {
      return null;
    }
  }

  @override
  bool shouldRepaint(_SvgPathPainter oldDelegate) {
    return strokes != oldDelegate.strokes;
  }
}
