import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
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
    final task = tasks.where((t) => t.id == taskId).firstOrNull;
    if (task == null) {
      return const Scaffold(body: Center(child: Text('Task not found')));
    }

    final accent = ref.watch(settingsProvider).accentColor;
    final notifier = ref.read(taskProvider.notifier);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Task Detail'),
        actions: [
          IconButton(
            icon: const Icon(Icons.edit_rounded),
            onPressed: () => Navigator.pushReplacement(
              context,
              MaterialPageRoute(builder: (_) => AddTaskScreen(editTask: task)),
            ),
          ),
          IconButton(
            icon: const Icon(Icons.delete_outline_rounded),
            onPressed: () async {
              final confirm = await showDialog<bool>(
                context: context,
                builder: (ctx) => AlertDialog(
                  title: const Text('Delete Task'),
                  content: const Text('Are you sure you want to delete this task?'),
                  actions: [
                    TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
                    TextButton(
                      onPressed: () => Navigator.pop(ctx, true),
                      child: const Text('Delete', style: TextStyle(color: Colors.red)),
                    ),
                  ],
                ),
              );
              if (confirm == true && context.mounted) {
                await notifier.deleteTask(taskId);
                Navigator.pop(context);
              }
            },
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Status
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: _statusColor(task.status).withOpacity(0.12),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(
                '${task.statusEmoji} ${task.status.name}',
                style: TextStyle(color: _statusColor(task.status), fontWeight: FontWeight.w600),
              ),
            ),
            const SizedBox(height: 20),

            // Title
            Text(task.title, style: Theme.of(context).textTheme.displaySmall),
            const SizedBox(height: 12),

            // Description
            if (task.description.isNotEmpty) ...[
              Text(task.description, style: Theme.of(context).textTheme.bodyLarge),
              const SizedBox(height: 20),
            ],

            // Info chips
            _InfoRow(icon: Icons.calendar_today_rounded,
                label: DateFormat('EEEE, MMM d, yyyy').format(task.date)),
            if (task.startTime != null)
              _InfoRow(
                  icon: Icons.access_time_rounded,
                  label:
                      '${DateFormat.Hm().format(task.startTime!)} – ${task.endTime != null ? DateFormat.Hm().format(task.endTime!) : 'no end time'}'),
            _InfoRow(icon: Icons.category_rounded,
                label: task.mode == TaskMode.smart ? 'Smart Mode' : 'Calendar Mode'),
            if (task.isCarriedOver)
              _InfoRow(icon: Icons.redo_rounded, label: 'Carried over from a previous day'),
            if (task.recurrence != null)
              _InfoRow(icon: Icons.repeat_rounded, label: 'Recurring task'),

            const SizedBox(height: 30),

            // Action buttons
            if (task.status != TaskStatus.completed) ...[
              if (task.status == TaskStatus.pending)
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    icon: const Icon(Icons.play_arrow_rounded),
                    label: const Text('Mark as In Progress'),
                    style: ElevatedButton.styleFrom(backgroundColor: accent),
                    onPressed: () => notifier.markInProgress(taskId),
                  ),
                ),
              if (task.status == TaskStatus.inProgress) ...[
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    icon: const Icon(Icons.check_rounded),
                    label: const Text('Mark as Completed'),
                    style: ElevatedButton.styleFrom(backgroundColor: Colors.green),
                    onPressed: () {
                      notifier.markCompleted(taskId);
                      Navigator.pop(context);
                    },
                  ),
                ),
                const SizedBox(height: 10),
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    icon: const Icon(Icons.pause_rounded),
                    label: const Text('Pause'),
                    onPressed: () => notifier.markPending(taskId),
                  ),
                ),
              ],
            ] else ...[
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  icon: const Icon(Icons.undo_rounded),
                  label: const Text('Mark as Pending'),
                  onPressed: () => notifier.markPending(taskId),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Color _statusColor(TaskStatus s) {
    switch (s) {
      case TaskStatus.completed: return Colors.green;
      case TaskStatus.inProgress: return Colors.blue;
      case TaskStatus.pending: return Colors.grey;
    }
  }
}

class _InfoRow extends StatelessWidget {
  final IconData icon;
  final String label;
  const _InfoRow({required this.icon, required this.label});

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 10),
    child: Row(
      children: [
        Icon(icon, size: 18, color: Theme.of(context).colorScheme.primary),
        const SizedBox(width: 10),
        Expanded(child: Text(label, style: Theme.of(context).textTheme.bodyLarge)),
      ],
    ),
  );
}
