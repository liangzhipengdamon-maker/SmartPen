import 'dart:io';
import 'dart:math';
import 'package:flutter/material.dart';
import '../models/character.dart';

/// 评分页面 - 双模式显示
class ScorePage extends StatefulWidget {
  final String imagePath;
  final CharacterData character;

  const ScorePage({
    super.key,
    required this.imagePath,
    required this.character,
  });

  @override
  State<ScorePage> createState() => _ScorePageState();
}

class _ScorePageState extends State<ScorePage> {
  bool _isOverlayMode = true;
  double _overlayOpacity = 0.5;
  ScoreResult? _mockScore;

  @override
  void initState() {
    super.initState();
    _generateMockScore();
  }

  void _generateMockScore() {
    final random = DateTime.now().millisecondsSinceEpoch % 30;
    _mockScore = ScoreResult(
      totalScore: 70.0 + random.toDouble(),
      strokeCount: widget.character.strokeCount ?? widget.character.strokes.length,
      perfectStrokes: (widget.character.strokes.length * 0.7).toInt(),
      averageScore: 75.0 + (random / 2),
      feedback: '整体结构良好，注意笔画顺序',
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('评分结果'),
        actions: [
          IconButton(
            icon: Icon(_isOverlayMode ? Icons.visibility : Icons.assessment),
            onPressed: () {
              setState(() {
                _isOverlayMode = !_isOverlayMode;
              });
            },
            tooltip: _isOverlayMode ? '切换到报告模式' : '切换到描红模式',
          ),
        ],
      ),
      body: _isOverlayMode ? _buildOverlayMode() : _buildReportMode(),
    );
  }

  /// Overlay 模式 - 数字描红台
  Widget _buildOverlayMode() {
    return Column(
      children: [
        _buildOpacitySlider(),
        Expanded(
          child: Stack(
            children: [
              // Layer 1: 用户照片
              Positioned.fill(
                child: Image.file(
                  File(widget.imagePath),
                  fit: BoxFit.contain,
                ),
              ),
              // Layer 2: 红色范字
              Positioned.fill(
                child: Opacity(
                  opacity: _overlayOpacity,
                  child: CustomPaint(
                    size: Size.infinite,
                    painter: _RedCharacterPainter(
                      strokes: widget.character.strokes,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
        _buildScoreSummary(),
      ],
    );
  }

  /// Report 模式 - 传统报告视图
  Widget _buildReportMode() {
    if (_mockScore == null) {
      return const Center(child: CircularProgressIndicator());
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: double.infinity,
            height: 300,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.grey.shade300),
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: Image.file(
                File(widget.imagePath),
                fit: BoxFit.contain,
              ),
            ),
          ),
          const SizedBox(height: 24),
          _buildScoreCard(),
        ],
      ),
    );
  }

  /// 透明度滑块
  Widget _buildOpacitySlider() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
      color: Colors.grey.shade100,
      child: Row(
        children: [
          const Icon(Icons.layers, color: Colors.grey),
          const SizedBox(width: 8),
          const Text('范字透明度', style: TextStyle(fontWeight: FontWeight.bold)),
          const SizedBox(width: 16),
          Expanded(
            child: Slider(
              value: _overlayOpacity,
              min: 0.0,
              max: 1.0,
              divisions: 10,
              onChanged: (value) {
                setState(() {
                  _overlayOpacity = value;
                });
              },
            ),
          ),
          Text('${(_overlayOpacity * 100).toInt()}%'),
        ],
      ),
    );
  }

  /// 底部评分摘要
  Widget _buildScoreSummary() {
    if (_mockScore == null) return const SizedBox.shrink();

    return Container(
      padding: const EdgeInsets.all(16.0),
      color: Colors.grey.shade100,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          _buildScoreItem('总分', '${_mockScore!.totalScore.toStringAsFixed(0)}分', _mockScore!.gradeColor),
          _buildScoreItem('等级', _mockScore!.grade, _mockScore!.gradeColor),
          _buildScoreItem('完美笔画', '${_mockScore!.perfectStrokes}/${_mockScore!.strokeCount}', Colors.blue),
        ],
      ),
    );
  }

  Widget _buildScoreItem(String label, String value, Color color) {
    return Column(
      children: [
        Text(label, style: const TextStyle(color: Colors.grey)),
        const SizedBox(height: 4),
        Text(value, style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: color)),
      ],
    );
  }

  /// 评分卡片
  Widget _buildScoreCard() {
    if (_mockScore == null) return const SizedBox.shrink();

    return Card(
      elevation: 4,
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('评分结果', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: _mockScore!.gradeColor,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    '${_mockScore!.totalScore.toStringAsFixed(0)}分',
                    style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                  ),
                ),
              ],
            ),
            const Divider(height: 24),
            _buildScoreRow('等级', _mockScore!.grade, _mockScore!.gradeColor),
            _buildScoreRow('笔画数', '${_mockScore!.strokeCount} 笔', Colors.grey),
            _buildScoreRow('完美笔画', '${_mockScore!.perfectStrokes} 笔', Colors.green),
            _buildScoreRow('平均得分', '${_mockScore!.averageScore.toStringAsFixed(1)}分', Colors.blue),
            if (_mockScore!.feedback != null) ...[
              const SizedBox(height: 16),
              const Text('评语', style: TextStyle(fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              Text(_mockScore!.feedback!),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildScoreRow(String label, String value, Color color) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(color: Colors.grey)),
          Text(value, style: TextStyle(color: color, fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }
}

/// 红色范字绘制器（用于 Overlay 模式）
class _RedCharacterPainter extends CustomPainter {
  final List<StrokeData> strokes;

  _RedCharacterPainter({required this.strokes});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.red
      ..strokeWidth = 3.0
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
          x = double.parse(commands[i]) / 1024 * size.width;
          i++;
          y = double.parse(commands[i]) / 1024 * size.height;
          startX = x;
          startY = y;
          path.moveTo(x, y);
        } else if (cmd == 'L' || cmd == 'l') {
          i++;
          x = double.parse(commands[i]) / 1024 * size.width;
          i++;
          y = double.parse(commands[i]) / 1024 * size.height;
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
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}
