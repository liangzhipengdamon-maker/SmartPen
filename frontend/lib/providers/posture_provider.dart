import 'dart:async';
import 'dart:ui' as ui;
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:camera/camera.dart' as camera;
import 'package:permission_handler/permission_handler.dart';

import 'package:google_mlkit_pose_detection/google_mlkit_pose_detection.dart';

import '../services/mlkit_service.dart';
import '../services/posture_detector.dart' as detector;
import '../services/posture_data.dart';
import '../services/grip_state.dart';
import '../services/calibration_state_manager.dart';
import '../utils/frame_throttler.dart';

/// 姿态监测状态管理
class PostureProvider extends ChangeNotifier {
  final MLKitPoseService _mlkitService = MLKitPoseService();
  final CalibrationStateManager _calibrationManager = CalibrationStateManager();

  PostureAnalysis? _currentAnalysis;
  List<Pose> _currentPoses = [];
  bool _isMonitoring = false;
  String? _errorMessage;
  StreamSubscription<List<Pose>>? _poseSubscription;
  CameraController? _cameraController;

  // 当前相机图像尺寸
  ui.Size? _currentImageSize;

  // Getters
  PostureAnalysis? get currentAnalysis => _currentAnalysis;
  List<Pose> get currentPoses => List.unmodifiable(_currentPoses);
  bool get isMonitoring => _isMonitoring;
  String? get errorMessage => _errorMessage;
  CameraController? get cameraController => _cameraController;
  ui.Size? get currentImageSize => _currentImageSize;

  // 新增：校准状态访问器
  CalibrationState get calibrationState => _calibrationManager.currentState;
  bool get isReadyForPractice => _calibrationManager.isReadyForPractice;
  String get calibrationMessage => _calibrationManager.currentState.message;
  Color get calibrationColor => _calibrationManager.currentState.color;

  bool get hasGoodPosture {
    return _currentAnalysis?.isCorrect ?? false;
  }

  /// 初始化姿态监测
  Future<void> initialize() async {
    debugPrint('════════════════════════════════════════');
    debugPrint('🔧 PostureProvider: 开始初始化...');
    _errorMessage = null;
    notifyListeners();

    try {
      debugPrint('📦 正在初始化 ML Kit...');
      await _mlkitService.initialize();
      debugPrint('✅ ML Kit 初始化成功');

      // 初始化相机控制器
      debugPrint('📷 正在创建相机控制器...');
      _cameraController = CameraController(this);
      debugPrint('📷 正在初始化相机硬件...');
      await _cameraController!.initialize();
      debugPrint('✅ PostureProvider: 相机控制器初始化成功');
      debugPrint('════════════════════════════════════════');
    } catch (e) {
      _errorMessage = '初始化失败: $e';
      debugPrint('❌ PostureProvider: 初始化错误 - $e');
      debugPrint('════════════════════════════════════════');
      notifyListeners();
      rethrow;
    }
  }

  /// 开始监测
  void startMonitoring() {
    if (_isMonitoring) {
      debugPrint('⚠️  PostureProvider: 已经在监测中，跳过');
      return;
    }

    debugPrint('🎯 PostureProvider: 开始监测姿态...');
    _isMonitoring = true;

    // 重置校准管理器
    _calibrationManager.reset();

    // 取消旧订阅
    _poseSubscription?.cancel();

    // 订阅姿态流
    _poseSubscription = _mlkitService.poseStream.listen(
      (poses) {
        _currentPoses = poses;

        // 分析姿态
        if (poses.isNotEmpty) {
          _currentAnalysis = detector.PostureDetector.analyzePose(poses.first);

          // 新增：更新校准状态管理器
          _calibrationManager.processAnalysis(_currentAnalysis!);

          debugPrint('📊 Calibration: ${_currentAnalysis!.calibrationState}, '
              'Ready: $isReadyForPractice');
        }

        notifyListeners();
      },
      onError: (error) {
        debugPrint('❌ PostureProvider: 流错误 - $error');
        _errorMessage = '监测出错: $error';
        notifyListeners();
      },
    );

    notifyListeners();
    debugPrint('✅ PostureProvider: 姿态监测已启动');
  }

  /// 停止监测
  void stopMonitoring() {
    if (!_isMonitoring) {
      debugPrint('⚠️  PostureProvider: 未在监测中，跳过停止');
      return;
    }

    debugPrint('🛑 PostureProvider: 停止监测...');
    _isMonitoring = false;

    // 取消订阅
    _poseSubscription?.cancel();
    _poseSubscription = null;

    // 清空数据
    _currentPoses = [];
    _currentAnalysis = null;

    // 重置校准管理器
    _calibrationManager.reset();

    notifyListeners();

    debugPrint('✅ PostureProvider: 姿态监测已停止');
  }

