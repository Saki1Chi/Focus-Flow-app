import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../core/theme/app_theme.dart';
import '../../data/models/task_model.dart';
import '../providers/task_provider.dart';
import '../providers/settings_provider.dart';
import 'calendar/add_task_screen.dart';

class TaskDetailScreen extends ConsumerWidget {
  final String taskId;
  const TaskDetailScreen({super.key, required this.taskId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tasks = ref.watch(taskProvider);
    final task  = tasks.where((t) => t.id == taskId).firstOrNull;
    if (task == null) {
      return const Scaffold(body: Center(child: Text('Task not found')));
    }

    final accent   = ref.watch(settingsProvider).accentColor;
    final notifier = ref.read(taskProvider.notifier);
    final isDark   = Theme.of(context).brightness == Brightness.dark;

    final statusColor = _statusColor(task.status, accent);

    return Scaffold(
      backgroundColor:
          isDark ? const Color(0xFF06060F) : const Color(0xFFF3F4FF),
      body: Column(
        children: [
          // ── Gradient header ────────────────────────────────
          _GradientHeader(
            task: task,
            accent: accent,
            isDark: isDark,
            statusColor: statusColor,
            onEdit: () => Navigator.pushReplacement(
              context,
              MaterialPageRoute(builder: (_) => AddTaskScreen(editTask: task)),
            ),
            onDelete: () => _confirmDelete(context, notifier),
          ),

          // ── Body ───────────────────────────────────────────
          Expanded(
            child: SingleChildScrollView(
              physics: const BouncingScrollPhysics(),
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Description
                  if (task.description.isNotEmpty) ...[
                    Text(
                      task.description,
                      style: Theme.of(context).textTheme.bodyLarge,
                    ),
                    const SizedBox(height: 24),
                  ],

                  // Info rows
                  _InfoCard(
                    isDark: isDark,
                    children: [
                      _InfoRow(
                        icon: Icons.calendar_today_rounded,
                        label: DateFormat('EEEE, MMM d, yyyy').format(task.date),
                        accent: accent,
                      ),
                      if (task.startTime != null)
                        _InfoRow(
                          icon: Icons.access_time_rounded,
                          label:
                              '${DateFormat.Hm().format(task.startTime!)} – '
                              '${task.endTime != null ? DateFormat.Hm().format(task.endTime!) : 'no end time'}',
                          accent: accent,
                        ),
                      _InfoRow(
                        icon: task.mode == TaskMode.smart
                            ? Icons.auto_awesome_rounded
                            : Icons.calendar_month_rounded,
                        label: task.mode == TaskMode.smart
                            ? 'Smart Mode'
                            : 'Calendar Mode',
                        accent: accent,
                      ),
                      if (task.isCarriedOver)
                        _InfoRow(
                          icon: Icons.redo_rounded,
                          label: 'Carried over from a previous day',
                          accent: Colors.orange,
                        ),
                      if (task.recurrence != null)
                        _InfoRow(
                          icon: Icons.repeat_rounded,
                          label: 'Recurring task',
                          accent: accent,
                        ),
                    ],
                  ),

                  const SizedBox(height: 28),

                  // ── Action buttons ────────────────────────
                  if (task.status != TaskStatus.completed) ...[
                    if (task.status == TaskStatus.pending)
                      _ActionButton(
                        label: 'Mark as In Progress',
                        icon: Icons.play_arrow_rounded,
                        color: accent,
                        isDark: isDark,
                        onPressed: () => notifier.markInProgress(taskId),
                      ),
                    if (task.status == TaskStatus.inProgress) ...[
                      _ActionButton(
                        label: 'Mark as Completed',
                        icon: Icons.check_rounded,
                        color: const Color(0xFF22C55E),
                        isDark: isDark,
                        onPressed: () {
                          notifier.markCompleted(taskId);
                          Navigator.pop(context);
                        },
                      ),
                      const SizedBox(height: 10),
                      _ActionButton(
                        label: 'Pause Task',
                        icon: Icons.pause_rounded,
                        color: Colors.orange,
                        isDark: isDark,
                        outlined: true,
                        onPressed: () => notifier.markPending(taskId),
                      ),
                    ],
                  ] else ...[
                    _ActionButton(
                      label: 'Mark as Pending',
                      icon: Icons.undo_rounded,
                      color: accent,
                      isDark: isDark,
                      outlined: true,
                      onPressed: () => notifier.markPending(taskId),
                    ),
                  ],
                  const SizedBox(height: 40),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _confirmDelete(
      BuildContext context, TaskNotifier notifier) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Task'),
        content:
            const Text('Are you sure you want to delete this task?'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancel')),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Delete',
                style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
    if (!context.mounted) return;
    if (confirm == true) {
      await notifier.deleteTask(taskId);
      if (context.mounted) Navigator.pop(context);
    }
  }

  Color _statusColor(TaskStatus s, Color accent) {
    switch (s) {
      case TaskStatus.completed:  return const Color(0xFF22C55E);
      case TaskStatus.inProgress: return accent;
      case TaskStatus.pending:    return const Color(0xFF9898B8);
    }
  }
}

// ── Gradient header ─────────────────────────────────────────────

class _GradientHeader extends StatelessWidget {
  final Task task;
  final Color accent;
  final bool isDark;
  final Color statusColor;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  const _GradientHeader({
    required this.task,
    required this.accent,
    required this.isDark,
    required this.statusColor,
    required this.onEdit,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF0E0E1C) : Colors.white,
        border: Border(
          bottom: BorderSide(
            color: isDark
                ? Colors.white.withValues(alpha: 0.07)
                : Colors.black.withValues(alpha: 0.06),
            width: 1,
          ),
        ),
        boxShadow: isDark ? NeonColors.crystalCard() : NeonColors.lightCard(),
      ),
      child: SafeArea(
        bottom: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(8, 8, 8, 20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Nav row
              Row(
                children: [
                  IconButton(
                    icon: const Icon(Icons.arrow_back_rounded),
                    onPressed: () => Navigator.pop(context),
                  ),
                  const Spacer(),
                  IconButton(
                    icon: const Icon(Icons.edit_rounded),
                    onPressed: onEdit,
                  ),
                  IconButton(
                    icon: const Icon(Icons.delete_outline_rounded),
                    color: Colors.red.withValues(alpha: 0.8),
                    onPressed: onDelete,
                  ),
                ],
              ),

              // Status badge
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 10),
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 11, vertical: 5),
                  decoration: BoxDecoration(
                    color: statusColor.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                        color: statusColor.withValues(alpha: 0.28), width: 1),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        width: 6,
                        height: 6,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: statusColor,
                          boxShadow: [
                            BoxShadow(
                              color: statusColor.withValues(alpha: 0.6),
                              blurRadius: 6,
                            )
                          ],
                        ),
                      ),
                      const SizedBox(width: 6),
                      Text(
                        '${task.statusEmoji} ${task.status.name}',
                        style: TextStyle(
                            color: statusColor,
                            fontWeight: FontWeight.w700,
                            fontSize: 12),
                      ),
                    ],
                  ),
                ),
              ),

              // Title
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Text(
                  task.title,
                  style: Theme.of(context).textTheme.displaySmall,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ── Info card ───────────────────────────────────────────────────

class _InfoCard extends StatelessWidget {
  final bool isDark;
  final List<Widget> children;
  const _InfoCard({required this.isDark, required this.children});

  @override
  Widget build(BuildContext context) {
    final bg     = isDark ? const Color(0xFF0E0E1C) : Colors.white;
    final border = isDark
        ? Colors.white.withValues(alpha: 0.07)
        : Colors.black.withValues(alpha: 0.06);

    return Container(
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: border, width: 1),
        boxShadow: isDark ? NeonColors.crystalCard() : NeonColors.lightCard(),
      ),
      child: Column(
        children: children
            .asMap()
            .entries
            .map((e) => Column(
                  children: [
                    e.value,
                    if (e.key < children.length - 1)
                      Divider(
                        height: 1,
                        color: isDark
                            ? Colors.white.withValues(alpha: 0.05)
                            : Colors.black.withValues(alpha: 0.05),
                        indent: 50,
                        endIndent: 16,
                      ),
                  ],
                ))
            .toList(),
      ),
    );
  }
}

// ── Info row ────────────────────────────────────────────────────

class _InfoRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color accent;
  const _InfoRow(
      {required this.icon, required this.label, required this.accent});

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
        child: Row(
          children: [
            Container(
              width: 32,
              height: 32,
              decoration: BoxDecoration(
                color: accent.withValues(alpha: 0.10),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(icon, size: 16, color: accent),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(label, style: Theme.of(context).textTheme.bodyLarge),
            ),
          ],
        ),
      );
}

