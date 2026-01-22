import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../providers/character_provider.dart';
import '../models/practice_mode.dart';

/// 练习模式选择器
class PracticeModeSelector extends StatelessWidget {
  const PracticeModeSelector({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<CharacterProvider>(
      builder: (context, provider, child) {
        final currentMode = provider.practiceMode;

        return Card(
          elevation: 4,
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '练习模式',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                const SizedBox(height: 16),
                Wrap(
                  spacing: 12,
                  runSpacing: 12,
                  children: PracticeMode.values.map((mode) {
                    return _ModeCard(
                      mode: mode,
                      isSelected: currentMode == mode,
                      onTap: () => provider.setPracticeMode(mode),
                    );
                  }).toList(),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _ModeCard extends StatelessWidget {
  final PracticeMode mode;
  final bool isSelected;
  final VoidCallback onTap;

  const _ModeCard({
    required this.mode,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        width: 160,
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: isSelected
              ? colorScheme.primaryContainer
              : colorScheme.surface,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected ? colorScheme.primary : Colors.grey.shade300,
            width: isSelected ? 2 : 1,
          ),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: colorScheme.primary.withOpacity(0.2),
                    blurRadius: 8,
                    offset: const Offset(0, 4),
                  )
                ]
              : null,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  _getModeIcon(mode),
                  color: isSelected ? colorScheme.primary : Colors.grey.shade600,
                  size: 24,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    _getModeTitle(mode),
                    style: theme.textTheme.titleMedium?.copyWith(
                      color: isSelected ? colorScheme.primary : null,
                      fontWeight:
                          isSelected ? FontWeight.bold : FontWeight.normal,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              _getModeDescription(mode),
              style: theme.textTheme.bodySmall?.copyWith(
                color: Colors.grey.shade600,
              ),
            ),
            if (_getModeFeatures(mode).isNotEmpty) ...[
              const SizedBox(height: 8),
              ..._getModeFeatures(mode).map((feature) => Padding(
                    padding: const EdgeInsets.only(left: 32, top: 4),
                    child: Row(
                      children: [
                        Icon(
                          Icons.check_circle_outline,
                          size: 12,
                          color: Colors.green.shade600,
                        ),
                        const SizedBox(width: 4),
                        Expanded(
                          child: Text(
                            feature,
                            style: theme.textTheme.bodySmall,
                          ),
                        ),
                      ],
                    ),
                  )),
            ],
          ],
        ),
      ),
    );
  }

  IconData _getModeIcon(PracticeMode mode) {
    switch (mode) {
      case PracticeMode.basic:
        return Icons.school;
      case PracticeMode.expert:
        return Icons.emoji_events;
      case PracticeMode.custom:
        return.icons.edit_note;
      case PracticeMode.timed:
        return Icons.timer;
    }
  }

  String _getModeTitle(PracticeMode mode) {
    switch (mode) {
      case PracticeMode.basic:
        return '基础模式';
      case PracticeMode.expert:
        return '专家模式';
      case PracticeMode.custom:
        return '自定义模式';
      case PracticeMode.timed:
        return '计时模式';
    }
  }

  String _getModeDescription(PracticeMode mode) {
    switch (mode) {
      case PracticeMode.basic:
        return '适合初学者，提供详细指导';
      case PracticeMode.expert:
        return '高标准要求，挑战满分';
      case PracticeMode.custom:
        return '使用教师提供的范字';
      case PracticeMode.timed:
        return '限时完成，提升书写速度';
    }
  }

  List<String> _getModeFeatures(PracticeMode mode) {
    switch (mode) {
      case PracticeMode.basic:
        return ['实时笔画提示', '宽松评分标准', '姿态友好提醒'];
      case PracticeMode.expert:
        return ['严格评分标准', '无笔画提示', '精确笔顺要求'];
      case PracticeMode.custom:
        return ['教师范字', '个性化指导', '班级排行榜'];
      case PracticeMode.timed:
        return ['30秒限时', '速度训练', '效率评分'];
    }
  }
}

/// 练习模式确认对话框
class PracticeModeDialog extends StatelessWidget {
  final PracticeMode selectedMode;

  const PracticeModeDialog({
    super.key,
    required this.selectedMode,
  });

  static Future<PracticeMode?> show(BuildContext context) {
    return showModalBottomSheet<PracticeMode>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => PracticeModeDialog(
        selectedMode: context.read<CharacterProvider>().practiceMode,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                '选择练习模式',
                style: Theme.of(context).textTheme.headlineSmall,
              ),
              const SizedBox(height: 24),
              ...PracticeMode.values.map((mode) {
                return Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: _ModeListItem(
                    mode: mode,
                    isSelected: selectedMode == mode,
                    onTap: () => Navigator.of(context).pop(mode),
                  ),
                );
              }),
              const SizedBox(height: 16),
            ],
          ),
        ),
      ),
    );
  }
}

class _ModeListItem extends StatelessWidget {
  final PracticeMode mode;
  final bool isSelected;
  final VoidCallback onTap;

  const _ModeListItem({
    required this.mode,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return ListTile(
      onTap: onTap,
      selected: isSelected,
      selectedTileColor: colorScheme.primaryContainer,
      leading: Icon(
        _getModeIcon(mode),
        color: isSelected ? colorScheme.primary : Colors.grey.shade600,
      ),
      title: Text(
        _getModeTitle(mode),
        style: TextStyle(
          fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
          color: isSelected ? colorScheme.primary : null,
        ),
      ),
      subtitle: Text(_getModeDescription(mode)),
      trailing: isSelected
          ? Icon(Icons.check_circle, color: colorScheme.primary)
          : null,
    );
  }

  IconData _getModeIcon(PracticeMode mode) {
    switch (mode) {
      case PracticeMode.basic:
        return Icons.school;
      case PracticeMode.expert:
        return Icons.emoji_events;
      case PracticeMode.custom:
        return Icons.edit_note;
      case PracticeMode.timed:
        return Icons.timer;
    }
  }

  String _getModeTitle(PracticeMode mode) {
    switch (mode) {
      case PracticeMode.basic:
        return '基础模式';
      case PracticeMode.expert:
        return '专家模式';
      case PracticeMode.custom:
        return '自定义模式';
      case PracticeMode.timed:
        return '计时模式';
    }
  }

  String _getModeDescription(PracticeMode mode) {
    switch (mode) {
      case PracticeMode.basic:
        return '适合初学者';
      case PracticeMode.expert:
        return '高标准挑战';
      case PracticeMode.custom:
        return '教师范字';
      case PracticeMode.timed:
        return '限时完成';
    }
  }
}
