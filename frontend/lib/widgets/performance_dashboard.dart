import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../providers/character_provider.dart';
import '../models/practice_mode.dart';

/// 性能分析仪表板
class PerformanceDashboard extends StatefulWidget {
  const PerformanceDashboard({super.key});

  @override
  State<PerformanceDashboard> createState() => _PerformanceDashboardState();
}

class _PerformanceDashboardState extends State<PerformanceDashboard>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('学习分析'),
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(text: '概览', icon: Icon(Icons.dashboard)),
            Tab(text: '详情', icon: Icon(Icons.analytics)),
            Tab(text: '排行', icon: Icon(Icons.leaderboard)),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: const [
          _OverviewTab(),
          _DetailTab(),
          _LeaderboardTab(),
        ],
      ),
    );
  }
}

/// 概览标签页
class _OverviewTab extends StatelessWidget {
  const _OverviewTab();

  @override
  Widget build(BuildContext context) {
    return Consumer<CharacterProvider>(
      builder: (context, provider, child) {
        final summary = provider.progressSummary;

        return SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 总练习次数卡片
              _StatCard(
                title: '总练习次数',
                value: '${summary.totalPractices}',
                icon: Icons.edit,
                color: Colors.blue,
              ),
              const SizedBox(height: 16),

              // 学习字符数
              _StatCard(
                title: '学习字符数',
                value: '${summary.uniqueCharacters}',
                icon: Icons.chars,
                color: Colors.green,
              ),
              const SizedBox(height: 16),

              // 平均分
              _StatCard(
                title: '平均得分',
                value: '${summary.averageScore.toStringAsFixed(1)}',
                icon: Icons.grade,
                color: Colors.orange,
              ),
              const SizedBox(height: 16),

              // 最高分
              _StatCard(
                title: '最高得分',
                value: '${summary.bestScore}',
                icon: Icons.emoji_events,
                color: Colors.purple,
              ),
              const SizedBox(height: 16),

              // 总学习时长
              _StatCard(
                title: '总学习时长',
                value: '${summary.totalTimeSpent.toStringAsFixed(1)} 小时',
                icon: Icons.access_time,
                color: Colors.teal,
              ),
              const SizedBox(height: 24),

              // 最近得分趋势
              Text(
                '最近练习',
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: 16),
              _RecentScoresChart(scores: summary.recentScores),
              const SizedBox(height: 24),

              // 连续练习天数
              _StreakCard(
                currentStreak: provider.currentStreak,
                longestStreak: provider.longestStreak,
              ),
            ],
          ),
        );
      },
    );
  }
}

/// 统计卡片
class _StatCard extends StatelessWidget {
  final String title;
  final String value;
  final IconData icon;
  final Color color;

  const _StatCard({
    required this.title,
    required this.value,
    required this.icon,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: color.withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon, color: color, size: 24),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: Colors.grey.shade600,
                        ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    value,
                    style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                          color: color,
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
}

/// 最近得分图表
class _RecentScoresChart extends StatelessWidget {
  final List<int> scores;

  const _RecentScoresChart({required this.scores});

