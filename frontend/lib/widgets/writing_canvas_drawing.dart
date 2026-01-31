import 'package:flutter/material.dart';

/// 书写画布组件 - 支持手指/触控书写的田字格画布
class WritingCanvasDrawing extends StatefulWidget {
  final VoidCallback? onStrokeComplete;

  const WritingCanvasDrawing({
    super.key,
    this.onStrokeComplete,
  });

  @override
  State<WritingCanvasDrawing> createState() => _WritingCanvasDrawingState();
}

class _WritingCanvasDrawingState extends State<WritingCanvasDrawing> {
  // 所有笔画
  final List<Path> _strokes = [];

  // 当前正在绘制的笔画
  Path? _currentStroke;

  // 当前笔画的关键点（用于平滑）
  final List<Offset> _currentPoints = [];

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(color: Colors.grey.shade300),
        borderRadius: BorderRadius.circular(8.0),
      ),
      child: GestureDetector(
        onPanStart: _handlePanStart,
        onPanUpdate: _handlePanUpdate,
        onPanEnd: _handlePanEnd,
        child: CustomPaint(
          painter: GridPainter(
            strokes: _strokes,
            currentStroke: _currentStroke,
          ),
          size: Size.infinite,
        ),
      ),
    );
  }

  void _handlePanStart(DragStartDetails details) {
    final localPosition = details.localPosition;
    setState(() {
      _currentStroke = Path();
      _currentStroke!.moveTo(localPosition.dx, localPosition.dy);
      _currentPoints.clear();
      _currentPoints.add(localPosition);
    });
  }

  void _handlePanUpdate(DragUpdateDetails details) {
    final localPosition = details.localPosition;
    setState(() {
      _currentStroke!.lineTo(localPosition.dx, localPosition.dy);
      _currentPoints.add(localPosition);
    });
  }

  void _handlePanEnd(DragEndDetails details) {
    setState(() {
      if (_currentStroke != null) {
        _strokes.add(_currentStroke!);
        _currentStroke = null;
        _currentPoints.clear();
        widget.onStrokeComplete?.call();
      }
    });
  }

  /// 撤销最后一笔
  void undo() {
    setState(() {
      if (_strokes.isNotEmpty) {
        _strokes.removeLast();
      }
    });
  }

  /// 清空所有笔画
  void clear() {
    setState(() {
      _strokes.clear();
      _currentStroke = null;
      _currentPoints.clear();
    });
  }
}

/// 田字格画笔 - 绘制网格背景和笔画
class GridPainter extends CustomPainter {
  final List<Path> strokes;
  final Path? currentStroke;

  GridPainter({
    required this.strokes,
    this.currentStroke,
  });

  @override
  void paint(Canvas canvas, Size size) {
    // 1. 绘制白色背景
    canvas.drawRect(
      Rect.fromLTWH(0, 0, size.width, size.height),
      Paint()..color = Colors.white,
    );

    // 2. 绘制田字格网格
    _drawGrid(canvas, size);

    // 3. 绘制所有笔画
    _drawStrokes(canvas);
  }

  /// 绘制田字格网格
  void _drawGrid(Canvas canvas, Size size) {
    // 浅色网格线（内部线条）
    final gridPaint = Paint()
      ..color = Colors.red.shade100
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.0;

    // 深色边框线
    final borderPaint = Paint()
      ..color = Colors.red.shade300
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.0;

    // 外边框
    canvas.drawRect(
      Rect.fromLTWH(0, 0, size.width, size.height),
      borderPaint,
    );

    // 垂直中线
    canvas.drawLine(
      Offset(size.width / 2, 0),
      Offset(size.width / 2, size.height),
      gridPaint,
    );

    // 水平中线
    canvas.drawLine(
      Offset(0, size.height / 2),
      Offset(size.width, size.height / 2),
      gridPaint,
    );

    // 左上到右下对角线
    canvas.drawLine(
      const Offset(0, 0),
      Offset(size.width, size.height),
      gridPaint,
    );

    // 右上到左下对角线
    canvas.drawLine(
      Offset(size.width, 0),
      Offset(0, size.height),
      gridPaint,
    );
  }

  /// 绘制所有笔画
  void _drawStrokes(Canvas canvas) {
    final strokePaint = Paint()
      ..color = Colors.black
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3.0
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    // 绘制已保存的笔画
    for (final stroke in strokes) {
      canvas.drawPath(stroke, strokePaint);
    }

    // 绘制当前正在画的笔画
    if (currentStroke != null) {
      canvas.drawPath(currentStroke!, strokePaint);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}
