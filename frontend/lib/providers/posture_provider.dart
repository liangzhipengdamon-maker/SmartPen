import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:camera/camera.dart';

import 'package:google_mlkit_pose_detection/google_mlkit_pose_detection.dart';

import '../services/mlkit_service.dart';
import '../services/posture_detector.dart';
import '../services/posture_data.dart';

/// 姿态监测状态管理
class PostureProvider extends ChangeNotifier {
  final MLKitPoseService _mlkitService = MLKitPoseService();

  PostureAnalysis? _currentAnalysis;
  List<Pose> _currentPoses = [];
  bool _isMonitoring = false;
  String? _errorMessage;
  Timer? _monitoringTimer;

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
    notifyListeners();

    // 订阅姿态流
    _mlkitService.poseStream.listen((poses) {
      _currentPoses = poses;

      // 分析姿态
      if (poses.isNotEmpty) {
        _currentAnalysis = PostureDetector.analyzePose(poses.first);
      }

      notifyListeners();
    });

    debugPrint('PostureProvider: Started monitoring');
  }

  /// 停止监测
  void stopMonitoring() {
    if (!_isMonitoring) return;

    _isMonitoring = false;
    _monitoringTimer?.cancel();
    _monitoringTimer = null;

    // 清空数据
    _currentPoses = [];
    _currentAnalysis = null;

    notifyListeners();

    debugPrint('PostureProvider: Stopped monitoring');
  }

  /// 处理相机帧
  Future<void> processCameraImage(CameraImage image) async {
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

    return PostureDetector.calculatePostureScore(_currentAnalysis!);
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

  CameraController(this._provider);

  /// 启动相机流
  Future<void> startCameraStream() async {
    // TODO: 实现 camera 包的相机初始化
    // 这需要 device_id 和其他配置
    debugPrint('CameraController: Starting camera stream...');
    _provider.startMonitoring();
  }

  /// 停止相机流
  Future<void> stopCameraStream() async {
    debugPrint('CameraController: Stopping camera stream...');
    _provider.stopMonitoring();
  }
}