  @override
  Widget build(BuildContext context) {
    if (scores.isEmpty) {
      return const Card(
        child: Padding(
          padding: EdgeInsets.all(32.0),
          child: Center(
            child: Text('暂无练习记录'),
          ),
        ),
      );
    }

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '最近 10 次得分',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 16),
            SizedBox(
              height: 150,
              child: CustomPaint(
                painter: _ScoresChartPainter(scores),
                size: Size.infinite,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ScoresChartPainter extends CustomPainter {
  final List<int> scores;

  _ScoresChartPainter(this.scores);

  @override
  void paint(Canvas canvas, Size size) {
    if (scores.isEmpty) return;

    final padding = 16.0;
    final chartWidth = size.width - padding * 2;
    final chartHeight = size.height - padding * 2;

    // 绘制背景网格
    final gridPaint = Paint()
      ..color = Colors.grey.shade200
      ..style = PaintingStyle.stroke;

    for (int i = 0; i <= 4; i++) {
      final y = padding + (chartHeight / 4) * i;
      canvas.drawLine(
        Offset(padding, y),
        Offset(size.width - padding, y),
        gridPaint,
      );
    }

    // 绘制得分线
    final linePaint = Paint()
      ..color = Colors.blue
      ..strokeWidth = 2
      ..style = PaintingStyle.stroke;

    final points = <Offset>[];
    for (int i = 0; i < scores.length; i++) {
      final x = padding + (chartWidth / (scores.length - 1)) * i;
      final y = padding + chartHeight - (scores[i] / 100) * chartHeight;
      points.add(Offset(x, y));
    }

    for (int i = 1; i < points.length; i++) {
      canvas.drawLine(points[i - 1], points[i], linePaint);
    }

    // 绘制数据点
    final dotPaint = Paint()
      ..color = Colors.blue
      ..style = PaintingStyle.fill;

    for (final point in points) {
      canvas.drawCircle(point, 4, dotPaint);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}

/// 连续练习天数卡片
class _StreakCard extends StatelessWidget {
  final int currentStreak;
  final int longestStreak;

  const _StreakCard({
    required this.currentStreak,
    required this.longestStreak,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 2,
      color: Colors.orange.shade50,
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Row(
          children: [
            Icon(Icons.local_fire_department,
                color: Colors.orange.shade700, size: 32),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '连续练习',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          color: Colors.orange.shade700,
                        ),
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Text(
                        '$currentStreak',
                        style: Theme.of(context)
                            .textTheme
                            .headlineMedium
                            ?.copyWith(
                              color: Colors.orange.shade700,
                              fontWeight: FontWeight.bold,
                            ),
                      ),
                      const SizedBox(width: 4),
                      Text(
                        '天',
                        style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                              color: Colors.orange.shade700,
                            ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '最长记录: $longestStreak 天',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: Colors.orange.shade600,
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
}

/// 详情标签页
class _DetailTab extends StatelessWidget {
  const _DetailTab();

  @override
  Widget build(BuildContext context) {
    return Consumer<CharacterProvider>(
      builder: (context, provider, child) {
        final characterStats = provider.progressSummary.characterStats;

        return SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '各字符统计',
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: 16),
              ...characterStats.entries.map((entry) {
                return _CharacterStatItem(
                  character: entry.key,
                  count: entry.value['count'] as int,
                  avgScore: (entry.value['average_score'] as num).toDouble(),
                );
              }).toList(),
            ],
          ),
        );
      },
    );
  }
}

/// 字符统计项
class _CharacterStatItem extends StatelessWidget {
  final String character;
  final int count;
  final double avgScore;

  const _CharacterStatItem({
    required this.character,
    required this.count,
    required this.avgScore,
  });

  @override
  Widget build(BuildContext context) {
    final scoreColor = avgScore >= 90
        ? Colors.green
        : avgScore >= 80
            ? Colors.blue
            : avgScore >= 60
                ? Colors.orange
                : Colors.red;

    return Card(
      child: ListTile(
        leading: Container(
          width: 48,
          height: 48,
          decoration: BoxDecoration(
            color: Colors.grey.shade100,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Center(
            child: Text(
              character,
              style: Theme.of(context).textTheme.titleLarge,
            ),
          ),
        ),
        title: Text('练习 $count 次'),
        subtitle: Text('平均分: ${avgScore.toStringAsFixed(1)}'),
        trailing: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            color: scoreColor.withOpacity(0.1),
            borderRadius: BorderRadius.circular(16),
          ),
          child: Text(
            '${avgScore.toStringAsFixed(0)}',
            style: TextStyle(
              color: scoreColor,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
      ),
    );
  }
}

/// 排行榜标签页
class _LeaderboardTab extends StatelessWidget {
  const _LeaderboardTab();

  @override
  Widget build(BuildContext context) {
    return Consumer<CharacterProvider>(
      builder: (context, provider, child) {
        final leaderboard = provider.leaderboard;

        return ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: leaderboard.length,
          itemBuilder: (context, index) {
            final entry = leaderboard[index];
            return _LeaderboardItem(
              rank: index + 1,
              userId: entry['userId'] as String,
              avgScore: (entry['averageScore'] as num).toDouble(),
              practiceCount: entry['practiceCount'] as int,
            );
          },
        );
      },
    );
  }
}

/// 排行榜项
class _LeaderboardItem extends StatelessWidget {
  final int rank;
  final String userId;
  final double avgScore;
  final int practiceCount;

  const _LeaderboardItem({
    required this.rank,
    required this.userId,
    required this.avgScore,
    required this.practiceCount,
  });

  @override
  Widget build(BuildContext context) {
    Color rankColor;
    IconData rankIcon;

    if (rank == 1) {
      rankColor = Colors.amber;
      rankIcon = Icons.emoji_events;
    } else if (rank == 2) {
      rankColor = Colors.grey.shade400;
      rankIcon = Icons.military_tech;
    } else if (rank == 3) {
      rankColor = Colors.brown.shade400;
      rankIcon = Icons.workspace_premium;
    } else {
      rankColor = Colors.grey;
      rankIcon = Icons.person;
    }

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: rankColor.withOpacity(0.1),
          child: Icon(rankIcon, color: rankColor),
        ),
        title: Text('用户 $userId'),
        subtitle: Text('练习 $practiceCount 次'),
        trailing: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Text(
              avgScore.toStringAsFixed(1),
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    color: rankColor,
                    fontWeight: FontWeight.bold,
                  ),
            ),
            Text(
              '平均分',
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ],
        ),
      ),
    );
  }
}
