import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:camera/camera.dart';
import 'package:flutter/foundation.dart';
import 'package:google_mlkit_pose_detection/google_mlkit_pose_detection.dart';

import '../widgets/character_display.dart';
import '../widgets/score_panel.dart';
import '../widgets/feedback_overlay.dart';
import '../widgets/camera_preview.dart';
import '../widgets/camera_permission_dialog.dart';
import '../widgets/pose_painter.dart';
import '../widgets/ai_tutor_dashboard.dart';
import '../providers/character_provider.dart';
import '../providers/posture_provider.dart';
import '../services/posture_data.dart';

/// 主屏幕 - 垂直可滚动习字本布局
class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final TextEditingController _characterController = TextEditingController(
    text: '永',
  );

  // 工作流状态：true = 校准阶段（显示相机），false = 练习阶段（显示画布）
  bool _isCalibrating = false;

  @override
  void initState() {
    super.initState();
    // 加载默认字符（不自动启动姿态监测）
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<CharacterProvider>().loadCharacter('永');
    });
  }

  @override
  void dispose() {
    _characterController.dispose();
    // 停止相机流和姿态监测（如果已初始化）
    try {
      final provider = context.read<PostureProvider>();
      debugPrint('🧹 HomeScreen disposing: 停止相机和监测');
      provider.cameraController?.stopCameraStream();
      provider.stopMonitoring();
    } catch (e) {
      debugPrint('⚠️  HomeScreen dispose error: $e');
    }
    super.dispose();
  }

  void _showErrorSnackBar(BuildContext context, String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red,
        duration: const Duration(seconds: 3),
      ),
    );
  }

  void _loadCharacter() {
    final char = _characterController.text.trim();
    if (char.isNotEmpty) {
      context.read<CharacterProvider>().loadCharacter(char);
    }
  }

  /// 根据校准状态获取图标
  IconData _getStateIcon(CalibrationState state) {
    switch (state) {
      case CalibrationState.noFace:
        return Icons.face_outlined;
      case CalibrationState.badPosture:
        return Icons.accessibility_new;
      case CalibrationState.noHands:
        return Icons.back_hand_outlined;
      case CalibrationState.aligned:
        return Icons.check_circle;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('智笔 - AI 书法教学'),
        actions: [
          // 姿态监测开关
          Consumer<PostureProvider>(
            builder: (context, postureProvider, child) {
              return Switch(
                value: postureProvider.isMonitoring,
                onChanged: (value) async {
                  debugPrint('════════════════════════════════════════');
                  debugPrint('🔄 用户点击开关: $value');

                  if (value) {
                    // ========== Switch ON -> 进入校准阶段 ==========
                    debugPrint('🔐 请求相机权限...');

                    // 1. 请求权限
                    final status = await Permission.camera.request();
                    debugPrint('🔐 权限状态: $status');

                    if (!status.isGranted) {
                      debugPrint('❌ 权限被拒绝，显示引导对话框');
                      await CameraPermissionDialog.show(context);
                      return;
                    }

                    debugPrint('✅ 权限已授予');

                    // 2. 启动相机
                    try {
                      if (postureProvider.cameraController == null) {
                        await postureProvider.initialize();
                      }

                      await postureProvider.cameraController!.startCameraStream();
                      postureProvider.startMonitoring();

                      debugPrint('✅ 相机已启动，进入校准阶段');

                      // 3. 进入校准阶段（显示全屏相机）
                      setState(() {
                        _isCalibrating = true;
                      });
                    } catch (e) {
                      debugPrint('❌ 启动相机失败: $e');

                      // 更全面的错误检测
                      if (e.toString().contains('Permission') ||
                          e.toString().contains('permission') ||
                          e.toString().contains('denied') ||
                          e.toString().contains('Camera')) {
                        await CameraPermissionDialog.show(context);
                      } else {
                        _showErrorSnackBar(context, '启动相机失败: $e');
                      }
                    }
                  } else {
                    // ========== Switch OFF -> 返回练习阶段 ==========
                    debugPrint('🛑 停止监测和相机流...');

                    await postureProvider.cameraController?.stopCameraStream();
                    postureProvider.stopMonitoring();

                    // 返回练习阶段
                    setState(() {
                      _isCalibrating = false;
                    });

                    debugPrint('✅ 姿态监测已停止，返回练习阶段');
                  }

                  debugPrint('════════════════════════════════════════');
                },
              );
            },
          ),
          // 姿态状态指示器
          Consumer<PostureProvider>(
            builder: (context, postureProvider, child) {
              final isGood = postureProvider.hasGoodPosture;
              return Padding(
                padding: const EdgeInsets.only(right: 8.0),
                child: CircleAvatar(
                  radius: 6,
                  backgroundColor: isGood ? Colors.green : Colors.red,
                ),
              );
            },
          ),
          IconButton(
            icon: const Icon(Icons.settings),
            onPressed: () {
              // TODO: 打开设置页面
            },
          ),
        ],
      ),
      body: Stack(
        children: [
          // ========== Layer 1 (底层): 练习界面 ==========
          _buildPracticeInterface(),

          // ========== Layer 2 (叠加层): 状态指示器 ==========
          _buildStatusIndicator(),

          // ========== Layer 3 (顶层): 校准界面（条件显示） ==========
          if (_isCalibrating) _buildCalibrationInterface(),
        ],
      ),
    );
  }

  Widget _buildCharacterInput() {
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: _characterController,
              decoration: const InputDecoration(
                labelText: '练习字符',
                hintText: '输入要练习的汉字',
                border: OutlineInputBorder(),
              ),
              maxLength: 1,
              textInputAction: TextInputAction.go,
              onSubmitted: (_) => _loadCharacter(),
            ),
          ),
          const SizedBox(width: 16),
          ElevatedButton.icon(
            onPressed: _loadCharacter,
            icon: const Icon(Icons.search),
            label: const Text('加载'),
          ),
        ],
      ),
    );
  }

  /// 参考区域（范字）- 正方形
  Widget _buildReferenceArea() {
    return Consumer<CharacterProvider>(
      builder: (context, charProvider, child) {
        // ========== 加载状态 ==========
        if (charProvider.isLoading) {
          return Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0),
            child: Column(
              children: [
                const Text(
                  '参考字',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                AspectRatio(
                  aspectRatio: 1.0,
                  child: Container(
                    decoration: BoxDecoration(
                      color: Colors.white,
                      border: Border.all(color: Colors.grey.shade300),
                      borderRadius: BorderRadius.circular(8.0),
                    ),
                    child: const Center(
                      child: CircularProgressIndicator(),
                    ),
                  ),
                ),
              ],
            ),
          );
        }

        // ========== 错误状态 ==========
        if (charProvider.errorMessage != null) {
          return Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0),
            child: Column(
              children: [
                const Text(
                  '参考字',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                AspectRatio(
                  aspectRatio: 1.0,
                  child: Container(
                    decoration: BoxDecoration(
                      color: Colors.white,
                      border: Border.all(color: Colors.red.shade300),
                      borderRadius: BorderRadius.circular(8.0),
                    ),
                    child: Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(Icons.error_outline, color: Colors.red, size: 48),
                          const SizedBox(height: 8),
                          const Text(
                            '加载失败',
                            style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            charProvider.errorMessage!,
                            style: const TextStyle(color: Colors.grey, fontSize: 12),
                            textAlign: TextAlign.center,
                          ),
                          const SizedBox(height: 16),
                          ElevatedButton(
                            onPressed: () => _loadCharacter(),
                            child: const Text('重试'),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          );
        }

        // ========== 空状态 ==========
        if (charProvider.currentCharacter == null) {
          return Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0),
            child: Column(
              children: [
                const Text(
                  '参考字',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                AspectRatio(
                  aspectRatio: 1.0,
                  child: Container(
                    decoration: BoxDecoration(
                      color: Colors.grey.shade100,
                      border: Border.all(color: Colors.grey.shade300),
                      borderRadius: BorderRadius.circular(8.0),
                    ),
                    child: const Center(
                      child: Text(
                        '请输入要练习的汉字',
                        style: TextStyle(color: Colors.grey),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          );
        }

        // ========== 显示范字 ==========
        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16.0),
          child: Column(
            children: [
              const Text(
                '参考字',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              AspectRatio(
                aspectRatio: 1.0,
                child: CharacterDisplay(
                  character: charProvider.currentCharacter!,
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  /// 底部操作按钮
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

  /// ========== 练习界面 - 范字 + AI 导师仪表板 ==========
  Widget _buildPracticeInterface() {
    return SafeArea(
      child: SingleChildScrollView(
        child: Column(
          children: [
            _buildCharacterInput(),
            _buildReferenceArea(),
            const SizedBox(height: 16),
            const AiTutorDashboard(),  // 新增 AI 导师仪表板
            const SizedBox(height: 16),
            _buildActionButtons(),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }

  /// ========== 状态指示器 - 右上角四态显示 ==========
  Widget _buildStatusIndicator() {
    return Positioned(
      top: 16,
      right: 16,
      child: Consumer<PostureProvider>(
        builder: (context, postureProvider, child) {
          // 只在监测中时显示
          if (!postureProvider.isMonitoring) {
            return const SizedBox.shrink();
          }

          final color = postureProvider.calibrationColor;
          final icon = _getStateIcon(postureProvider.calibrationState);

          return AnimatedContainer(
            duration: const Duration(milliseconds: 300),
            child: CircleAvatar(
              radius: 20,
              backgroundColor: color,
              child: Icon(
                icon,
                color: Colors.white,
                size: 24,
              ),
            ),
          );
        },
      ),
    );
  }

  /// ========== 校准界面 - 全屏相机预览（更新版） ==========
  Widget _buildCalibrationInterface() {
    return Consumer<PostureProvider>(
      builder: (context, postureProvider, child) {
        final calibrationState = postureProvider.calibrationState;
        final message = postureProvider.calibrationMessage;
        final color = postureProvider.calibrationColor;
        final isReady = postureProvider.isReadyForPractice;
        final buttonLabel = calibrationState.buttonLabel;  // 用户要求 #2：动态按钮文案

        debugPrint('🎨 UI: state=$calibrationState, color=$color, ready=$isReady, button=$buttonLabel');

        return Container(
          color: Colors.black,
          child: Stack(
            children: [
              // 全屏相机预览
              if (postureProvider.cameraController?.controller != null)
                CameraPreview(postureProvider.cameraController!.controller!),

              // ========== 静态校准引导（虚线轮廓）==========
              Positioned.fill(
                child: IgnorePointer(
                  child: CustomPaint(
                    painter: CalibrationGuidePainter(),
                  ),
                ),
              ),

              // ========== 动态姿态绘制器（ML Kit 检测点）==========
              if (postureProvider.currentPoses.isNotEmpty)
                Positioned.fill(
                  child: IgnorePointer(
                    child: CustomPaint(
                      painter: PosePainter(
                        poses: postureProvider.currentPoses,
                        imageSize: postureProvider.currentImageSize ?? const Size(640, 480),
                      ),
                    ),
                  ),
                ),

              // 顶部提示栏
              Positioned(
                top: 0,
                left: 0,
                right: 0,
                child: Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        Colors.black.withOpacity(0.7),
                        Colors.transparent,
                      ],
                    ),
                  ),
                  child: const Column(
                    children: [
                      Text(
                        '姿态校准',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      SizedBox(height: 8),
                      Text(
                        '请调整坐姿，保持头部在画面中央',
                        style: TextStyle(color: Colors.white70),
                      ),
                    ],
                  ),
                ),
              ),

              // ========== 核心更新：四级反馈状态指示器 ==========
              Positioned(
                right: 16,
                top: 80,
                child: Column(
                  children: [
                    // 状态圆圈
                    AnimatedContainer(
                      duration: const Duration(milliseconds: 300),
                      curve: Curves.easeInOut,
                      child: CircleAvatar(
                        radius: 40,
                        backgroundColor: color,
                        child: Icon(
                          _getStateIcon(calibrationState),
                          color: Colors.white,
                          size: 40,
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    // 状态文本
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 8,
                      ),
                      decoration: BoxDecoration(
                        color: color.withOpacity(0.9),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        message,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              // ========== 核心更新：智能门按钮（动态文案） ==========
              Positioned(
                bottom: 50,
                left: 0,
                right: 0,
                child: Center(
                  child: AnimatedOpacity(
                    duration: const Duration(milliseconds: 300),
                    opacity: 1.0,
                    child: ElevatedButton(
                      // 核心二条件：只有在 aligned 状态持续1秒后才启用
                      onPressed: isReady
                          ? () {
                              setState(() {
                                _isCalibrating = false;
                              });
                              debugPrint('✅ 用户点击"开始练习"');
                            }
                          : null,  // null = 禁用状态
                      style: ElevatedButton.styleFrom(
                        backgroundColor: isReady ? Colors.green : Colors.grey,
                        disabledBackgroundColor: Colors.grey.shade700,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 48,
                          vertical: 16,
                        ),
                        elevation: isReady ? 8 : 0,
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          if (isReady) ...[
                            const Icon(Icons.check_circle, size: 24),
                            const SizedBox(width: 8),
                          ] else ...[
                            const Icon(Icons.lock, size: 24),
                            const SizedBox(width: 8),
                          ],
                          Text(
                            buttonLabel,  // 用户要求 #2：动态按钮文案
                            style: const TextStyle(fontSize: 18),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),

              // ========== 调试信息面板（仅 Debug 模式） ==========
              if (kDebugMode)
                Positioned(
                  left: 16,
                  bottom: 50,
                  child: IgnorePointer(
                    child: Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.black.withOpacity(0.7),
                        borderRadius: BorderRadius.circular(8),
                      ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'State: $calibrationState',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 12,
                            fontFamily: 'monospace',
                          ),
                        ),
                        Text(
                          'Ready: $isReady',
                          style: TextStyle(
                            color: isReady ? Colors.green : Colors.orange,
                            fontSize: 12,
                            fontFamily: 'monospace',
                          ),
                        ),
                        if (postureProvider.currentAnalysis != null)
                          Text(
                            'Hands: ${postureProvider.currentAnalysis!.hasVisibleHands}, '
                            'Face: ${postureProvider.currentAnalysis!.isFaceDetected}',
                            style: const TextStyle(
                              color: Colors.white70,
                              fontSize: 10,
                              fontFamily: 'monospace',
                            ),
                          ),
                        // ========== 新增：显示 nose 坐标用于调试 ==========
                        if (postureProvider.currentPoses.isNotEmpty)
                          Builder(
                            builder: (context) {
                              final pose = postureProvider.currentPoses.first;
                              final nose = pose.landmarks[PoseLandmarkType.nose];
                              if (nose != null) {
                                return Text(
                                  'nose: (${nose.x.toStringAsFixed(2)}, ${nose.y.toStringAsFixed(2)})',
                                  style: const TextStyle(
                                    color: Colors.cyan,
                                    fontSize: 10,
                                    fontFamily: 'monospace',
                                  ),
                                );
                              }
                              return const Text(
                                'nose: null',
                                style: TextStyle(
                                  color: Colors.red,
                                  fontSize: 10,
                                  fontFamily: 'monospace',
                                ),
                              );
                            },
                          ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
