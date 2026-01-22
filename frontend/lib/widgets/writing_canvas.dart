import 'package:flutter/material.dart';
import 'package:flutter/material.dart' as material;
import 'package:provider/provider.dart';

import '../providers/character_provider.dart';
import '../models/character.dart';

/// 书写画布 - 用户在此处书写字符
class WritingCanvas extends StatefulWidget {
  final VoidCallback? onStrokeComplete;

  const WritingCanvas({
    super.key,
    this.onStrokeComplete,
  });

  @override
  State<WritingCanvas> createState() => _WritingCanvasState();
}

class _WritingCanvasState extends State<WritingCanvas> {
  final GlobalKey _canvasKey = GlobalKey();
  final List<Offset> _currentStroke = [];
  bool _isDrawing = false;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.all(16.0),
      decoration: BoxDecoration(
        border: Border.all(color: Colors.grey.shade300),
        borderRadius: BorderRadius.circular(8.0),
        color: Colors.white,
      ),
      child: Column(
        children: [
          // 标题栏
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            decoration: BoxDecoration(
              color: Colors.grey.shade100,
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(8.0),
                topRight: Radius.circular(8.0),
              ),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('书写区域'),
                Consumer<CharacterProvider>(
                  builder: (context, provider, child) {
                    return Text(
                      '笔画: ${provider.strokeCount}',
                      style: Theme.of(context).textTheme.bodySmall,
                    );
                  },
                ),
              ],
            ),
          ),

          // 画布
          Expanded(
            child: GestureDetector(
              onPanStart: _handlePanStart,
              onPanUpdate: _handlePanUpdate,
              onPanEnd: _handlePanEnd,
              behavior: HitTestBehavior.opaque,
              child: CustomPaint(
                key: _canvasKey,
                size: Size.infinite,
                painter: _CanvasPainter(
                  strokes: context.select<CharacterProvider, List<List<PointData>>>(
                    (provider) => provider.userStrokes,
                    (strokes) => strokes,
                  ),
                  currentStroke: _currentStroke,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _handlePanStart(DragStartDetails details) {
    setState(() {
      _isDrawing = true;
      _currentStroke.clear();
      _currentStroke.add(details.localPosition);
    });
    context.read<CharacterProvider>().startStroke();
  }

  void _handlePanUpdate(DragUpdateDetails details) {
    if (!_isDrawing) return;

    setState(() {
      _currentStroke.add(details.localPosition);
    });

    // 转换为归一化坐标并添加到 provider
    final renderBox = context.findRenderObject() as RenderBox?;
    if (renderBox != null) {
      final size = renderBox.size;
      final point = PointData(
        x: details.localPosition.dx / size.width,
        y: details.localPosition.dy / size.height,
      );
      context.read<CharacterProvider>().addPoint(point);
    }
  }

  void _handlePanEnd(DragEndDetails details) {
    setState(() {
      _isDrawing = false;
      _currentStroke.clear();
    });
    context.read<CharacterProvider>().endStroke();
    widget.onStrokeComplete?.call();
  }
}

/// 画布绘制器
class _CanvasPainter extends CustomPainter {
  final List<List<PointData>> strokes;
  final List<Offset> currentStroke;

  _CanvasPainter({
    required this.strokes,
    required this.currentStroke,
  });

  @override
  void paint(Canvas canvas, Size size) {
    // 绘制网格背景
    _drawGrid(canvas, size);

    // 绘制已完成的笔画
    for (final stroke in strokes) {
      _drawStroke(canvas, size, stroke, Colors.black);
    }

    // 绘制当前笔画
    if (currentStroke.isNotEmpty) {
      _drawCurrentStroke(canvas, currentStroke);
    }
  }

  void _drawGrid(Canvas canvas, Size size) {
    final gridPaint = Paint()
      ..color = Colors.grey.shade200
      ..strokeWidth = 0.5;

    // 绘制米字格
    // 外框
    canvas.drawRect(
      Rect.fromPoints(const Offset(0, 0), Offset(size.width, size.height)),
      gridPaint,
    );

    // 对角线
    canvas.drawLine(
      const Offset(0, 0),
      Offset(size.width, size.height),
      gridPaint,
    );
    canvas.drawLine(
      Offset(size.width, 0),
      Offset(0, size.height),
      gridPaint,
    );

    // 中线
    canvas.drawLine(
      Offset(size.width / 2, 0),
      Offset(size.width / 2, size.height),
      gridPaint,
    );
    canvas.drawLine(
      Offset(0, size.height / 2),
      Offset(size.width, size.height / 2),
      gridPaint,
    );
  }

  void _drawStroke(Canvas canvas, Size size, List<PointData> stroke, Color color) {
    if (stroke.isEmpty) return;

    final paint = Paint()
      ..color = color
      ..strokeWidth = 3.0
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    final path = Path();

    for (int i = 0; i < stroke.length; i++) {
      final point = stroke[i];
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

    canvas.drawPath(path, paint);
  }

  void _drawCurrentStroke(Canvas canvas, List<Offset> stroke) {
    if (stroke.isEmpty) return;

    final paint = Paint()
      ..color = Colors.blue.shade700
      ..strokeWidth = 3.0
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    final path = Path();

    for (int i = 0; i < stroke.length; i++) {
      if (i == 0) {
        path.moveTo(stroke[i].dx, stroke[i].dy);
      } else {
        path.lineTo(stroke[i].dx, stroke[i].dy);
      }
    }

    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(_CanvasPainter oldDelegate) {
    return true;
  }
}
