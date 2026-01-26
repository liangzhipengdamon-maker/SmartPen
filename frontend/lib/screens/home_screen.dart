import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../widgets/character_display.dart';
import '../widgets/writing_canvas.dart';
import '../widgets/score_panel.dart';
import '../widgets/feedback_overlay.dart';
import '../widgets/camera_preview.dart';
import '../widgets/camera_permission_dialog.dart';
import '../providers/character_provider.dart';
import '../providers/posture_provider.dart';

/// 主屏幕
class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final TextEditingController _characterController = TextEditingController(
    text: '永',
  );

  @override
  void initState() {
    super.initState();
    // 加载默认字符
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      context.read<CharacterProvider>().loadCharacter('永');

      // 尝试初始化姿态监测（但不自动启动）
      try {
        final postureProvider = context.read<PostureProvider>();
        await postureProvider.initialize();
        debugPrint('HomeScreen: Posture monitoring initialized successfully');
      } catch (e) {
        // 姿态监测初始化失败，但不影响应用其他功能
        debugPrint('HomeScreen: Posture monitoring initialization failed - $e');
      }
    });
  }

  @override
  void dispose() {
    _characterController.dispose();
    // 停止相机流和姿态监测（如果已初始化）
    try {
      final provider = context.read<PostureProvider>();
      provider.cameraController?.stopCameraStream();
      provider.stopMonitoring();
    } catch (e) {
      // 忽略错误
    }
    super.dispose();
  }

  void _loadCharacter() {
    final char = _characterController.text.trim();
    if (char.isNotEmpty) {
      context.read<CharacterProvider>().loadCharacter(char);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('智笔 - AI 书法教学'),
        actions: [
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
          // 主内容
          SafeArea(
            child: Column(
              children: [
                // 字符输入栏
                _buildCharacterInput(),

                // 相机预览区域（仅在监测时显示）
                Consumer<PostureProvider>(
                  builder: (context, postureProvider, child) {
                    return postureProvider.isMonitoring
                        ? Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 16.0),
                            child: SizedBox(
                              height: 180,
                              child: CameraPreviewWidget(provider: postureProvider),
                            ),
                          )
                        : const SizedBox.shrink();
                  },
                ),

                // 主内容区域
                Expanded(
                  child: Consumer<CharacterProvider>(
                    builder: (context, provider, child) {
                      if (provider.isLoading) {
                        return const Center(child: CircularProgressIndicator());
                      }

                      if (provider.errorMessage != null) {
                        return Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              const Icon(Icons.error_outline, size: 48, color: Colors.red),
                              const SizedBox(height: 16),
                              Text(
                                provider.errorMessage!,
                                style: Theme.of(context).textTheme.bodyLarge,
                                textAlign: TextAlign.center,
                              ),
                              const SizedBox(height: 16),
                              ElevatedButton(
                                onPressed: _loadCharacter,
                                child: const Text('重试'),
                              ),
                            ],
                          ),
                        );
                      }

                      if (provider.currentCharacter == null) {
                        return const Center(
                          child: Text('请输入要练习的字符'),
                        );
                      }

                      return Column(
                        children: [
                          // 范字显示和书写区域（纵向排列）
                          Expanded(
                            child: Column(
                              children: [
                                // 上部：范字
                                Expanded(
                                  flex: 1,
                                  child: CharacterDisplay(
                                    character: provider.currentCharacter!,
                                  ),
                                ),

                                // 下部：摄像头输入区域
                                Expanded(
                                  flex: 1,
                                  child: WritingCanvas(
                                    onStrokeComplete: () {
                                      // 笔画完成回调
                                    },
                                  ),
                                ),
                              ],
                            ),
                          ),

                          // 底部：评分面板
                          if (provider.lastScore != null)
                            ScorePanel(score: provider.lastScore!),

                          // 控制按钮
                          _buildControlButtons(),
                        ],
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
          // 实时反馈叠加层（姿态监测）
          const FeedbackOverlay(),
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

  Widget _buildControlButtons() {
    return Consumer2<CharacterProvider, PostureProvider>(
      builder: (context, charProvider, postureProvider, child) {
        return Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            children: [
              // 相机控制按钮
              ElevatedButton.icon(
                onPressed: () async {
                  if (postureProvider.isMonitoring) {
                    // 停止监测
                    await postureProvider.cameraController?.stopCameraStream();
                    postureProvider.stopMonitoring();
                  } else {
                    // 启动监测
                    try {
                      await postureProvider.cameraController!.startCameraStream();
                      postureProvider.startMonitoring();
                    } catch (e) {
                      // 显示错误对话框
                      if (e.toString().contains('Permission')) {
                        await CameraPermissionDialog.show(context);
                      }
                    }
                  }
                },
                icon: Icon(
                  postureProvider.isMonitoring ? Icons.videocam_off : Icons.videocam,
                ),
                label: Text(postureProvider.isMonitoring ? '停止监测' : '开始监测'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: postureProvider.isMonitoring ? Colors.red : Colors.blue,
                  minimumSize: const Size(double.infinity, 48),
                ),
              ),
              const SizedBox(height: 8),

              // 书写控制按钮
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  ElevatedButton.icon(
                    onPressed: charProvider.strokeCount > 0 ? charProvider.undoStroke : null,
                    icon: const Icon(Icons.undo),
                    label: const Text('撤销'),
                  ),
                  ElevatedButton.icon(
                    onPressed: charProvider.strokeCount > 0 ? charProvider.clearWriting : null,
                    icon: const Icon(Icons.clear),
                    label: const Text('清空'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.orange,
                    ),
                  ),
                  ElevatedButton.icon(
                    onPressed: charProvider.strokeCount > 0
                        ? () => charProvider.submitScore()
                        : null,
                    icon: const Icon(Icons.grade),
                    label: const Text('评分'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.green,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 32,
                        vertical: 16,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }
}
