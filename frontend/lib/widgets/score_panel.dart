import 'package:flutter/material.dart';

import '../models/character.dart';

/// 评分面板组件
class ScorePanel extends StatelessWidget {
  final ScoreResult score;

  const ScorePanel({
    super.key,
    required this.score,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
      padding: const EdgeInsets.all(16.0),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            score.gradeColor.withOpacity(0.1),
            score.gradeColor.withOpacity(0.05),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        border: Border.all(
          color: score.gradeColor.withOpacity(0.3),
          width: 2,
        ),
        borderRadius: BorderRadius.circular(12.0),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 总分显示
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '评分结果',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          color: Colors.grey.shade700,
                        ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '${score.totalScore.toStringAsFixed(1)} 分',
                    style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                          color: score.gradeColor,
                          fontWeight: FontWeight.bold,
                        ),
                  ),
                ],
              ),
              // 等级标签
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 8,
                ),
                decoration: BoxDecoration(
                  color: score.gradeColor,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  score.grade,
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 18,
                  ),
                ),
              ),
            ],
          ),

          const Divider(height: 24),

          // 详细统计
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _buildStatItem(
                context,
                label: '笔画数',
                value: '${score.strokeCount}',
                icon: Icons.edit,
              ),
              _buildStatItem(
                context,
                label: '完美笔画',
                value: '${score.perfectStrokes}',
                icon: Icons.star,
              ),
              _buildStatItem(
                context,
                label: '平均分',
                value: '${(score.averageScore * 100).toStringAsFixed(0)}',
                icon: Icons.analytics,
              ),
            ],
          ),

          // 反馈信息
          if (score.feedback != null) ...[
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.blue.shade50,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  Icon(Icons.info_outline, color: Colors.blue.shade700, size: 20),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      score.feedback!,
                      style: TextStyle(color: Colors.blue.shade900),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildStatItem(
    BuildContext context, {
    required String label,
    required String value,
    required IconData icon,
  }) {
    return Column(
      children: [
        Icon(icon, color: Colors.grey.shade600),
        const SizedBox(height: 4),
        Text(
          value,
          style: Theme.of(context).textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.bold,
              ),
        ),
        Text(
          label,
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: Colors.grey.shade600,
              ),
        ),
      ],
    );
  }
}
