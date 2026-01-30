import 'dart:async';
import 'dart:io';
import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:camera/camera.dart';
import 'package:flutter/foundation.dart';
import 'package:google_mlkit_pose_detection/google_mlkit_pose_detection.dart';
import 'package:permission_handler/permission_handler.dart';

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
  /// 在 Isolate 中运行以避免阻塞 UI 线程
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

      // 在后台 isolate 中处理
      final poses = await compute(_detectPoses, _PoseDetectionInput(
        detector: _poseDetector!,
        inputImage: inputImage,
      ));

      // 添加调试日志（每 30 帧打印一次）
      final frameNumber = DateTime.now().millisecondsSinceEpoch ~/ 100;
      if (frameNumber % 30 == 0) {
        debugPrint('📸 Frame: ${image.width}x${image.height}, '
            'rotation: ${inputImage.metadata.rotation}, '
            'poses: ${poses.length}, '
            'landmarks: ${poses.isNotEmpty ? poses.first.landmarks.length : 0}');
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

/// 用于 isolate 计算的输入数据
class _PoseDetectionInput {
  final PoseDetector detector;
  final InputImage inputImage;

  _PoseDetectionInput({
    required this.detector,
    required this.inputImage,
  });
}

/// 在 isolate 中运行姿态检测
Future<List<Pose>> _detectPoses(_PoseDetectionInput input) async {
  final poses = await input.detector.processImage(input.inputImage);
  return poses;
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
  /// 修复旋转问题：根据相机描述计算正确的旋转角度
  /// Android 前置摄像头通常需要 270° 旋转来匹配竖屏方向
  static InputImage toInputImage(CameraImage image, CameraDescription? cameraDescription) {
    // 将 CameraImage 转换为 ML Kit 可用的格式
    final allBytes = WriteBuffer();
    for (final Plane plane in image.planes) {
      allBytes.putUint8List(plane.bytes);
    }
    final bytes = allBytes.done().buffer.asUint8List();

    // 确定图像格式
    final format = InputImageFormat.values.firstWhere(
      (f) => f.rawValue == image.format.raw,
      orElse: () => InputImageFormat.nv21,
    );

    // 获取第一个平面的 bytesPerRow
    final bytesPerRow = image.planes.isNotEmpty ? image.planes[0].bytesPerRow : 0;

    // ========== 旋转角度计算 ==========
    InputImageRotation rotation;

    if (cameraDescription != null) {
      // 获取传感器方向
      final sensorOrientation = cameraDescription.sensorOrientation;

      // Android 前置摄像头在竖屏模式下的旋转计算
      // 传感器方向 270° 需要转换为 InputImageRotation.rotation270deg
      // 这样 ML Kit 才能正确检测竖向的人脸
      switch (sensorOrientation) {
        case 0:
          rotation = InputImageRotation.rotation0deg;
          break;
        case 90:
          rotation = InputImageRotation.rotation90deg;
          break;
        case 180:
          rotation = InputImageRotation.rotation180deg;
          break;
        case 270:
          rotation = InputImageRotation.rotation270deg;
          break;
        default:
          // 默认：前置摄像头通常是 270°
          rotation = InputImageRotation.rotation270deg;
      }

      // 调试日志（每 30 帧打印一次）
      _frameCount++;
      if (_frameCount % 30 == 0) {
        debugPrint('🔄 Camera rotation calculation: '
            'sensorOrientation=$sensorOrientation°, '
            'inputImageRotation=$rotation, '
            'lensDirection=${cameraDescription.lensDirection}');
      }
    } else {
      // 没有相机描述时，使用默认值（前置摄像头通常 270°）
      debugPrint('⚠️  No camera description, using default rotation (270deg)');
      rotation = InputImageRotation.rotation270deg;
    }

    return InputImage.fromBytes(
      bytes: bytes,
      metadata: InputImageMetadata(
        size: ui.Size(image.width.toDouble(), image.height.toDouble()),
        rotation: rotation,
        format: format,
        bytesPerRow: bytesPerRow,
      ),
    );
  }
}

