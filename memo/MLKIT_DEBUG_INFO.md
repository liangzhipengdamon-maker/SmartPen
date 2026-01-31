# ML Kit Pose Detection 调试信息

## 问题症状
```
PlatformException(InputImageConverterError, ImageFormat is not supported., null, null)
```

## 相机信息（来自日志）
```
🔄 Camera rotation: sensorOrientation=270°, inputImageRotation=InputImageRotation.rotation270deg, lensDirection=CameraLensDirection.front
📷 Frame: 640x480, format: raw=35, planes: 3, bytesPerRow: 640
```

**关键数据：**
- `format: raw=35` → 这是 `ImageFormat.YUV_420_888` (Android)
- `planes: 3` → YUV_420_888 有 3 个独立平面
- `sensorOrientation=270°` → 前置摄像头竖屏模式
- 分辨率: 640x480

---

## 当前代码 (lib/services/mlkit_service.dart)

### ImageUtils.toInputImage() 方法

```dart
static InputImage toInputImage(CameraImage image, CameraDescription? cameraDescription) {
  // 1. 处理字节流拼接（官方推荐：简单拼接所有 planes）
  final allBytes = WriteBuffer();
  for (final Plane plane in image.planes) {
    allBytes.putUint8List(plane.bytes);
  }
  final bytes = allBytes.done().buffer.asUint8List();

  // 2. 获取图像尺寸
  final size = ui.Size(image.width.toDouble(), image.height.toDouble());

  // 3. 计算旋转角度（关键修复点）
  // 使用 fromRawValue 动态获取，避免硬编码
  InputImageRotation rotation;

  if (cameraDescription != null) {
    rotation = InputImageRotationValue.fromRawValue(cameraDescription.sensorOrientation)
        ?? InputImageRotation.rotation0deg;

    // 调试日志（每 30 帧打印一次）
    _frameCount++;
    if (_frameCount % 30 == 0) {
      debugPrint('🔄 Camera rotation: sensorOrientation=${cameraDescription.sensorOrientation}°, '
          'inputImageRotation=$rotation, '
          'lensDirection=${cameraDescription.lensDirection}');
    }
  } else {
    debugPrint('⚠️  No camera description, using default rotation (270deg)');
    rotation = InputImageRotation.rotation270deg;
  }

  // 4. 确定输入格式（官方推荐：Android 使用 nv21）
  // 虽然源是 yuv420_888，但插件层将其视为 nv21 处理
  final format = InputImageFormatValue.fromRawValue(image.format.raw)
      ?? InputImageFormat.nv21;

  // 5. 提取行跨度（使用 Y 平面）
  final bytesPerRow = image.planes.isNotEmpty ? image.planes[0].bytesPerRow : 0;

  // 6. 构建元数据
  final metadata = InputImageMetadata(
    size: size,
    rotation: rotation,
    format: format,
    bytesPerRow: bytesPerRow,
  );

  // 7. 调试日志
  if (_frameCount % 30 == 0) {
    debugPrint('📷 Frame: ${image.width}x${image.height}, '
        'format: raw=${image.format.raw}, '
        'planes: ${image.planes.length}, '
        'bytesPerRow: $bytesPerRow');
  }

  return InputImage.fromBytes(
    bytes: bytes,
    metadata: metadata,
  );
}
```

---

## 关键疑问

### 1. InputImageFormat 映射问题
当前代码使用：
```dart
final format = InputImageFormatValue.fromRawValue(image.format.raw)
    ?? InputImageFormat.nv21;
```

**问题：**
- `image.format.raw = 35` (YUV_420_888)
- `InputImageFormatValue.fromRawValue(35)` 返回什么？
- 如果返回 null，会回退到 `InputImageFormat.nv21`
- 但字节流是 YUV_420_888 (3个平面)，不是 NV21 (2个平面)

### 2. 字节拼接问题
当前代码简单拼接 3 个 planes：
```dart
final allBytes = WriteBuffer();
for (final Plane plane in image.planes) {
  allBytes.putUint8List(plane.bytes);
}
final bytes = allBytes.done().buffer.asUint8List();
```

**问题：**
- YUV_420_888 和 NV21 的字节排列不同
- YUV_420_888: YYYY... UVUV... (分平面)
- NV21: YYYY... VUVU... (交错)
- 简单拼接能直接用吗？

---

## 尝试过的方案

### 方案 A（当前）：fromRawValue + 简单拼接
```dart
final format = InputImageFormatValue.fromRawValue(image.format.raw)
    ?? InputImageFormat.nv21;
// 简单拼接所有 planes
```
**结果：** ❌ `InputImageConverterError`

### 方案 B：查找 values 列表
```dart
final format = InputImageFormat.values.firstWhere(
  (f) => f.rawValue == image.format.raw,
  orElse: () => InputImageFormat.nv21,
);
```
**结果：** ❌ `InputImageConverterError`

---

## 需要咨询 NotebookLM 的问题

1. **Android 相机返回 YUV_420_888 (raw=35, 3 planes)**
2. **ML Kit 的 InputImage.fromBytes() 需要什么格式？**
3. **是否需要将 YUV_420_888 转换为 NV21？**
4. **google_mlkit_pose_detection 插件如何处理 YUV 格式？**
5. **官方推荐的正确转换方法是什么？**

---

## 依赖版本

```yaml
# pubspec.yaml
dependencies:
  camera: ^0.10.5+5
  google_mlkit_pose_detection: ^0.12.0
```

---

## 调试步骤

1. 检查 `InputImageFormatValue.fromRawValue(35)` 的返回值
2. 检查 ML Kit 插件源码如何处理格式
3. 验证是否需要 YUV → NV21 转换
4. 测试直接使用 `InputImageFormat.yuv_420`（如果存在）

---

## 参考文档链接

- ML Kit Pose Detection 官方文档
- google_ml_kit_flutter GitHub
- Android Camera2 ImageFormat 文档
