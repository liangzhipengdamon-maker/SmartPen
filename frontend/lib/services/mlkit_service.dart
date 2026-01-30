import 'dart:async';
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:camera/camera.dart';
import 'package:flutter/foundation.dart';
import 'package:google_mlkit_pose_detection/google_mlkit_pose_detection.dart';

/// ML Kit Pose Detection 服务
///
/// 使用 google_ml_kit_pose_detection 插件
/// ⚠️ 禁止使用原生 MediaPipe C++ 桥接
class MLKitPoseService {
  PoseDetector? _poseDetector;
  bool _isProcessing = false;
  final StreamController<List<Pose>> _poseStreamController = StreamController.broadcast();

  Stream<List<Pose>> get poseStream => _poseStreamController.stream;
  bool get isProcessing => _isProcessing;

  /// 初始化 Pose Detector
  ///
  /// 使用 Lite 模型以获得最佳性能
  Future<void> initialize() async {
    if (_poseDetector != null) {
      debugPrint('MLKitPoseService: Already initialized');
      return;
    }

    try {
      // 注意：权限请求已移至 HomeScreen Switch 中统一处理
      // 不再在此处请求权限，避免重复请求和权限竞争

      // 创建 Pose Detector
      // 使用 Base 模型（最快）和 stream 模式
      final options = PoseDetectorOptions(
        model: PoseDetectionModel.base,
        mode: PoseDetectionMode.stream,
      );

      _poseDetector = PoseDetector(options: options);

      debugPrint('MLKitPoseService: Initialized with Base model + stream mode');
    } catch (e) {
      debugPrint('MLKitPoseService: Initialization failed - $e');
      rethrow;
    }
  }

  /// 处理相机图像帧并检测姿态
  ///
  /// 注意：不再使用 compute() 避免 BackgroundIsolateBinaryMessenger 错误
  /// ML Kit Pose Detection 已在原生层优化，不会阻塞 UI 线程
  /// 配合 FrameThrottler（10 FPS）使用，性能表现良好
  Future<void> processCameraImage(CameraImage image, CameraDescription? cameraDescription) async {
    if (_poseDetector == null) {
      debugPrint('MLKitPoseService: Not initialized');
      return;
    }

    if (_isProcessing) {
      // 跳过，上一帧还在处理
      return;
    }

    _isProcessing = true;

    try {
      // 转换 CameraImage 为 InputImage（传递相机描述用于旋转计算）
      final inputImage = ImageUtils.toInputImage(image, cameraDescription);

      // 直接调用 ML Kit 进行姿态检测
      // 不再使用 compute() 避免 BackgroundIsolateBinaryMessenger 错误
      final poses = await _poseDetector!.processImage(inputImage);

      // 添加调试日志（每 30 帧打印一次）
      final frameNumber = DateTime.now().millisecondsSinceEpoch ~/ 100;
      if (frameNumber % 30 == 0) {
        debugPrint('📸 Frame: ${image.width}x${image.height}, '
            'format: raw=${image.format.raw}, '
            'rotation: ${inputImage.metadata?.rotation}, '
            'poses: ${poses.length}, '
            'landmarks: ${poses.isNotEmpty ? poses.first.landmarks.length : 0}');

        // 打印 nose 坐标（如果检测到）
        if (poses.isNotEmpty) {
          final pose = poses.first;
          final nose = pose.landmarks[PoseLandmarkType.nose];
          if (nose != null) {
            debugPrint('👃 Nose: x=${nose.x.toStringAsFixed(3)}, '
                'y=${nose.y.toStringAsFixed(3)}, '
                'likelihood=${nose.likelihood.toStringAsFixed(3)}');
          } else {
            debugPrint('⚠️  No nose landmark detected');
          }
        }
      }

      if (poses.isNotEmpty) {
        _poseStreamController.add(poses);
      }
    } catch (e) {
      debugPrint('MLKitPoseService: Detection failed - $e');
    } finally {
      _isProcessing = false;
    }
  }

  /// 释放资源
  Future<void> dispose() async {
    await _poseDetector?.close();
    _poseDetector = null;
    await _poseStreamController.close();
  }
}

/// 姿态数据扩展
extension PoseExtensions on Pose {
  /// 获取鼻子位置（用于计算眼屏距离）
  PoseLandmark? get nose {
    return landmarks[PoseLandmarkType.nose];
  }

  /// 获取左眼
  PoseLandmark? get leftEye {
    return landmarks[PoseLandmarkType.leftEye];
  }

  /// 获取右眼
  PoseLandmark? get rightEye {
    return landmarks[PoseLandmarkType.rightEye];
  }

  /// 获取左肩
  PoseLandmark? get leftShoulder {
    return landmarks[PoseLandmarkType.leftShoulder];
  }

  /// 获取右肩
  PoseLandmark? get rightShoulder {
    return landmarks[PoseLandmarkType.rightShoulder];
  }

  /// 获取脊柱中点（两肩之间）
  ui.Offset? get spineMidpoint {
    final left = leftShoulder;
    final right = rightShoulder;

    if (left == null || right == null) return null;

    return ui.Offset(
      (left.x + right.x) / 2,
      (left.y + right.y) / 2,
    );
  }

  /// 计算脊柱角度（0° = 直立）
  double? get spineAngle {
    final left = leftShoulder;
    final right = rightShoulder;

    if (left == null || right == null) return null;

    final dx = right.x - left.x;
    final dy = right.y - left.y;

    // 计算角度（弧度转度）
    final angle = (math.atan2(dy, dx) * 180 / 3.14159).abs();
    return angle;
  }
}

/// 图像转换工具
class ImageUtils {
  static int _frameCount = 0;

  /// 将 CameraImage 转换为 InputImage（用于 ML Kit）
  ///
  /// 基于 ML Kit 官方推荐方法：
  /// 1. 简单拼接所有 planes 的字节（无需复杂 YUV 转换）
  /// 2. 格式声明为 nv21（插件层将其视为 nv21 处理）
  /// 3. 使用 fromRawValue 动态计算旋转角度
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
}

