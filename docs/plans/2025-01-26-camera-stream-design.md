# 实时相机流处理设计

**日期**: 2025-01-26
**阶段**: Sprint 5 - P0-1
**状态**: 设计完成，待实施

---

## 架构概述

相机流处理系统采用**生产者-消费者模式**，将相机帧捕获与 ML Kit 推理解耦。相机作为生产者持续捕获帧，通过节流机制控制为 10 FPS，然后传递给 ML Kit Pose Detection 服务进行处理。

核心组件：
1. **CameraController** - 管理相机生命周期和权限
2. **FrameThrottler** - 节流机制，确保不超过 10 FPS
3. **MLKitPoseService** - 在 Isolate 中处理姿态检测
4. **PostureProvider** - 状态管理和错误处理

数据流向：`Camera硬件` → `CameraImage流` → `FrameThrottler` → `MLKitPoseService` → `PostureAnalysis` → `UI更新`

---

## 关键设计决策

| 决策点 | 选择 | 理由 |
|--------|------|------|
| 摄像头 | 前置摄像头 | 用户面向屏幕写字，视野更合适 |
| 分辨率 | medium | 平衡性能与质量，640x480 对姿态检测足够 |
| 启动控制 | 用户点击"开始书写" | 精细控制，避免不必要的电量消耗 |
| 错误处理 | 引导修复 | 给用户明确的解决路径 |
| 帧率控制 | 限制 10 FPS | 姿态变化不需要毫秒级响应，显著降低 CPU 占用 |
| 图像流 | startImageStream() | 直接获取 CameraImage，更容易与 ML Kit 集成 |

---

## CameraController 实现

### 初始化阶段
```dart
Future<void> initialize() async {
  // 1. 请求相机权限
  final status = await Permission.camera.request();
  if (!status.isGranted) {
    _showPermissionDialog();
    return;
  }

  // 2. 获取前置摄像头
  final cameras = await availableCameras();
  final frontCamera = cameras.firstWhere(
    (c) => c.lensDirection == CameraLensDirection.front,
  );

  // 3. 创建相机控制器
  _cameraController = camera.CameraController(
    frontCamera,
    ResolutionPreset.medium,
    enableAudio: false,
  );

  await _cameraController!.initialize();
}
```

### 启动流
```dart
Future<void> startCameraStream() async {
  await _cameraController!.startImageStream((CameraImage image) {
    if (_throttler.shouldProcess()) {
      _provider.processCameraImage(image);
    }
  });
  _provider.startMonitoring();
}
```

### 停止流
```dart
Future<void> stopCameraStream() async {
  await _cameraController?.stopImageStream();
  await _cameraController?.dispose();
  _provider.stopMonitoring();
}
```

---

## 帧节流机制

```dart
class FrameThrottler {
  DateTime _lastProcessTime = DateTime.now();
  static const _minInterval = Duration(milliseconds: 100); // 10 FPS

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

**优势**：
- 避免处理队列积压
- 降低 CPU 占用约 60-70%
- 保证姿态检测的"实时感"

---

## 图像转换与 ML Kit 集成

```dart
// 在 PostureProvider.processCameraImage() 中
Future<void> processCameraImage(CameraImage image) async {
  if (!_throttler.shouldProcess()) return;

  try {
    await _mlkitService.processCameraImage(image);
  } catch (e) {
    debugPrint('Frame processing error: $e');
    // 不中断流，继续处理下一帧
  }
}
```

---

## 错误处理与用户引导

### 第一层：权限错误
- 检测到 `PermissionDenied` 时，显示对话框
- 提供"去设置"按钮，使用 `openAppSettings()` 跳转
- 保存用户拒绝状态，避免重复弹窗

### 第二层：硬件错误
- 无可用相机时，显示友好提示
- 建议用户检查设备或尝试重启应用

### 第三层：运行时错误
- 单帧处理失败不影响后续帧
- 持续失败时（如 5 次），显示警告并停止流
- 提供重试按钮

---

## 测试策略

### 单元测试
- `FrameThrottler` - 验证节流逻辑准确性
- 测试不同时间间隔下的行为
- 模拟边界条件（0ms, 99ms, 100ms, 101ms）

### 集成测试
- 使用 camera 包的 mock 模拟相机流
- 验证完整的帧处理流程
- 测试错误恢复机制

### 手动测试
- 真实设备测试权限流程
- 长时间运行测试（30 分钟）检查内存泄漏
- 不同设备性能对比

---

## 性能指标

| 指标 | 目标值 |
|------|--------|
| 帧率 | 9-11 FPS |
| 内存增长 | < 10MB/小时 |
| CPU 占用 | < 30%（中端设备） |
| 初始化时间 | < 3 秒 |

---

## 范围说明

**本设计包含**：
- ✅ 相机流处理
- ✅ 姿态检测（已集成 ML Kit Pose Detection）
- ✅ 权限和错误处理

**本设计不包含**（留到后续阶段）：
- ❌ 握笔检测（需要 ML Kit Hand Detection）
- ❌ AR 叠加层 UI
- ❌ 音频警报（P0-2 阶段）
