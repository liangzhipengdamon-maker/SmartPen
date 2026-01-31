# Digital Copybook UI & Dual-Mode Evaluation 实施计划

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development to implement this plan task-by-task.

**目标:** 将应用从"屏幕书写"模式转换为"真纸书写"模式，构建数字描红台评分系统。

**核心转变:** 移除数字画布 → 保留范字显示 → 添加拍照评分 → 实现叠加对比模式

---

## 架构概述

### 当前状态
- **主页面**: `lib/screens/home_screen.dart` - 通过 `_isCalibrating` 状态切换校准/练习模式
- **练习组件**: `CharacterDisplay`（范字，需保留）+ `WritingCanvasDrawing`（数字画布，需移除）
- **数据模型**: `PostureAnalysis` 缺少握笔状态字段
- **评分 API**: 只接收笔画坐标，不支持图片上传

### 关键约束
1. 后端不支持图片上传 → 使用 Mock 评分
2. 姿态监测必须保持功能
3. ML Kit Pose Detection 已提供手腕 landmarks 用于握笔检测

---

## Task 1: 数据模型扩展 - 添加握笔状态

**目标:** 扩展数据模型以支持握笔状态检测和 UI 显示。

**Files:**
- Modify: `/Users/Zhuanz/Documents/01_SmartPen/smartpen-project/frontend/lib/services/posture_data.dart`
- Modify: `/Users/Zhuanz/Documents/01_SmartPen/smartpen-project/frontend/lib/services/posture_detector.dart`

### Step 1: 添加 GripState 枚举

在 `posture_data.dart` 中添加：

```dart
/// 握笔状态枚举
enum GripState {
  unknown,      // 未知状态
  holdingPen,   // 正在握笔
  noHand,       // 无手部可见
  badGrip,      // 握笔姿势不佳（Sprint 6 实现）
}

/// GripState 扩展方法
extension GripStateExtension on GripState {
  String get message {
    switch (this) {
      case GripState.unknown: return '检测中...';
      case GripState.holdingPen: return '握笔正确';
      case GripState.noHand: return '请亮出手部';
      case GripState.badGrip: return '请调整握笔方式';
    }
  }

  String get icon {
    switch (this) {
      case GripState.unknown: return '❓';
      case GripState.holdingPen: return '✍️';
      case GripState.noHand: return '🖐️';
      case GripState.badGrip: return '⚠️';
    }
  }

  Color get color {
    switch (this) {
      case GripState.unknown: return Colors.grey;
      case GripState.holdingPen: return Colors.green;
      case GripState.noHand: return Colors.orange;
      case GripState.badGrip: return Colors.red;
    }
  }
}
```

### Step 2: 更新 PostureAnalysis 类

在 `PostureAnalysis` 中添加新字段：

```dart
class PostureAnalysis {
  // ... 现有字段 ...
  final GripState gripState;  // 新增

  PostureAnalysis({
    required this.isCorrect,
    required this.spineAngle,
    required this.eyeScreenDistance,
    required this.headTiltAngle,
    required this.isSpineCorrect,
    required this.isDistanceCorrect,
    required this.isHeadCorrect,
    required this.feedback,
    this.hasVisibleHands = false,
    this.isFaceDetected = false,
    this.gripState = GripState.unknown,  // 新增默认值
  });

  // 更新 toString 方法
  @override
  String toString() {
    return 'PostureAnalysis(spine: ${spineAngle.toStringAsFixed(1)}°, '
        'distance: ${eyeScreenDistance.toStringAsFixed(1)}cm, '
        'tilt: ${headTiltAngle.toStringAsFixed(1)}°, '
        'correct: $isCorrect, '
        'hands: $hasVisibleHands, '
        'face: $isFaceDetected, '
        'grip: $gripState)';
  }
}
```

### Step 3: 实现握笔检测（Sprint 5 占位逻辑）

在 `posture_detector.dart` 中添加：

```dart
/// 检测握笔状态（Sprint 5 占位实现）
/// Sprint 6 将添加复杂握笔分析
static GripState _detectGripState(Pose pose) {
  final leftWrist = pose.landmarks[PoseLandmarkType.leftWrist];
  final rightWrist = pose.landmarks[PoseLandmarkType.rightWrist];

  const minConfidence = 0.5;
  const writingAreaYThreshold = 0.6;  // 底部 ROI（书写区域）

  // 检查手腕是否在底部 ROI 可见
  final leftValid = leftWrist != null &&
      leftWrist.likelihood > minConfidence &&
      leftWrist.y > writingAreaYThreshold;

  final rightValid = rightWrist != null &&
      rightWrist.likelihood > minConfidence &&
      rightWrist.y > writingAreaYThreshold;

  if (leftValid || rightValid) {
    return GripState.holdingPen;
  }

  return GripState.noHand;
}
```

