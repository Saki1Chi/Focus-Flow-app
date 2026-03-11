import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../../data/models/task_model.dart';
import '../../../data/models/recurrence_rule.dart';
import '../../providers/task_provider.dart';
import '../../providers/settings_provider.dart';

class AddTaskScreen extends ConsumerStatefulWidget {
  final Task? editTask;
  final DateTime? initialDate;

  const AddTaskScreen({super.key, this.editTask, this.initialDate});

  @override
  ConsumerState<AddTaskScreen> createState() => _AddTaskScreenState();
}

class _AddTaskScreenState extends ConsumerState<AddTaskScreen> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _titleCtrl;
  late final TextEditingController _descCtrl;

  late DateTime _selectedDate;
  TimeOfDay? _startTime;
  TimeOfDay? _endTime;
  bool _hasRecurrence = false;
  RepeatType _repeatType = RepeatType.daily;
  int _interval = 1;
  EndType _endType = EndType.never;
  int _occurrences = 5;
  DateTime? _recurrenceEndDate;
  final List<bool> _skipDays = List.filled(7, false); // Mon–Sun

  @override
  void initState() {
    super.initState();
    final task = widget.editTask;
    _titleCtrl = TextEditingController(text: task?.title ?? '');
    _descCtrl = TextEditingController(text: task?.description ?? '');
    _selectedDate = task?.date ?? widget.initialDate ?? DateTime.now();
    if (task?.startTime != null) {
      _startTime = TimeOfDay.fromDateTime(task!.startTime!);
    }
    if (task?.endTime != null) {
      _endTime = TimeOfDay.fromDateTime(task!.endTime!);
    }
    if (task?.recurrence != null) {
      _hasRecurrence = true;
      final r = task!.recurrence!;
      _repeatType = r.repeatType;
      _interval = r.interval;
      _endType = r.endType;
      _occurrences = r.occurrences ?? 5;
      _recurrenceEndDate = r.endDate;
      for (final d in r.skipDays) {
        if (d < 7) _skipDays[d] = true;
      }
    }
  }

  @override
  void dispose() {
    _titleCtrl.dispose();
    _descCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final accent = ref.watch(settingsProvider).accentColor;
    final isEditing = widget.editTask != null;

    return Scaffold(
      appBar: AppBar(title: Text(isEditing ? 'Edit Task' : 'New Task')),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            TextFormField(
              controller: _titleCtrl,
              decoration: const InputDecoration(labelText: 'Title', prefixIcon: Icon(Icons.title_rounded)),
              validator: (v) => v == null || v.trim().isEmpty ? 'Required' : null,
            ),
            const SizedBox(height: 14),
            TextFormField(
              controller: _descCtrl,
              decoration: const InputDecoration(labelText: 'Description (optional)', prefixIcon: Icon(Icons.notes_rounded)),
              maxLines: 3,
            ),
            const SizedBox(height: 14),

            // Date picker
            _SectionLabel(label: 'Date'),
            _Tile(
              icon: Icons.calendar_today_rounded,
              title: DateFormat('EEEE, MMM d, yyyy').format(_selectedDate),
              accent: accent,
              onTap: _pickDate,
            ),
            const SizedBox(height: 14),

            // Time pickers
            _SectionLabel(label: 'Time'),
            Row(children: [
              Expanded(child: _Tile(
                icon: Icons.play_circle_outline_rounded,
                title: _startTime != null ? _startTime!.format(context) : 'Start time',
                accent: accent,
                onTap: () => _pickTime(isStart: true),
              )),
              const SizedBox(width: 10),
              Expanded(child: _Tile(
                icon: Icons.stop_circle_outlined,
                title: _endTime != null ? _endTime!.format(context) : 'End time',
                accent: accent,
                onTap: () => _pickTime(isStart: false),
              )),
            ]),
            const SizedBox(height: 14),

            // Recurrence
            SwitchListTile(
              title: const Text('Repeat'),
              subtitle: const Text('Set recurring schedule'),
              value: _hasRecurrence,
              onChanged: (v) => setState(() => _hasRecurrence = v),
              activeColor: accent,
              contentPadding: EdgeInsets.zero,
            ),

            if (_hasRecurrence) _buildRecurrenceOptions(accent),

            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _save,
                child: Text(isEditing ? 'Save Changes' : 'Add Task'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRecurrenceOptions(Color accent) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      const SizedBox(height: 8),
      const _SectionLabel(label: 'Repeat type'),
      SegmentedButton<RepeatType>(
        segments: const [
          ButtonSegment(value: RepeatType.daily, label: Text('Daily')),
          ButtonSegment(value: RepeatType.weekly, label: Text('Weekly')),
          ButtonSegment(value: RepeatType.monthly, label: Text('Monthly')),
          ButtonSegment(value: RepeatType.yearly, label: Text('Yearly')),
        ],
        selected: {_repeatType},
        onSelectionChanged: (s) => setState(() => _repeatType = s.first),
        style: ButtonStyle(
          backgroundColor: WidgetStateProperty.resolveWith(
            (states) => states.contains(WidgetState.selected) ? accent : null,
          ),
        ),
      ),
      const SizedBox(height: 12),
      Row(children: [
        const Text('Every '),
        SizedBox(
          width: 60,
          child: TextFormField(
            initialValue: _interval.toString(),
            keyboardType: TextInputType.number,
            textAlign: TextAlign.center,
            onChanged: (v) => _interval = int.tryParse(v) ?? 1,
            decoration: const InputDecoration(contentPadding: EdgeInsets.symmetric(horizontal: 8, vertical: 8)),
          ),
        ),
        const SizedBox(width: 8),
        Text(_repeatType.name),
      ]),
      const SizedBox(height: 12),
      const _SectionLabel(label: 'Skip days'),
      Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: ['M', 'T', 'W', 'T', 'F', 'S', 'S'].asMap().entries.map((e) {
          return GestureDetector(
            onTap: () => setState(() => _skipDays[e.key] = !_skipDays[e.key]),
            child: CircleAvatar(
              radius: 16,
              backgroundColor: _skipDays[e.key] ? accent : accent.withOpacity(0.12),
              child: Text(e.value,
                  style: TextStyle(
                    fontSize: 12,
                    color: _skipDays[e.key] ? Colors.white : accent,
                    fontWeight: FontWeight.w600,
                  )),
            ),
          );
        }).toList(),
      ),
      const SizedBox(height: 12),
      const _SectionLabel(label: 'End recurrence'),
      DropdownButtonFormField<EndType>(
        value: _endType,
        decoration: const InputDecoration(),
        items: const [
          DropdownMenuItem(value: EndType.never, child: Text('Never')),
          DropdownMenuItem(value: EndType.afterOccurrences, child: Text('After N occurrences')),
          DropdownMenuItem(value: EndType.onDate, child: Text('On specific date')),
        ],
        onChanged: (v) => setState(() => _endType = v!),
      ),
      if (_endType == EndType.afterOccurrences)
        TextFormField(
          initialValue: _occurrences.toString(),
          decoration: const InputDecoration(labelText: 'Occurrences'),
          keyboardType: TextInputType.number,
          onChanged: (v) => _occurrences = int.tryParse(v) ?? 5,
        ),
      if (_endType == EndType.onDate)
        _Tile(
          icon: Icons.event_rounded,
          title: _recurrenceEndDate != null
              ? DateFormat('MMM d, yyyy').format(_recurrenceEndDate!)
              : 'Pick end date',
          accent: accent,
          onTap: _pickRecurrenceEndDate,
        ),
      const SizedBox(height: 8),
    ],
  );

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime.now().subtract(const Duration(days: 365)),
      lastDate: DateTime.now().add(const Duration(days: 730)),
    );
    if (picked != null) setState(() => _selectedDate = picked);
  }

  Future<void> _pickTime({required bool isStart}) async {
    final picked = await showTimePicker(
      context: context,
      initialTime: isStart
          ? (_startTime ?? const TimeOfDay(hour: 9, minute: 0))
          : (_endTime ?? const TimeOfDay(hour: 10, minute: 0)),
    );
    if (picked != null) {
      setState(() => isStart ? _startTime = picked : _endTime = picked);
    }
  }

  Future<void> _pickRecurrenceEndDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _recurrenceEndDate ?? DateTime.now().add(const Duration(days: 30)),
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 730)),
    );
    if (picked != null) setState(() => _recurrenceEndDate = picked);
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;

    final notifier = ref.read(taskProvider.notifier);

    DateTime? startDt;
    DateTime? endDt;
    if (_startTime != null) {
      startDt = DateTime(_selectedDate.year, _selectedDate.month, _selectedDate.day,
          _startTime!.hour, _startTime!.minute);
    }
    if (_endTime != null) {
      endDt = DateTime(_selectedDate.year, _selectedDate.month, _selectedDate.day,
          _endTime!.hour, _endTime!.minute);
    }

    RecurrenceRule? recurrence;
    if (_hasRecurrence) {
      recurrence = RecurrenceRule(
        repeatType: _repeatType,
        interval: _interval,
        skipDays: _skipDays.asMap().entries.where((e) => e.value).map((e) => e.key).toList(),
        endType: _endType,
        occurrences: _endType == EndType.afterOccurrences ? _occurrences : null,
        endDate: _endType == EndType.onDate ? _recurrenceEndDate : null,
      );
    }

    if (widget.editTask != null) {
      final updated = widget.editTask!.copyWith(
        title: _titleCtrl.text.trim(),
        description: _descCtrl.text.trim(),
        date: _selectedDate,
        startTime: startDt,
        endTime: endDt,
        recurrence: recurrence,
        isRecurringParent: _hasRecurrence,
      );
      await notifier.updateTask(updated);
    } else {
      await notifier.addTask(
        title: _titleCtrl.text.trim(),
        description: _descCtrl.text.trim(),
        date: _selectedDate,
        startTime: startDt,
        endTime: endDt,
        mode: TaskMode.calendar,
        recurrence: recurrence,
      );
    }

    if (mounted) Navigator.pop(context);
  }
}

class _SectionLabel extends StatelessWidget {
  final String label;
  const _SectionLabel({required this.label});

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 6),
    child: Text(label, style: Theme.of(context).textTheme.bodyMedium),
  );
}

class _Tile extends StatelessWidget {
  final IconData icon;
  final String title;
  final Color accent;
  final VoidCallback onTap;

  const _Tile({required this.icon, required this.title, required this.accent, required this.onTap});

  @override
  Widget build(BuildContext context) => GestureDetector(
    onTap: onTap,
    child: Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Theme.of(context).dividerColor),
      ),
      child: Row(children: [
        Icon(icon, size: 18, color: accent),
        const SizedBox(width: 8),
        Expanded(child: Text(title, style: const TextStyle(fontSize: 14))),
      ]),
    ),
  );
}
