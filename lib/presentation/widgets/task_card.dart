import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../data/models/task_model.dart';
import '../providers/task_provider.dart';
import '../providers/settings_provider.dart';

class TaskCard extends ConsumerWidget {
  final Task task;
  final bool showDate;
  final VoidCallback? onTap;

  const TaskCard({
    super.key,
    required this.task,
    this.showDate = false,
    this.onTap,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final accent = ref.watch(settingsProvider).accentColor;
    final scheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return Card(
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  _StatusBadge(task: task, accent: accent),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      task.title,
                      style: textTheme.titleLarge?.copyWith(
                        decoration: task.status == TaskStatus.completed
                            ? TextDecoration.lineThrough
                            : null,
                        color: task.status == TaskStatus.completed
                            ? scheme.onSurface.withOpacity(0.4)
                            : null,
                      ),
                    ),
                  ),
                  if (task.isCarriedOver)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: Colors.orange.withOpacity(0.15),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: const Text('carried over',
                          style: TextStyle(fontSize: 10, color: Colors.orange)),
                    ),
                ],
              ),
              if (task.description.isNotEmpty) ...[
                const SizedBox(height: 6),
                Text(task.description,
                    style: textTheme.bodyMedium, maxLines: 2, overflow: TextOverflow.ellipsis),
              ],
              const SizedBox(height: 10),
              Row(
                children: [
                  if (task.startTime != null) ...[
                    Icon(Icons.access_time_rounded, size: 13, color: scheme.onSurface.withOpacity(0.5)),
                    const SizedBox(width: 4),
                    Text(
                      '${DateFormat.Hm().format(task.startTime!)} – ${task.endTime != null ? DateFormat.Hm().format(task.endTime!) : '?'}',
                      style: textTheme.bodyMedium,
                    ),
                    const SizedBox(width: 12),
                  ],
                  if (showDate) ...[
                    Icon(Icons.calendar_today_rounded, size: 13, color: scheme.onSurface.withOpacity(0.5)),
                    const SizedBox(width: 4),
                    Text(DateFormat('MMM d').format(task.date), style: textTheme.bodyMedium),
                    const SizedBox(width: 12),
                  ],
                  if (task.mode == TaskMode.smart)
                    Icon(Icons.auto_awesome_rounded, size: 13, color: accent),
                  if (task.recurrence != null)
                    Padding(
                      padding: const EdgeInsets.only(left: 8),
                      child: Icon(Icons.repeat_rounded, size: 13, color: scheme.onSurface.withOpacity(0.5)),
                    ),
                ],
              ),
              const SizedBox(height: 12),
              _ActionButtons(task: task, accent: accent),
            ],
          ),
        ),
      ),
    );
  }
}

class _StatusBadge extends StatelessWidget {
  final Task task;
  final Color accent;
  const _StatusBadge({required this.task, required this.accent});

  @override
  Widget build(BuildContext context) {
    Color color;
    IconData icon;
    switch (task.status) {
      case TaskStatus.completed:
        color = Colors.green;
        icon = Icons.check_circle_rounded;
        break;
      case TaskStatus.inProgress:
        color = accent;
        icon = Icons.play_circle_rounded;
        break;
      case TaskStatus.pending:
        color = Colors.grey.shade400;
        icon = Icons.circle_outlined;
        break;
    }
    return Icon(icon, color: color, size: 22);
  }
}

class _ActionButtons extends ConsumerWidget {
  final Task task;
  final Color accent;
  const _ActionButtons({required this.task, required this.accent});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final notifier = ref.read(taskProvider.notifier);

    if (task.status == TaskStatus.completed) {
      return Row(
        children: [
          const Spacer(),
          _chip(
            label: 'Undo',
            icon: Icons.undo_rounded,
            color: Colors.grey,
            onTap: () => notifier.markPending(task.id),
          ),
        ],
      );
    }

    return Row(
      mainAxisAlignment: MainAxisAlignment.end,
      children: [
        if (task.status == TaskStatus.pending)
          _chip(
            label: 'Start',
            icon: Icons.play_arrow_rounded,
            color: accent,
            onTap: () => notifier.markInProgress(task.id),
          ),
        if (task.status == TaskStatus.inProgress) ...[
          _chip(
            label: 'Done',
            icon: Icons.check_rounded,
            color: Colors.green,
            onTap: () => notifier.markCompleted(task.id),
          ),
          const SizedBox(width: 8),
          _chip(
            label: 'Pause',
            icon: Icons.pause_rounded,
            color: Colors.orange,
            onTap: () => notifier.markPending(task.id),
          ),
        ],
      ],
    );
  }

  Widget _chip({
    required String label,
    required IconData icon,
    required Color color,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(20),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: color.withOpacity(0.12),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: color.withOpacity(0.3)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 14, color: color),
            const SizedBox(width: 4),
            Text(label, style: TextStyle(fontSize: 12, color: color, fontWeight: FontWeight.w600)),
          ],
        ),
      ),
    );
  }
}