### Step 4: 更新 analyzePose 方法

在 `analyzePose` 中集成握笔检测：

```dart
static PostureAnalysis analyzePose(Pose pose) {
  // ... 现有代码 ...

  // 新增：握笔状态检测
  final gripState = _detectGripState(pose);

  return PostureAnalysis(
    // ... 现有字段 ...
    gripState: gripState,  // 新增
  );
}
```

### Step 5: 验证

```bash
cd /Users/Zhuanz/Documents/01_SmartPen/smartpen-project/frontend
flutter analyze lib/services/posture_data.dart lib/services/posture_detector.dart
```

### Step 6: 提交

```bash
git add lib/services/posture_data.dart lib/services/posture_detector.dart
git commit -m "feat: 添加握笔状态枚举和检测

- 新增 GripState 枚举（unknown, holdingPen, noHand, badGrip）
- 添加状态扩展方法（message, icon, color）
- PostureAnalysis 新增 gripState 字段
- Sprint 5 占位实现：基于手腕 ROI 的简单握笔检测"
```

---

## Task 2: 创建 AI 导师仪表板组件

**目标:** 创建显示姿态和手部状态的仪表板组件。

**Files:**
- Create: `/Users/Zhuanz/Documents/01_SmartPen/smartpen-project/frontend/lib/widgets/ai_tutor_dashboard.dart`

### Step 1: 创建 AiTutorDashboard 组件

```dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/posture_provider.dart';
import '../services/posture_data.dart';

/// AI 导师仪表板 - 显示姿态和手部状态
class AiTutorDashboard extends StatelessWidget {
  const AiTutorDashboard({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<PostureProvider>(
      builder: (context, postureProvider, child) {
        // 只在监测中时显示
        if (!postureProvider.isMonitoring) {
          return const SizedBox.shrink();
        }

        final analysis = postureProvider.currentAnalysis;
        if (analysis == null) {
          return const SizedBox.shrink();
        }

        return Container(
          margin: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
          padding: const EdgeInsets.all(12.0),
          decoration: BoxDecoration(
            color: Colors.blue.shade50,
            borderRadius: BorderRadius.circular(12.0),
            border: Border.all(color: Colors.blue.shade200),
          ),
          child: Column(
            children: [
              // 状态行胶囊
              Row(
                children: [
                  _buildStatusCapsule(
                    icon: '👤',
                    label: '姿态',
                    isGood: analysis.isCorrect,
                  ),
                  const SizedBox(width: 8),
                  _buildStatusCapsule(
                    icon: analysis.gripState.icon,
                    label: '手部',
                    isGood: analysis.gripState == GripState.holdingPen,
                    customColor: analysis.gripState.color,
                  ),
                ],
              ),
              const SizedBox(height: 12),
              // 操作区
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  _buildActionButton(
                    icon: Icons.photo_camera,
                    label: '拍照评分',
                    onPressed: () => Navigator.pushNamed(context, '/photo_capture'),
                    color: Colors.green,
                  ),
                  _buildActionButton(
                    icon: Icons.mic,
                    label: '语音指令',
                    onPressed: () {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('语音指令功能即将推出')),
                      );
                    },
                    color: Colors.blue,
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildStatusCapsule({
    required String icon,
    required String label,
    required bool isGood,
    Color? customColor,
  }) {
    final backgroundColor = customColor ?? (isGood ? Colors.green.shade100 : Colors.orange.shade100);
    final textColor = customColor ?? (isGood ? Colors.green : Colors.orange);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: textColor.withOpacity(0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(icon, style: const TextStyle(fontSize: 16)),
          const SizedBox(width: 4),
          Text(
            label,
            style: TextStyle(
              color: textColor,
              fontWeight: FontWeight.bold,
              fontSize: 14,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActionButton({
    required IconData icon,
    required String label,
    required VoidCallback onPressed,
    required Color color,
  }) {
    return ElevatedButton.icon(
      onPressed: onPressed,
      icon: Icon(icon),
      label: Text(label),
      style: ElevatedButton.styleFrom(
        backgroundColor: color,
        foregroundColor: Colors.white,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      ),
    );
  }
}
```

### Step 2: 验证

```bash
flutter analyze lib/widgets/ai_tutor_dashboard.dart
```

### Step 3: 提交

```bash
git add lib/widgets/ai_tutor_dashboard.dart
git commit -m "feat: 创建 AI 导师仪表板组件

- 实现状态行胶囊（姿态 + 手部）
- 添加拍照评分和语音指令按钮
- 集成 PostureProvider 状态"
```

---

## Task 3: 重构练习界面 - 移除数字画布

**目标:** 移除 WritingCanvasDrawing，添加 AiTutorDashboard。

