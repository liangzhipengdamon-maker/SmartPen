import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/posture_provider.dart';
import '../services/posture_data.dart';
import '../services/grip_state.dart';

/// AI 导师仪表板 - 显示姿态和手部状态
class AiTutorDashboard extends StatelessWidget {
  const AiTutorDashboard({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<PostureProvider>(
      builder: (context, postureProvider, child) {
        // 只在监测中时显示
        if (!postureProvider.isMonitoring) {
          return const SizedBox.shrink();
        }

        final analysis = postureProvider.currentAnalysis;
        if (analysis == null) {
          return const SizedBox.shrink();
        }

        return Container(
          margin: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
          padding: const EdgeInsets.all(12.0),
          decoration: BoxDecoration(
            color: Colors.blue.shade50,
            borderRadius: BorderRadius.circular(12.0),
            border: Border.all(color: Colors.blue.shade200),
          ),
          child: Column(
            children: [
              // 状态行胶囊
              Row(
                children: [
                  _buildStatusCapsule(
                    icon: '👤',
                    label: '姿态',
                    isGood: analysis.isCorrect,
                  ),
                  const SizedBox(width: 8),
                  _buildStatusCapsule(
                    icon: analysis.gripState.icon,
                    label: '手部',
                    isGood: analysis.gripState == GripState.holdingPen,
                    customColor: analysis.gripState.color,
                  ),
                ],
              ),
              const SizedBox(height: 12),
              // 操作区
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  _buildActionButton(
                    icon: Icons.photo_camera,
                    label: '拍照评分',
                    onPressed: () {
                      Navigator.pushNamed(context, '/photo_capture');
                    },
                    color: Colors.green,
                  ),
                  _buildActionButton(
                    icon: Icons.mic,
                    label: '语音指令',
                    onPressed: () {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('语音指令功能即将推出')),
                      );
                    },
                    color: Colors.blue,
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildStatusCapsule({
    required String icon,
    required String label,
    required bool isGood,
    Color? customColor,
  }) {
    final backgroundColor = customColor ?? (isGood ? Colors.green.shade100 : Colors.orange.shade100);
    final textColor = customColor ?? (isGood ? Colors.green : Colors.orange);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: textColor.withOpacity(0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(icon, style: const TextStyle(fontSize: 16)),
          const SizedBox(width: 4),
          Text(
            label,
            style: TextStyle(
              color: textColor,
              fontWeight: FontWeight.bold,
              fontSize: 14,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActionButton({
    required IconData icon,
    required String label,
    required VoidCallback onPressed,
    required Color color,
  }) {
    return ElevatedButton.icon(
      onPressed: onPressed,
      icon: Icon(icon),
      label: Text(label),
      style: ElevatedButton.styleFrom(
        backgroundColor: color,
        foregroundColor: Colors.white,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      ),
    );
  }
}
