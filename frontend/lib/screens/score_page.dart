import 'dart:io';
import 'dart:math';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:dio/dio.dart';

import '../api/scoring_api.dart';
import '../models/character.dart';
import '../models/comprehensive_score.dart';

/// 评分页面 - 双模式显示
class ScorePage extends StatefulWidget {
  final XFile photo;
  final CharacterData character;

  const ScorePage({
    super.key,
    required this.photo,
    required this.character,
  });

  @override
  State<ScorePage> createState() => _ScorePageState();
}

class _ScorePageState extends State<ScorePage> {
  bool _isOverlayMode = true;
  double _overlayOpacity = 0.5;
  ComprehensiveScoreResult? _score;
  bool _isLoading = true;
  String? _errorMessage;
  String? _errorType;

  @override
  void initState() {
    super.initState();
    _scoreFromPhoto();
  }

  Future<void> _scoreFromPhoto() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
      _errorType = null;
    });

    try {
      final api = ScoringApi();
      final result = await api.scoreFromPhoto(
        character: widget.character.character,
        photo: widget.photo,
      );

      setState(() {
        _score = result;
        _errorType = result.errorType;
        _errorMessage = null;
        _isLoading = false;
      });
    } on DioException catch (e) {
      final data = e.response?.data;
      if (data is Map && data['detail'] is Map) {
        final detail = data['detail'] as Map;
        setState(() {
          _errorType = detail['error_type']?.toString();
          _errorMessage = detail['message']?.toString() ?? '无法评分';
          _isLoading = false;
        });
      } else {
        setState(() {
          _errorMessage = '无法评分：${e.message}';
          _isLoading = false;
        });
      }
    } catch (e) {
      setState(() {
        _errorMessage = '无法评分：$e';
        _isLoading = false;
      });
    }
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
    if (_isLoading) {
      return _buildLoading();
    }
    if (_errorMessage != null) {
      return _buildError();
    }
    return Column(
      children: [
        _buildOpacitySlider(),
        Expanded(
          child: Stack(
            children: [
              // Layer 1: 用户照片
              Positioned.fill(
                child: Image.file(
                  File(widget.photo.path),
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
    if (_isLoading) {
      return _buildLoading();
    }
    if (_errorMessage != null) {
      return _buildError();
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
                File(widget.photo.path),
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
    if (_score == null) return const SizedBox.shrink();

    return Container(
      padding: const EdgeInsets.all(16.0),
      color: Colors.grey.shade100,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          _buildScoreItem('总分', '${_score!.totalScore.toStringAsFixed(0)}分', _score!.gradeColor),
          _buildScoreItem('等级', _score!.grade, _score!.gradeColor),
          _buildScoreItem('完美笔画', '${_score!.perfectStrokes}/${_score!.strokeAnalysis.length}', Colors.blue),
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
    if (_score == null) return const SizedBox.shrink();

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
                    color: _score!.gradeColor,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    '${_score!.totalScore.toStringAsFixed(0)}分',
                    style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                  ),
                ),
              ],
            ),
            const Divider(height: 24),
            _buildScoreRow('等级', _score!.grade, _score!.gradeColor),
            _buildScoreRow('笔画数', '${_score!.strokeAnalysis.length} 笔', Colors.grey),
            _buildScoreRow('完美笔画', '${_score!.perfectStrokes} 笔', Colors.green),
            _buildScoreRow('书写得分', '${_score!.handwritingScore.toStringAsFixed(1)}分', Colors.blue),
            if (_score!.errorType != null) ...[
              const SizedBox(height: 12),
              Text(
                '无法评分：${_score!.message ?? _score!.feedback}',
                style: const TextStyle(color: Colors.red),
              ),
              const SizedBox(height: 4),
              Text(
                'error_type: ${_score!.errorType}',
                style: const TextStyle(color: Colors.grey, fontSize: 12),
              ),
            ],
            if (_score!.feedback.isNotEmpty) ...[
              const SizedBox(height: 16),
              const Text('评语', style: TextStyle(fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              Text(_score!.feedback),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildLoading() {
    return const Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          CircularProgressIndicator(),
          SizedBox(height: 12),
          Text('评分中...'),
        ],
      ),
    );
  }

  Widget _buildError() {
    final message = _errorMessage ?? '无法评分';
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.error, color: Colors.red, size: 48),
          const SizedBox(height: 12),
          Text('无法评分：$message', textAlign: TextAlign.center),
          if (_errorType != null) ...[
            const SizedBox(height: 8),
            Text('error_type: $_errorType', style: const TextStyle(color: Colors.grey)),
          ],
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              ElevatedButton(
                onPressed: _scoreFromPhoto,
                child: const Text('重试'),
              ),
              const SizedBox(width: 12),
              OutlinedButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('返回'),
              ),
            ],
          ),
        ],
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

  static const bool _flipX = false;
  static const bool _flipY = true;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.red
      ..strokeWidth = 3.0
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round
      ..style = PaintingStyle.stroke;

    canvas.save();
    _applyAxisFlip(canvas, size);

    for (final stroke in strokes) {
      final path = _parseSvgPath(stroke.path, size);
      if (path != null) {
        canvas.drawPath(path, paint);
      }
    }

    if (kDebugMode) {
      _drawDebugCorners(canvas, size);
    }

    canvas.restore();
  }

  void _applyAxisFlip(Canvas canvas, Size size) {
    final scaleX = _flipX ? -1.0 : 1.0;
    final scaleY = _flipY ? -1.0 : 1.0;
    final translateX = _flipX ? size.width : 0.0;
    final translateY = _flipY ? size.height : 0.0;
    canvas.translate(translateX, translateY);
    canvas.scale(scaleX, scaleY);
  }

  void _drawDebugCorners(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.yellow
      ..style = PaintingStyle.fill;
    const r = 6.0;
    final points = <Offset>[
      const Offset(0, 0),
      Offset(size.width, 0),
      Offset(0, size.height),
      Offset(size.width, size.height),
    ];
    for (final p in points) {
      canvas.drawCircle(p, r, paint);
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
