# 实时相机流处理实施计划

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**目标:** 实现稳定的相机流处理，以 10 FPS 捕获帧并传递给 ML Kit Pose Detection 进行姿态检测

**架构:** 生产者-消费者模式，相机捕获帧 → FrameThrottler 节流 → ML Kit 推理 → PostureProvider 状态更新

**技术栈:** Flutter camera 0.11.3, ML Kit Pose Detection 0.14.0, Permission Handler 11.1.0

---

## Task 1: 实现 FrameThrottler 帧节流器

**目标:** 创建节流器类，确保帧处理频率不超过 10 FPS

**Files:**
- Create: `/Users/Zhuanz/Documents/01_SmartPen/smartpen-project/frontend/lib/utils/frame_throttler.dart`
- Test: `/Users/Zhuanz/Documents/01_SmartPen/smartpen-project/frontend/test/utils/frame_throttler_test.dart`

### Step 1: 编写失败的测试 - 节流逻辑

```dart
// test/utils/frame_throttler_test.dart
import 'package:flutter_test/flutter_test.dart';
import 'package:smartpen_frontend/utils/frame_throttler.dart';

void main() {
  group('FrameThrottler', () {
    test('shouldProcess 在 100ms 内首次调用返回 true', () {
      final throttler = FrameThrottler();
      expect(throttler.shouldProcess(), isTrue);
    });

    test('shouldProcess 在 100ms 内再次调用返回 false', () {
      final throttler = FrameThrottler();
      throttler.shouldProcess(); // 第一次调用
      expect(throttler.shouldProcess(), isFalse); // 100ms 内第二次调用
    });

    test('shouldProcess 在 100ms 后再次调用返回 true', () async {
      final throttler = FrameThrottler();
      throttler.shouldProcess(); // 第一次调用
      await Future.delayed(Duration(milliseconds: 110)); // 等待超过 100ms
      expect(throttler.shouldProcess(), isTrue);
    });
  });
}
```

**运行测试验证失败:**
```bash
cd /Users/Zhuanz/Documents/01_SmartPen/smartpen-project/frontend
flutter test test/utils/frame_throttler_test.dart
```
预期: FAIL - "FrameThrottler class not found"

### Step 2: 实现 FrameThrottler 类

```dart
// lib/utils/frame_throttler.dart
import 'dart:async';

/// 帧节流器，限制帧处理频率
class FrameThrottler {
  DateTime _lastProcessTime = DateTime.now();
  static const Duration _minInterval = Duration(milliseconds: 100); // 10 FPS

  /// 判断是否应该处理当前帧
  /// 返回 true 表示应该处理，false 表示应该跳过
  bool shouldProcess() {
    final now = DateTime.now();
    if (now.difference(_lastProcessTime) < _minInterval) {
      return false; // 跳过此帧
    }
    _lastProcessTime = now;
    return true; // 处理此帧
  }
}
```

### Step 3: 运行测试验证通过

```bash
flutter test test/utils/frame_throttler_test.dart
```
预期: PASS (3 tests)

### Step 4: 提交

```bash
git add lib/utils/frame_throttler.dart test/utils/frame_throttler_test.dart
git commit -m "feat: 实现 FrameThrottler 帧节流器

- 限制帧处理频率为 10 FPS
- 添加完整的单元测试覆盖"
```

---

## Task 2: 重构 CameraController 以支持真实相机

**目标:** 完善 `posture_provider.dart` 中的 `CameraController` 类，实现真实的相机初始化和流处理

**Files:**
- Modify: `/Users/Zhuanz/Documents/01_SmartPen/smartpen-project/frontend/lib/providers/posture_provider.dart:125-145`

### Step 1: 更新导入语句

在 `posture_provider.dart` 顶部添加 camera 包导入：

```dart
import 'package:camera/camera.dart' as camera;
```

### Step 2: 重构 CameraController 类

替换现有的 `CameraController` 实现（第 125-145 行）：