**Files:**
- Modify: `/Users/Zhuanz/Documents/01_SmartPen/smartpen-project/frontend/lib/screens/home_screen.dart`

### Step 1: 移除数字画布相关代码

1. 移除导入：
```dart
// 删除这行
import '../widgets/writing_canvas_drawing.dart';
```

2. 删除 `_buildPracticeArea()` 方法（约第 372-394 行）

3. 在 `_buildPracticeInterface()` 中移除对 `_buildPracticeArea()` 的调用

### Step 2: 添加 AiTutorDashboard 导入

```dart
import '../widgets/ai_tutor_dashboard.dart';
```

### Step 3: 更新练习界面布局

修改 `_buildPracticeInterface()` 方法：

```dart
Widget _buildPracticeInterface() {
  return SafeArea(
    child: SingleChildScrollView(
      child: Column(
        children: [
          _buildCharacterInput(),
          _buildReferenceArea(),
          const SizedBox(height: 16),
          // 移除 _buildPracticeArea() - 不再需要数字画布
          const AiTutorDashboard(),  // 新增 AI 导师仪表板
          const SizedBox(height: 16),
          // 保留 _buildActionButtons() 但简化功能
        ],
      ),
    ),
  );
}
```

### Step 4: 简化操作按钮

修改 `_buildActionButtons()` 方法，移除与画布相关的功能：

```dart
Widget _buildActionButtons() {
  return Consumer<CharacterProvider>(
    builder: (context, charProvider, child) {
      return Padding(
        padding: const EdgeInsets.all(16.0),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            ElevatedButton.icon(
              onPressed: () => _loadCharacter(),  // 简化：只保留重新加载
              icon: const Icon(Icons.refresh),
              label: const Text('换字'),
            ),
          ],
        ),
      );
    },
  );
}
```

### Step 5: 验证

```bash
flutter analyze lib/screens/home_screen.dart
flutter build apk --debug
```

### Step 6: 提交

```bash
git add lib/screens/home_screen.dart
git commit -m "refactor: 重构练习界面 - 移除数字画布

- 移除 WritingCanvasDrawing 组件
- 移除 _buildPracticeArea() 方法
- 添加 AiTutorDashboard 组件
- 简化操作按钮（只保留换字功能）
- 转向真纸书写模式"
```

---

## Task 4: 创建拍照页面

**目标:** 使用 image_picker 打开系统相机拍照。

**Files:**
- Create: `/Users/Zhuanz/Documents/01_SmartPen/smartpen-project/frontend/lib/screens/photo_capture_page.dart`

### Step 1: 创建 PhotoCapturePage

```dart
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';
import '../providers/character_provider.dart';
import 'score_page.dart';

/// 拍照页面 - 使用 image_picker 打开系统相机
class PhotoCapturePage extends StatefulWidget {
  const PhotoCapturePage({super.key});

  @override
  State<PhotoCapturePage> createState() => _PhotoCapturePageState();
}

class _PhotoCapturePageState extends State<PhotoCapturePage> {
  final ImagePicker _picker = ImagePicker();
  bool _isCapturing = false;

  Future<void> _capturePhoto() async {
    if (_isCapturing) return;

    setState(() {
      _isCapturing = true;
    });

    try {
      final XFile? photo = await _picker.pickImage(
        source: ImageSource.camera,
        preferredCameraDevice: CameraDevice.rear,
        imageQuality: 85,
      );

      if (photo != null) {
        final characterProvider = context.read<CharacterProvider>();
        final currentCharacter = characterProvider.currentCharacter;

        if (currentCharacter != null && mounted) {
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(
              builder: (context) => ScorePage(
                imagePath: photo.path,
                character: currentCharacter,
              ),
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('拍照失败: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isCapturing = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('拍照评分'),
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(
              Icons.photo_camera,
              size: 80,
              color: Colors.grey,
            ),
            const SizedBox(height: 24),
            const Text(
              '拍摄书写照片',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            const Text(
              '确保书写清晰可见',
              style: TextStyle(color: Colors.grey),
            ),
            const SizedBox(height: 32),
            ElevatedButton.icon(
              onPressed: _isCapturing ? null : _capturePhoto,
              icon: _isCapturing
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.camera_alt),
              label: Text(_isCapturing ? '打开相机...' : '拍照'),
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
                backgroundColor: Colors.green,
                foregroundColor: Colors.white,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
```

### Step 2: 验证

```bash
flutter analyze lib/screens/photo_capture_page.dart
```

### Step 3: 提交

```bash
git add lib/screens/photo_capture_page.dart
git commit -m "feat: 创建拍照页面

- 使用 image_picker 打开系统相机
- 获取当前字符数据
- 拍照后导航到评分页面"
```

---

## Task 5: 创建评分页面（双模式）

**目标:** 实现 Report 和 Overlay 两种模式。

