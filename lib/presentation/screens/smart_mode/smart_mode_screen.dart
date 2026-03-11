import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../../data/models/task_model.dart';
import '../../providers/task_provider.dart';
import '../../providers/settings_provider.dart';
import '../../widgets/task_card.dart';
import '../task_detail_screen.dart';

class SmartModeScreen extends ConsumerStatefulWidget {
  const SmartModeScreen({super.key});

  @override
  ConsumerState<SmartModeScreen> createState() => _SmartModeScreenState();
}

class _SmartModeScreenState extends ConsumerState<SmartModeScreen> {
  final List<({TextEditingController title, TextEditingController desc})> _inputs = [];
  DateTime _scheduleDate = DateTime.now();
  bool _loading = false;
  List<Task>? _scheduledPreview;

  @override
  void initState() {
    super.initState();
    _addInput();
  }

  void _addInput() {
    setState(() => _inputs.add((
      title: TextEditingController(),
      desc: TextEditingController(),
    )));
  }

  void _removeInput(int i) {
    _inputs[i].title.dispose();
    _inputs[i].desc.dispose();
    setState(() => _inputs.removeAt(i));
  }

  @override
  void dispose() {
    for (final input in _inputs) {
      input.title.dispose();
      input.desc.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final accent = ref.watch(settingsProvider).accentColor;

    return Scaffold(
      appBar: AppBar(
        title: Row(
          children: [
            Icon(Icons.auto_awesome_rounded, color: accent, size: 20),
            const SizedBox(width: 8),
            const Text('Smart Scheduler'),
          ],
        ),
      ),
      body: _scheduledPreview != null
          ? _buildPreview(accent)
          : _buildForm(accent),
    );
  }

  Widget _buildForm(Color accent) {
    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        // Explanation card
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: accent.withOpacity(0.08),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: accent.withOpacity(0.2)),
          ),
          child: Row(
            children: [
              Icon(Icons.lightbulb_rounded, color: accent),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  'Just enter your tasks — FocusFlow will auto-schedule them throughout the day.',
                  style: TextStyle(fontSize: 13, color: accent),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 20),

        // Date picker
        GestureDetector(
          onTap: _pickDate,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            decoration: BoxDecoration(
              color: Theme.of(context).cardColor,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Theme.of(context).dividerColor),
            ),
            child: Row(
              children: [
                Icon(Icons.calendar_today_rounded, color: accent, size: 18),
                const SizedBox(width: 10),
                Text('Schedule for: ${DateFormat('EEEE, MMM d').format(_scheduleDate)}',
                    style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500)),
              ],
            ),
          ),
        ),
        const SizedBox(height: 20),

        Text('Tasks to schedule', style: Theme.of(context).textTheme.titleLarge),
        const SizedBox(height: 12),

        // Task inputs
        ...List.generate(_inputs.length, (i) => _buildTaskInput(i, accent)),

        // Add another
        TextButton.icon(
          icon: Icon(Icons.add_rounded, color: accent),
          label: Text('Add another task', style: TextStyle(color: accent)),
          onPressed: _addInput,
        ),
        const SizedBox(height: 20),

        // Schedule button
        SizedBox(
          width: double.infinity,
          child: ElevatedButton.icon(
            icon: _loading
                ? const SizedBox(
                    width: 16, height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                : const Icon(Icons.auto_awesome_rounded),
            label: const Text('Auto-Schedule'),
            onPressed: _loading ? null : _schedule,
          ),
        ),
      ],
    );
  }

  Widget _buildTaskInput(int i, Color accent) => Container(
    margin: const EdgeInsets.only(bottom: 12),
    padding: const EdgeInsets.all(14),
    decoration: BoxDecoration(
      color: Theme.of(context).cardColor,
      borderRadius: BorderRadius.circular(14),
      border: Border.all(color: Theme.of(context).dividerColor),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            CircleAvatar(
              radius: 12,
              backgroundColor: accent.withOpacity(0.15),
              child: Text('${i + 1}', style: TextStyle(fontSize: 11, color: accent, fontWeight: FontWeight.w700)),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: TextField(
                controller: _inputs[i].title,
                decoration: const InputDecoration(
                  hintText: 'Task title',
                  border: InputBorder.none,
                  isDense: true,
                  contentPadding: EdgeInsets.zero,
                ),
                style: const TextStyle(fontWeight: FontWeight.w600),
              ),
            ),
            if (_inputs.length > 1)
              IconButton(
                icon: const Icon(Icons.close_rounded, size: 18),
                onPressed: () => _removeInput(i),
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
                color: Colors.grey,
              ),
          ],
        ),
        const SizedBox(height: 6),
        TextField(
          controller: _inputs[i].desc,
          decoration: const InputDecoration(
            hintText: 'Short description (optional)',
            border: InputBorder.none,
            isDense: true,
            contentPadding: EdgeInsets.zero,
          ),
          style: const TextStyle(fontSize: 13, color: Colors.grey),
        ),
      ],
    ),
  );

  Widget _buildPreview(Color accent) {
    return Column(
      children: [
        Container(
          margin: const EdgeInsets.all(16),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.green.withOpacity(0.08),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: Colors.green.withOpacity(0.3)),
          ),
          child: Row(
            children: [
              const Icon(Icons.check_circle_rounded, color: Colors.green),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  '${_scheduledPreview!.length} tasks scheduled for ${DateFormat('MMM d').format(_scheduleDate)}',
                  style: const TextStyle(color: Colors.green, fontWeight: FontWeight.w600),
                ),
              ),
            ],
          ),
        ),
        Expanded(
          child: ListView.builder(
            padding: const EdgeInsets.only(bottom: 100),
            itemCount: _scheduledPreview!.length,
            itemBuilder: (ctx, i) {
              final task = _scheduledPreview![i];
              return TaskCard(
                task: task,
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => TaskDetailScreen(taskId: task.id)),
                ),
              );
            },
          ),
        ),
        Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: () => setState(() => _scheduledPreview = null),
                  child: const Text('Schedule More'),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _scheduleDate,
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );
    if (picked != null) setState(() => _scheduleDate = picked);
  }

  Future<void> _schedule() async {
    final validInputs = _inputs
        .where((i) => i.title.text.trim().isNotEmpty)
        .map((i) => (title: i.title.text.trim(), description: i.desc.text.trim()))
        .toList();

    if (validInputs.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter at least one task title')),
      );
      return;
    }

    setState(() => _loading = true);

    try {
      final scheduled = await ref.read(taskProvider.notifier).smartSchedule(
        inputs: validInputs,
        date: _scheduleDate,
      );
      setState(() {
        _scheduledPreview = scheduled;
        _loading = false;
      });
    } catch (e) {
      setState(() => _loading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error scheduling tasks: $e')),
        );
      }
    }
  }
}