  /// 处理相机帧
  Future<void> processCameraImage(camera.CameraImage image) async {
    if (!_isMonitoring) return;

    // 记录当前图像尺寸
    _currentImageSize = ui.Size(image.width.toDouble(), image.height.toDouble());

    try {
      // 获取相机描述用于旋转计算
      final cameraDescription = _cameraController?._internalController?.description;
      await _mlkitService.processCameraImage(image, cameraDescription);
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
    _cameraController?.dispose();
    _mlkitService.dispose();
    _calibrationManager.dispose();  // 新增
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
    debugPrint('📷 CameraController: 开始初始化相机硬件...');
    try {
      // 1. 检查相机权限
      debugPrint('🔐 检查相机权限...');
      final status = await Permission.camera.request();
      debugPrint('🔐 权限状态: $status');
      if (!status.isGranted) {
        debugPrint('❌ 权限被拒绝');
        _provider._errorMessage = '需要相机权限进行姿态检测';
        _provider.notifyListeners();
        return false;
      }
      debugPrint('✅ 权限已授予');

      // 2. 获取可用相机
      debugPrint('📹 获取可用相机列表...');
      final cameras = await camera.availableCameras();
      debugPrint('📹 找到 ${cameras.length} 个相机');
      if (cameras.isEmpty) {
        debugPrint('❌ 未找到可用相机');
        _provider._errorMessage = '未找到可用相机';
        _provider.notifyListeners();
        return false;
      }

      // 3. 查找前置摄像头
      debugPrint('🎥 查找前置摄像头...');
      final frontCamera = cameras.firstWhere(
        (c) => c.lensDirection == camera.CameraLensDirection.front,
        orElse: () {
          debugPrint('⚠️  未找到前置摄像头，使用第一个相机');
          return cameras.first;
        },
      );
      debugPrint('🎥 使用相机: ${frontCamera.name}');

      // 4. 创建相机控制器
      debugPrint('🔧 创建相机控制器...');
      _internalController = camera.CameraController(
        frontCamera,
        camera.ResolutionPreset.medium,
        enableAudio: false,
      );

      // 5. 初始化相机
      debugPrint('⚡ 初始化相机硬件...');
      await _internalController!.initialize();
      _isInitialized = true;

      debugPrint('✅ CameraController: 相机初始化成功');
      return true;
    } catch (e) {
      debugPrint('❌ CameraController: 初始化错误 - $e');
      _provider._errorMessage = '相机初始化失败: $e';
      _provider.notifyListeners();
      return false;
    }
  }

  /// 启动相机流
  Future<void> startCameraStream() async {
    debugPrint('🎬 CameraController: 启动相机流...');
    if (!_isInitialized) {
      debugPrint('⚠️  相机未初始化，先初始化...');
      final success = await initialize();
      if (!success) {
        debugPrint('❌ 相机初始化失败');
        throw Exception('Camera initialization failed');
      }
    }

    try {
      debugPrint('📡 调用 startImageStream...');
      await _internalController!.startImageStream((cameraImage) {
        // 使用节流器控制帧率
        if (_throttler.shouldProcess()) {
          _provider.processCameraImage(cameraImage);
        }
      });

      debugPrint('✅ CameraController: 相机流已启动');
    } catch (e) {
      debugPrint('❌ CameraController: 流启动错误 - $e');
      _provider._errorMessage = '启动相机流失败: $e';
      _provider.notifyListeners();
      rethrow;
    }
  }

  /// 停止相机流
  Future<void> stopCameraStream() async {
    debugPrint('🛑 CameraController: 停止相机流...');
    try {
      if (_internalController != null) {
        debugPrint('⏹️  停止图像流...');
        await _internalController!.stopImageStream();
        debugPrint('⏹️  图像流已停止');
      }
    } catch (e) {
      debugPrint('⚠️  停止图像流错误 - $e');
    }

    try {
      if (_internalController != null) {
        debugPrint('🗑️  释放相机资源...');
        await _internalController!.dispose();
        debugPrint('🗑️  相机资源已释放');
      }
    } catch (e) {
      debugPrint('⚠️  释放相机错误 - $e');
    } finally {
      _internalController = null;
      _isInitialized = false;
      debugPrint('✅ CameraController: 相机流已停止');
    }
  }

  /// 获取相机控制器实例（用于预览）
  camera.CameraController? get controller => _internalController;

  /// 相机是否已初始化
  bool get isInitialized => _isInitialized;

  /// 释放资源
  void dispose() {
    debugPrint('🗑️  CameraController.dispose() 被调用');
    stopCameraStream();
  }
}