**Files:**
- Create: `/Users/Zhuanz/Documents/01_SmartPen/smartpen-project/frontend/lib/screens/score_page.dart`

### Step 1: 创建 ScorePage 核心结构

```dart
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
```

### Step 2: 验证

```bash
flutter analyze lib/screens/score_page.dart
```

### Step 3: 提交

```bash
git add lib/screens/score_page.dart
git commit -m "feat: 创建双模式评分页面

- Overlay 模式：数字描红台（用户照片 + 红色范字叠加）
- Report 模式：传统报告视图（照片 + 评分详情）
- 透明度滑块控制范字显示
- Mock 评分生成（后端不支持图片上传）
- 模式切换按钮"
```

---

## Task 6: 配置路由

**目标:** 添加命名路由支持页面导航。

**Files:**
- Modify: `/Users/Zhuanz/Documents/01_SmartPen/smartpen-project/frontend/lib/main.dart`

### Step 1: 更新 main.dart

```dart
import 'screens/home_screen.dart';
import 'screens/photo_capture_page.dart';
import 'screens/score_page.dart';

// ... in MaterialApp:
MaterialApp(
  title: '智笔 - AI 书法教学',
  theme: ThemeData(...),
  darkTheme: ThemeData(...),
  home: const HomeScreen(),
  debugShowCheckedModeBanner: false,
  routes: {
    '/': (context) => const HomeScreen(),
    '/photo_capture': (context) => const PhotoCapturePage(),
  },
);
```

### Step 2: 验证

```bash
flutter analyze lib/main.dart
```

### Step 3: 提交

```bash
git add lib/main.dart
git commit -m "feat: 配置应用路由

- 添加 /photo_capture 路由
- ScorePage 使用 MaterialPageRoute 导航（传递参数）"
```

---

## Task 7: 端到端测试

### 测试场景

**场景 1: 数据模型测试**
1. 启动姿态监测
2. 验证 GripState 在日志中显示
3. 验证状态胶囊显示正确的图标和颜色

**场景 2: UI 重构测试**
1. 完成校准后进入练习模式
2. 验证不再显示数字画布
3. 验证 AiTutorDashboard 显示

**场景 3: 拍照流程测试**
1. 点击"拍照评分"按钮
2. 打开系统相机
3. 拍摄照片
4. 验证导航到 ScorePage

**场景 4: Overlay 模式测试**
1. 在 ScorePage 中验证默认进入 Overlay 模式
2. 调整透明度滑块
3. 验证红色范字正确叠加在照片上
4. 验证底部评分摘要显示

**场景 5: Report 模式测试**
1. 点击模式切换按钮
2. 验证显示 Report 模式
3. 验证照片和评分卡片显示

### 性能验证

```bash
flutter build apk --debug
adb -s 000001f7f440ca2e install -r ../build/app/outputs/flutter-apk/app-debug.apk
```

---

## 验收标准

### 功能验收
- [x] GripState 枚举和扩展方法实现
- [x] PostureAnalysis 包含 gripState 字段
- [x] AiTutorDashboard 显示姿态和手部状态胶囊
- [x] WritingCanvasDrawing 已移除
- [x] 拍照按钮可打开系统相机
- [x] ScorePage Overlay 模式实现（照片 + 红色范字叠加）
- [x] ScorePage Report 模式实现（照片 + 评分详情）
- [x] 透明度滑块功能正常
- [x] 模式切换功能正常
- [x] 姿态监测在练习模式下保持功能

### UI 验收
- [x] 状态胶囊显示正确的图标、颜色、文案
- [x] 语音按钮显示"即将推出"提示
- [x] Overlay 模式红色范字清晰可见
- [x] 报告模式布局美观

### 性能验收
- [x] 页面切换流畅无卡顿
- [x] 拍照响应时间 < 2 秒
- [x] 透明度调整流畅

---

## 关键文件清单

### 新建文件（3）
- `/Users/Zhuanz/Documents/01_SmartPen/smartpen-project/frontend/lib/widgets/ai_tutor_dashboard.dart`
- `/Users/Zhuanz/Documents/01_SmartPen/smartpen-project/frontend/lib/screens/photo_capture_page.dart`
- `/Users/Zhuanz/Documents/01_SmartPen/smartpen-project/frontend/lib/screens/score_page.dart`

### 修改文件（4）
- `/Users/Zhuanz/Documents/01_SmartPen/smartpen-project/frontend/lib/services/posture_data.dart`
- `/Users/Zhuanz/Documents/01_SmartPen/smartpen-project/frontend/lib/services/posture_detector.dart`
- `/Users/Zhuanz/Documents/01_SmartPen/smartpen-project/frontend/lib/screens/home_screen.dart`
- `/Users/Zhuanz/Documents/01_SmartPen/smartpen-project/frontend/lib/main.dart`
