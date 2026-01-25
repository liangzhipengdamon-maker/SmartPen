import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../widgets/character_display.dart';
import '../widgets/writing_canvas.dart';
import '../widgets/score_panel.dart';
import '../providers/character_provider.dart';

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
    });
  }

  @override
  void dispose() {
    _characterController.dispose();
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
      body: SafeArea(
        child: Column(
          children: [
            // 字符输入栏
            _buildCharacterInput(),

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
                      _buildControlButtons(provider),
                    ],
                  );
                },
              ),
            ),
          ],
        ),
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

  Widget _buildControlButtons(CharacterProvider provider) {
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          ElevatedButton.icon(
            onPressed: provider.strokeCount > 0 ? provider.undoStroke : null,
            icon: const Icon(Icons.undo),
            label: const Text('撤销'),
          ),
          ElevatedButton.icon(
            onPressed: provider.strokeCount > 0 ? provider.clearWriting : null,
            icon: const Icon(Icons.clear),
            label: const Text('清空'),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.orange,
            ),
          ),
          ElevatedButton.icon(
            onPressed: provider.strokeCount > 0
                ? () => provider.submitScore()
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
    );
  }
}