// ── Action button ───────────────────────────────────────────────

class _ActionButton extends StatelessWidget {
  final String label;
  final IconData icon;
  final Color color;
  final bool isDark;
  final bool outlined;
  final VoidCallback onPressed;

  const _ActionButton({
    required this.label,
    required this.icon,
    required this.color,
    required this.isDark,
    required this.onPressed,
    this.outlined = false,
  });

  @override
  Widget build(BuildContext context) {
    if (outlined) {
      return SizedBox(
        width: double.infinity,
        child: OutlinedButton.icon(
          icon: Icon(icon),
          label: Text(label),
          style: OutlinedButton.styleFrom(
            foregroundColor: color,
            side: BorderSide(color: color.withValues(alpha: 0.5), width: 1.5),
            padding: const EdgeInsets.symmetric(vertical: 15),
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14)),
          ),
          onPressed: onPressed,
        ),
      );
    }

    return SizedBox(
      width: double.infinity,
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(14),
          boxShadow: isDark ? NeonColors.glow(color, intensity: 0.7) : null,
        ),
        child: ElevatedButton.icon(
          icon: Icon(icon),
          label: Text(label),
          style: ElevatedButton.styleFrom(
            backgroundColor: color,
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(vertical: 15),
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14)),
          ),
          onPressed: onPressed,
        ),
      ),
    );
  }
}
