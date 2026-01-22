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
    // 构建 SVG 字符串
    final svgPaths = character.strokes.map((stroke) => stroke.path).join(' ');

    return SizedBox(
      width: 200,
      height: 200,
      child: CustomPaint(
        painter: _StrokePainter(strokes: character.strokes),
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

    // 绘制每个笔画
    for (final stroke in strokes) {
      if (stroke.points.isEmpty) continue;

      final path = Path();

      for (int i = 0; i < stroke.points.length; i++) {
        final point = stroke.points[i];
        final offset = Offset(
          point.x * size.width,
          point.y * size.height,
        );

        if (i == 0) {
          path.moveTo(offset.dx, offset.dy);
        } else {
          path.lineTo(offset.dx, offset.dy);
        }
      }

      canvas.drawPath(path, strokePaint);
    }
  }

  @override
  bool shouldRepaint(_StrokePainter oldDelegate) {
    return strokes != oldDelegate.strokes;
  }
}
