// DEPRECATED: realtime AR overlay disabled per PRD v2.2
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../providers/posture_provider.dart';
import '../services/posture_data.dart';

/// 实时反馈叠加层 - AR 风格的姿态反馈
class FeedbackOverlay extends StatelessWidget {
  const FeedbackOverlay({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<PostureProvider>(
      builder: (context, provider, child) {
        final analysis = provider.currentAnalysis;

        if (analysis == null) {
          return const SizedBox.shrink();
        }

        return Positioned(
          top: 0,
          left: 0,
          right: 0,
          child: SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: _buildFeedbackCard(context, analysis!),
            ),
          ),
        );
      },
    );
  }

  Widget _buildFeedbackCard(BuildContext context, PostureAnalysis analysis) {
    final level = analysis.warningLevel;
    final color = _getWarningColor(level);
    final icon = _getWarningIcon(level);

    return Card(
      color: color.withOpacity(0.9),
      child: Padding(
        padding: const EdgeInsets.all(12.0),
        child: Row(
          children: [
            Icon(icon, color: Colors.white),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    _getWarningTitle(level),
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                  ),
                  if (!analysis.isCorrect) ...[
                    const SizedBox(height: 4),
                    Text(
                      analysis.feedback,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 14,
                      ),
                    ),
                  ],
                ],
              ),
            ),
            // 评分
            if (analysis.isCorrect)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.thumb_up, color: Colors.white, size: 16),
                    const SizedBox(width: 4),
                    Text(
                      '良好',
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }

  Color _getWarningColor(PostureWarningLevel level) {
    switch (level) {
      case PostureWarningLevel.good:
        return Colors.green;
      case PostureWarningLevel.warning:
        return Colors.orange;
      case PostureWarningLevel.critical:
        return Colors.red;
    }
  }

  IconData _getWarningIcon(PostureWarningLevel level) {
    switch (level) {
      case PostureWarningLevel.good:
        return Icons.check_circle;
      case PostureWarningLevel.warning:
        return Icons.warning;
      case PostureWarningLevel.critical:
        return Icons.error;
    }
  }

  String _getWarningTitle(PostureWarningLevel level) {
    switch (level) {
      case PostureWarningLevel.good:
        return '坐姿良好';
      case PostureWarningLevel.warning:
        return '请注意坐姿';
      case PostureWarningLevel.critical:
        return '坐姿不正确';
    }
  }
}

/// 姿态数据可视化组件
class PostureVisualization extends StatelessWidget {
  final PostureAnalysis analysis;

  const PostureVisualization({
    super.key,
    required this.analysis,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16.0),
      decoration: BoxDecoration(
        color: Colors.grey.shade100,
        borderRadius: BorderRadius.circular(12.0),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '姿态数据',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 16),
          _buildMetricRow(
            context,
            '脊柱角度',
            '${analysis.spineAngle.toStringAsFixed(1)}°',
            analysis.isSpineCorrect,
            Icons.accessibility_new,
          ),
          const SizedBox(height: 12),
          _buildMetricRow(
            context,
            '眼屏距离',
            '${analysis.eyeScreenDistance.toStringAsFixed(1)}cm',
            analysis.isDistanceCorrect,
            Icons.remove_red_eye,
          ),
          const SizedBox(height: 12),
          _buildMetricRow(
            context,
            '头部倾斜',
            '${analysis.headTiltAngle.toStringAsFixed(1)}°',
            analysis.isHeadCorrect,
            Icons.face,
          ),
        ],
      ),
    );
  }

  Widget _buildMetricRow(
    BuildContext context,
    String label,
    String value,
    bool isCorrect,
    IconData icon,
  ) {
    return Row(
      children: [
        Icon(
          icon,
          color: isCorrect ? Colors.green : Colors.orange,
          size: 20,
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            label,
            style: Theme.of(context).textTheme.bodyMedium,
          ),
        ),
        Text(
          value,
          style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                color: isCorrect ? Colors.green : Colors.orange,
                fontWeight: FontWeight.bold,
              ),
        ),
      ],
    );
  }
}