```dart
/// 相机图像流控制器
class CameraController {
  final PostureProvider _provider;
  final FrameThrottler _throttler = FrameThrottler();

  camera.CameraController? _internalController;
  bool _isInitialized = false;

  CameraController(this._provider);

  /// 初始化相机
  Future<bool> initialize() async {
    try {
      // 1. 检查相机权限
      final status = await Permission.camera.request();
      if (!status.isGranted) {
        _provider._errorMessage = '需要相机权限进行姿态检测';
        _provider.notifyListeners();
        return false;
      }

      // 2. 获取可用相机
      final cameras = await camera.availableCameras();
      if (cameras.isEmpty) {
        _provider._errorMessage = '未找到可用相机';
        _provider.notifyListeners();
        return false;
      }

      // 3. 查找前置摄像头
      final frontCamera = cameras.firstWhere(
        (c) => c.lensDirection == camera.CameraLensDirection.front,
        orElse: () => cameras.first,
      );

      // 4. 创建相机控制器
      _internalController = camera.CameraController(
        frontCamera,
        camera.ResolutionPreset.medium,
        enableAudio: false,
      );

      // 5. 初始化相机
      await _internalController!.initialize();
      _isInitialized = true;

      debugPrint('CameraController: Camera initialized successfully');
      return true;
    } catch (e) {
      _provider._errorMessage = '相机初始化失败: $e';
      _provider.notifyListeners();
      debugPrint('CameraController: Initialization error - $e');
      return false;
    }
  }

  /// 启动相机流
  Future<void> startCameraStream() async {
    if (!_isInitialized) {
      final success = await initialize();
      if (!success) {
        throw Exception('Camera initialization failed');
      }
    }

    try {
      await _internalController!.startImageStream((cameraImage) {
        // 使用节流器控制帧率
        if (_throttler.shouldProcess()) {
          _provider.processCameraImage(cameraImage);
        }
      });

      _provider.startMonitoring();
      debugPrint('CameraController: Camera stream started');
    } catch (e) {
      _provider._errorMessage = '启动相机流失败: $e';
      _provider.notifyListeners();
      debugPrint('CameraController: Stream start error - $e');
      rethrow;
    }
  }

  /// 停止相机流
  Future<void> stopCameraStream() async {
    try {
      await _internalController?.stopImageStream();
      await _internalController?.dispose();
      _internalController = null;
      _isInitialized = false;

      _provider.stopMonitoring();
      debugPrint('CameraController: Camera stream stopped');
    } catch (e) {
      debugPrint('CameraController: Stop error - $e');
    }
  }

  /// 获取相机控制器实例（用于预览）
  camera.CameraController? get controller => _internalController;

  /// 相机是否已初始化
  bool get isInitialized => _isInitialized;
}
```

### Step 3: 添加 FrameThrottler 导入

确保文件顶部有导入：

```dart
import '../utils/frame_throttler.dart';
import 'package:permission_handler/permission_handler.dart';
```

### Step 4: 提交

```bash
git add lib/providers/posture_provider.dart
git commit -m "feat: 实现真实的相机流初始化和处理

- 集成 camera 包进行相机管理
- 添加权限检查和错误处理
- 集成 FrameThrottler 控制 10 FPS
- 支持前置摄像头自动选择"
```

---

## Task 3: 改进 PostureProvider 错误处理

**目标:** 增强错误处理机制，添加权限对话框引导

**Files:**
- Create: `/Users/Zhuanz/Documents/01_SmartPen/smartpen-project/frontend/lib/widgets/camera_permission_dialog.dart`
- Modify: `/Users/Zhuanz/Documents/01_SmartPen/smartpen-project/frontend/lib/providers/posture_provider.dart`

### Step 1: 创建权限对话框组件

```dart
// lib/widgets/camera_permission_dialog.dart
import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';

class CameraPermissionDialog extends StatelessWidget {
  final VoidCallback onOpenSettings;

  const CameraPermissionDialog({
    Key? key,
    required this.onOpenSettings,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('需要相机权限'),
      content: const Text(
        'SmartPen 需要相机权限来检测您的书写姿态。\n\n'
        '请点击下方按钮前往设置开启相机权限。',
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('取消'),
        ),
        ElevatedButton(
          onPressed: () {
            Navigator.of(context).pop();
            onOpenSettings();
          },
          child: const Text('去设置'),
        ),
      ],
    );
  }

  /// 显示权限对话框
  static Future<void> show(BuildContext context) {
    return showDialog(
      context: context,
      builder: (context) => CameraPermissionDialog(
        onOpenSettings: () async {
          await openAppSettings();
        },
      ),
    );
  }
}
```

### Step 4: 提交

```bash
git add lib/widgets/camera_permission_dialog.dart
git commit -m "feat: 添加相机权限对话框组件

- 提供友好的权限申请引导
- 支持跳转到系统设置页面"
```

---

## Task 4: 添加相机预览 UI 组件

**目标:** 创建相机预览组件，用于显示实时画面

**Files:**
- Create: `/Users/Zhuanz/Documents/01_SmartPen/smartpen-project/frontend/lib/widgets/camera_preview.dart`

### Step 1: 实现相机预览组件

```dart
// lib/widgets/camera_preview.dart
import 'package:flutter/material.dart';
import 'package:camera/camera.dart';
import '../providers/posture_provider.dart';

/// 相机预览组件
class CameraPreviewWidget extends StatelessWidget {
  final PostureProvider provider;

  const CameraPreviewWidget({
    Key? key,
    required this.provider,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final cameraController = provider.cameraController;

    if (cameraController == null || !cameraController!.isInitialized) {
      return Container(
        color: Colors.black,
        child: const Center(
          child: CircularProgressIndicator(
            valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
          ),
        ),
      );
    }

    return CameraPreview(cameraController!.controller!);
  }
}
```

