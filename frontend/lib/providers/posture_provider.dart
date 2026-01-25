import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:camera/camera.dart' as camera;
import 'package:permission_handler/permission_handler.dart';

import 'package:google_mlkit_pose_detection/google_mlkit_pose_detection.dart';

import '../services/mlkit_service.dart';
import '../services/posture_detector.dart' as detector;
import '../services/posture_data.dart';
import '../utils/frame_throttler.dart';

/// 姿态监测状态管理
class PostureProvider extends ChangeNotifier {
  final MLKitPoseService _mlkitService = MLKitPoseService();

  PostureAnalysis? _currentAnalysis;
  List<Pose> _currentPoses = [];
  bool _isMonitoring = false;
  String? _errorMessage;
  StreamSubscription<List<Pose>>? _poseSubscription;

  // Getters
  PostureAnalysis? get currentAnalysis => _currentAnalysis;
  List<Pose> get currentPoses => List.unmodifiable(_currentPoses);
  bool get isMonitoring => _isMonitoring;
  String? get errorMessage => _errorMessage;

  bool get hasGoodPosture {
    return _currentAnalysis?.isCorrect ?? false;
  }

  /// 初始化姿态监测
  Future<void> initialize() async {
    _errorMessage = null;
    notifyListeners();

    try {
      await _mlkitService.initialize();
      debugPrint('PostureProvider: ML Kit initialized');
    } catch (e) {
      _errorMessage = '初始化失败: $e';
      debugPrint('PostureProvider: Initialization error - $e');
      notifyListeners();
    }
  }

  /// 开始监测
  void startMonitoring() {
    if (_isMonitoring) return;

    _isMonitoring = true;

    // 取消旧订阅
    _poseSubscription?.cancel();

    // 订阅姿态流
    _poseSubscription = _mlkitService.poseStream.listen(
      (poses) {
        _currentPoses = poses;

        // 分析姿态
        if (poses.isNotEmpty) {
          _currentAnalysis = detector.PostureDetector.analyzePose(poses.first);
        }

        notifyListeners();
      },
      onError: (error) {
        debugPrint('PostureProvider: Stream error - $error');
        _errorMessage = '监测出错: $error';
        notifyListeners();
      },
    );

    notifyListeners();
    debugPrint('PostureProvider: Started monitoring');
  }

  /// 停止监测
  void stopMonitoring() {
    if (!_isMonitoring) return;

    _isMonitoring = false;

    // 取消订阅
    _poseSubscription?.cancel();
    _poseSubscription = null;

    // 清空数据
    _currentPoses = [];
    _currentAnalysis = null;

    notifyListeners();

    debugPrint('PostureProvider: Stopped monitoring');
  }

  /// 处理相机帧
  Future<void> processCameraImage(camera.CameraImage image) async {
    if (!_isMonitoring) return;

    try {
      await _mlkitService.processCameraImage(image);
    } catch (e) {
      debugPrint('PostureProvider: Failed to process image - $e');
      _errorMessage = '图像处理失败: $e';
      notifyListeners();
    }
  }

  /// 获取姿态评分 (0-100)
  int getPostureScore() {
    if (_currentAnalysis == null) return 0;

    return detector.PostureDetector.calculatePostureScore(_currentAnalysis!);
  }

  @override
  void dispose() {
    stopMonitoring();
    _mlkitService.dispose();
    super.dispose();
  }
}

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
