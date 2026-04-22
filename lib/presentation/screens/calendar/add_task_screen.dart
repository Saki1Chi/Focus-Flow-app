import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../../core/theme/app_theme.dart';
import '../../../data/models/task_model.dart';
import '../../../data/models/recurrence_rule.dart';
import '../../providers/task_provider.dart';
import '../../providers/settings_provider.dart';
import '../../providers/category_provider.dart';

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
  int? _selectedCategoryId;
  bool _hasRecurrence = false;
  RepeatType _repeatType = RepeatType.daily;
  int _interval = 1;
  EndType _endType = EndType.never;
  int _occurrences = 5;
  DateTime? _recurrenceEndDate;
  final List<bool> _skipDays = List.filled(7, false);

  @override
  void initState() {
    super.initState();
    final task = widget.editTask;
    _titleCtrl  = TextEditingController(text: task?.title ?? '');
    _descCtrl   = TextEditingController(text: task?.description ?? '');
    _selectedDate = task?.date ?? widget.initialDate ?? DateTime.now();
    if (task?.startTime != null) _startTime = TimeOfDay.fromDateTime(task!.startTime!);
    if (task?.endTime   != null) _endTime   = TimeOfDay.fromDateTime(task!.endTime!);
    _selectedCategoryId = task?.categoryId;
    if (task?.recurrence != null) {
      _hasRecurrence = true;
      final r = task!.recurrence!;
      _repeatType = r.repeatType;
      _interval   = r.interval;
      _endType    = r.endType;
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
    final accent    = ref.watch(settingsProvider).accentColor;
    final isDark    = Theme.of(context).brightness == Brightness.dark;
    final isEditing = widget.editTask != null;

    return Scaffold(
      appBar: AppBar(
        title: Text(isEditing ? 'Edit Task' : 'New Task'),
        leading: IconButton(
          icon: const Icon(Icons.close_rounded),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          physics: const BouncingScrollPhysics(),
          padding: const EdgeInsets.all(20),
          children: [
            // Title field
            TextFormField(
              controller: _titleCtrl,
              autofocus: !isEditing,
              decoration: InputDecoration(
                labelText: 'Task title',
                prefixIcon: Icon(Icons.title_rounded, color: accent),
              ),
              style: Theme.of(context).textTheme.titleMedium,
              validator: (v) =>
                  v == null || v.trim().isEmpty ? 'Required' : null,
            ),
            const SizedBox(height: 12),

            // Description field
            TextFormField(
              controller: _descCtrl,
              decoration: InputDecoration(
                labelText: 'Description (optional)',
                prefixIcon: Icon(Icons.notes_rounded, color: accent),
                alignLabelWithHint: true,
              ),
              maxLines: 3,
            ),
            const SizedBox(height: 20),

            // Date
            _SectionLabel(label: 'Date', accent: accent),
            const SizedBox(height: 8),
            _PickerTile(
              icon: Icons.calendar_today_rounded,
              title: DateFormat('EEEE, MMM d, yyyy').format(_selectedDate),
              accent: accent,
              isDark: isDark,
              onTap: _pickDate,
            ),
            const SizedBox(height: 16),

            // Time
            _SectionLabel(label: 'Time', accent: accent),
            const SizedBox(height: 8),
            Row(children: [
              Expanded(
                child: _PickerTile(
                  icon: Icons.play_circle_outline_rounded,
                  title: _startTime != null
                      ? _startTime!.format(context)
                      : 'Start time',
                  accent: accent,
                  isDark: isDark,
                  onTap: () => _pickTime(isStart: true),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _PickerTile(
                  icon: Icons.stop_circle_outlined,
                  title: _endTime != null
                      ? _endTime!.format(context)
                      : 'End time',
                  accent: accent,
                  isDark: isDark,
                  onTap: () => _pickTime(isStart: false),
                ),
              ),
            ]),
            const SizedBox(height: 16),

            // Category
            _buildCategoryRow(accent, isDark),
            const SizedBox(height: 16),

            // Recurrence toggle
            _RecurrenceToggle(
              value: _hasRecurrence,
              accent: accent,
              isDark: isDark,
              onChanged: (v) => setState(() => _hasRecurrence = v),
            ),

            if (_hasRecurrence) ...[
              const SizedBox(height: 4),
              _buildRecurrenceOptions(accent, isDark),
            ],

            const SizedBox(height: 28),

            // Save button
            Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(14),
                boxShadow: isDark
                    ? NeonColors.glow(accent, intensity: 0.7)
                    : null,
              ),
              child: SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _save,
                  child: Text(isEditing ? 'Save Changes' : 'Add Task'),
                ),
              ),
            ),
            const SizedBox(height: 40),
          ],
        ),
      ),
    );
  }

  Widget _buildCategoryRow(Color accent, bool isDark) {
    final catState = ref.watch(categoryProvider);
    if (catState.isLoading) {
      return const SizedBox(height: 36, child: Center(child: LinearProgressIndicator()));
    }
    if (catState.categories.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _SectionLabel(label: 'Category', accent: accent),
        const SizedBox(height: 8),
        SizedBox(
          height: 36,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            itemCount: catState.categories.length + 1, // +1 for "None"
            separatorBuilder: (_, __) => const SizedBox(width: 8),
            itemBuilder: (context, i) {
              if (i == 0) {
                // "None" chip
                final selected = _selectedCategoryId == null;
                return ChoiceChip(
                  label: const Text('None'),
                  selected: selected,
                  onSelected: (_) => setState(() => _selectedCategoryId = null),
                  selectedColor: accent.withValues(alpha: 0.2),
                  side: BorderSide(
                    color: selected ? accent : Colors.transparent,
                    width: 1.5,
                  ),
                );
              }
              final cat = catState.categories[i - 1];
              final selected = _selectedCategoryId == cat.id;
              return ChoiceChip(
                avatar: CircleAvatar(
                  backgroundColor: cat.colorValue,
                  radius: 8,
                ),
                label: Text(cat.name),
                selected: selected,
                onSelected: (_) =>
                    setState(() => _selectedCategoryId = selected ? null : cat.id),
                selectedColor: cat.colorValue.withValues(alpha: 0.18),
                side: BorderSide(
                  color: selected ? cat.colorValue : Colors.transparent,
                  width: 1.5,
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildRecurrenceOptions(Color accent, bool isDark) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 12),
          _SectionLabel(label: 'Repeat type', accent: accent),
          const SizedBox(height: 8),
          SegmentedButton<RepeatType>(
            segments: const [
              ButtonSegment(value: RepeatType.daily, label: Text('Daily')),
              ButtonSegment(value: RepeatType.weekly, label: Text('Weekly')),
              ButtonSegment(value: RepeatType.monthly, label: Text('Monthly')),
              ButtonSegment(value: RepeatType.yearly, label: Text('Yearly')),
            ],
            selected: {_repeatType},
            onSelectionChanged: (s) =>
                setState(() => _repeatType = s.first),
            style: ButtonStyle(
              backgroundColor: WidgetStateProperty.resolveWith(
                (states) =>
                    states.contains(WidgetState.selected) ? accent : null,
              ),
            ),
          ),
          const SizedBox(height: 14),
          Row(children: [
            Text('Every ',
                style: Theme.of(context).textTheme.bodyLarge),
            SizedBox(
              width: 60,
              child: TextFormField(
                initialValue: _interval.toString(),
                keyboardType: TextInputType.number,
                textAlign: TextAlign.center,
                onChanged: (v) => _interval = int.tryParse(v) ?? 1,
                decoration: const InputDecoration(
                    contentPadding:
                        EdgeInsets.symmetric(horizontal: 8, vertical: 8)),
              ),
            ),
            const SizedBox(width: 8),
            Text(_repeatType.name,
                style: Theme.of(context).textTheme.bodyLarge),
          ]),
          const SizedBox(height: 14),
          _SectionLabel(label: 'Skip days', accent: accent),
          const SizedBox(height: 10),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children:
                ['M', 'T', 'W', 'T', 'F', 'S', 'S'].asMap().entries.map((e) {
              final active = _skipDays[e.key];
              return GestureDetector(
                onTap: () => setState(() => _skipDays[e.key] = !_skipDays[e.key]),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  width: 38,
                  height: 38,
                  decoration: BoxDecoration(
                    color:
                        active ? accent : accent.withValues(alpha: 0.10),
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: active
                          ? accent
                          : accent.withValues(alpha: 0.20),
                      width: 1.5,
                    ),
                    boxShadow: active
                        ? NeonColors.softGlow(accent)
                        : null,
                  ),
                  child: Center(
                    child: Text(
                      e.value,
                      style: TextStyle(
                        fontSize: 12,
                        color: active ? Colors.white : accent,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ),
              );
            }).toList(),
          ),
          const SizedBox(height: 14),
          _SectionLabel(label: 'End recurrence', accent: accent),
          const SizedBox(height: 8),
          DropdownButtonFormField<EndType>(
            value: _endType,
            decoration: const InputDecoration(),
            items: const [
              DropdownMenuItem(value: EndType.never, child: Text('Never')),
              DropdownMenuItem(
                  value: EndType.afterOccurrences,
                  child: Text('After N occurrences')),
              DropdownMenuItem(
                  value: EndType.onDate,
                  child: Text('On specific date')),
            ],
            onChanged: (v) => setState(() => _endType = v!),
          ),
          if (_endType == EndType.afterOccurrences) ...[
            const SizedBox(height: 10),
            TextFormField(
              initialValue: _occurrences.toString(),
              decoration: const InputDecoration(labelText: 'Occurrences'),
              keyboardType: TextInputType.number,
              onChanged: (v) => _occurrences = int.tryParse(v) ?? 5,
            ),
          ],
          if (_endType == EndType.onDate) ...[
            const SizedBox(height: 10),
            _PickerTile(
              icon: Icons.event_rounded,
              title: _recurrenceEndDate != null
                  ? DateFormat('MMM d, yyyy').format(_recurrenceEndDate!)
                  : 'Pick end date',
              accent: accent,
              isDark: isDark,
              onTap: _pickRecurrenceEndDate,
            ),
          ],
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
      initialDate:
          _recurrenceEndDate ?? DateTime.now().add(const Duration(days: 30)),
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
      startDt = DateTime(_selectedDate.year, _selectedDate.month,
          _selectedDate.day, _startTime!.hour, _startTime!.minute);
    }
    if (_endTime != null) {
      endDt = DateTime(_selectedDate.year, _selectedDate.month,
          _selectedDate.day, _endTime!.hour, _endTime!.minute);
    }

    RecurrenceRule? recurrence;
    if (_hasRecurrence) {
      recurrence = RecurrenceRule(
        repeatType: _repeatType,
        interval: _interval,
        skipDays: _skipDays
            .asMap()
            .entries
            .where((e) => e.value)
            .map((e) => e.key)
            .toList(),
        endType: _endType,
        occurrences:
            _endType == EndType.afterOccurrences ? _occurrences : null,
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
        categoryId: _selectedCategoryId,
        clearCategory: _selectedCategoryId == null,
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
        isRecurringParent: _hasRecurrence,
        categoryId: _selectedCategoryId,
      );
    }

    if (mounted) Navigator.pop(context);
  }
}

// ── Section label ───────────────────────────────────────────────

class _SectionLabel extends StatelessWidget {
  final String label;
  final Color accent;
  const _SectionLabel({required this.label, required this.accent});

  @override
  Widget build(BuildContext context) => Row(
        children: [
          Container(
            width: 3,
            height: 12,
            decoration: BoxDecoration(
              color: accent,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(width: 8),
          Text(
            label,
            style: Theme.of(context).textTheme.labelSmall?.copyWith(
                  color: accent,
                  letterSpacing: 0.6,
                ),
          ),
        ],
      );
}

// ── Picker tile ─────────────────────────────────────────────────

class _PickerTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final Color accent;
  final bool isDark;
  final VoidCallback onTap;

  const _PickerTile({
    required this.icon,
    required this.title,
    required this.accent,
    required this.isDark,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final bg     = isDark ? const Color(0xFF0C0C1A) : Colors.white;
    final border = isDark
        ? Colors.white.withValues(alpha: 0.08)
        : Colors.black.withValues(alpha: 0.08);

    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: border, width: 1),
          boxShadow: isDark ? NeonColors.crystalCard() : NeonColors.lightCard(),
        ),
        child: Row(
          children: [
            Icon(icon, size: 17, color: accent),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                title,
                style: Theme.of(context)
                    .textTheme
                    .titleMedium
                    ?.copyWith(fontSize: 13),
              ),
            ),
            Icon(
              Icons.chevron_right_rounded,
              size: 16,
              color: isDark
                  ? Colors.white.withValues(alpha: 0.25)
                  : Colors.black.withValues(alpha: 0.25),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Recurrence toggle tile ──────────────────────────────────────

class _RecurrenceToggle extends StatelessWidget {
  final bool value;
  final Color accent;
  final bool isDark;
  final ValueChanged<bool> onChanged;

  const _RecurrenceToggle({
    required this.value,
    required this.accent,
    required this.isDark,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final bg     = isDark ? const Color(0xFF0C0C1A) : Colors.white;
    final border = isDark
        ? Colors.white.withValues(alpha: 0.08)
        : Colors.black.withValues(alpha: 0.08);

    return Container(
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: border, width: 1),
        boxShadow: isDark ? NeonColors.crystalCard() : NeonColors.lightCard(),
      ),
      child: SwitchListTile(
        title: Text('Repeat', style: Theme.of(context).textTheme.titleMedium),
        subtitle: Text('Set a recurring schedule',
            style: Theme.of(context).textTheme.bodyMedium),
        secondary: Icon(Icons.repeat_rounded, color: accent, size: 20),
        value: value,
        onChanged: onChanged,
        activeColor: accent,
        contentPadding: const EdgeInsets.fromLTRB(14, 0, 14, 0),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      ),
    );
  }
}