### Step 2: 在 PostureProvider 中暴露 cameraController

在 `PostureProvider` 类中添加 getter：

```dart
// 在 lib/providers/posture_provider.dart 中添加
CameraController? get cameraController => _cameraController;
```

需要添加私有字段：

```dart
// 在 PostureProvider 类顶部添加
CameraController? _cameraController;
```

在 `initialize()` 方法中初始化：

```dart
// 在 initialize() 方法中添加
_cameraController = CameraController(this);
await _cameraController!.initialize();
```

### Step 3: 提交

```bash
git add lib/widgets/camera_preview.dart lib/providers/posture_provider.dart
git commit -m "feat: 添加相机预览 UI 组件

- 创建 CameraPreviewWidget 显示实时画面
- 在 PostureProvider 中暴露相机控制器"
```

---

## Task 5: 集成到 HomeScreen

**目标:** 将相机预览和控制按钮集成到主页面

**Files:**
- Modify: `/Users/Zhuanz/Documents/01_SmartPen/smartpen-project/frontend/lib/screens/home_screen.dart`

### Step 1: 添加开始/停止按钮

在 `home_screen.dart` 中添加相机控制按钮：

```dart
// 在现有的按钮区域添加
ElevatedButton.icon(
  onPressed: () async {
    final provider = context.read<PostureProvider>();

    if (provider.isMonitoring) {
      await provider.cameraController?.stopCameraStream();
    } else {
      try {
        await provider.cameraController!.startCameraStream();
      } catch (e) {
        // 显示错误对话框
        if (e.toString().contains('Permission')) {
          await CameraPermissionDialog.show(context);
        }
      }
    }
  },
  icon: Icon(
    provider.isMonitoring ? Icons.stop : Icons.play_arrow,
  ),
  label: Text(provider.isMonitoring ? '停止监测' : '开始监测'),
)
```

### Step 2: 添加相机预览区域

在页面中添加相机预览：

```dart
// 在适当位置添加
Consumer<PostureProvider>(
  builder: (context, provider, child) {
    return provider.isMonitoring
        ? SizedBox(
            height: 240,
            child: CameraPreviewWidget(provider: provider),
          )
        : const SizedBox.shrink();
  },
)
```

### Step 3: 添加导入

```dart
import '../widgets/camera_preview.dart';
import '../widgets/camera_permission_dialog.dart';
```

### Step 4: 提交

```bash
git add lib/screens/home_screen.dart
git commit -m "feat: 集成相机控制到主页面

- 添加开始/停止监测按钮
- 集成相机预览区域
- 添加权限对话框处理"
```

---

## Task 6: 手动测试验证

**目标:** 在真实设备上验证完整流程

### Step 1: 构建并安装到设备

```bash
cd /Users/Zhuanz/Documents/01_SmartPen/smartpen-project/frontend
flutter run -d <your_device_id>
```

### Step 2: 测试权限流程

1. 首次点击"开始监测"按钮
2. 验证权限请求对话框显示
3. 拒绝权限，验证引导对话框显示
4. 点击"去设置"，验证跳转到系统设置

### Step 3: 测试相机流

1. 在设置中允许相机权限
2. 返回应用，点击"开始监测"
3. 验证相机预览显示
4. 验证姿态数据开始更新

### Step 4: 测试停止流程

1. 点击"停止监测"按钮
2. 验证相机预览消失
3. 验证姿态数据清空

### Step 5: 性能监控

使用 Flutter DevTools 观察：
- 帧率是否稳定在 9-11 FPS
- 内存增长是否正常
- CPU 占用是否合理

---

## 验收标准

### 功能验收

- [ ] 相机能成功初始化（前置摄像头）
- [ ] 权限被拒绝时显示引导对话框
- [ ] 点击"开始监测"后相机预览正常显示
- [ ] 姿态数据实时更新
- [ ] 帧率稳定在 10 FPS 左右
- [ ] 点击"停止监测"后相机正确释放

### 性能验收

- [ ] 帧率: 9-11 FPS
- [ ] 内存增长: < 10MB/小时
- [ ] CPU 占用: < 30%（中端设备）
- [ ] 初始化时间: < 3 秒

### 代码质量

- [ ] 所有单元测试通过
- [ ] 无明显内存泄漏
- [ ] 错误处理完善
- [ ] 代码符合 Flutter 规范

---

## 后续步骤

完成此计划后，继续以下任务：

1. **P0-2:** 准备音频资源文件和配置
2. **P0-3:** 集成警报系统到姿态监测
3. **P1-1:** ML Kit Hand Detection 集成
4. **P1-2:** 握笔检测算法实现
