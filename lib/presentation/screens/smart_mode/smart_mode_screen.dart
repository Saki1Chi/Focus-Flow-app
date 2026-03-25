import 'package:animate_do/animate_do.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../../core/theme/app_theme.dart';
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
  final List<({TextEditingController title, TextEditingController desc})>
      _inputs = [];
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
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(
        title: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 28,
              height: 28,
              decoration: BoxDecoration(
                color: accent.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(Icons.auto_awesome_rounded, color: accent, size: 15),
            ),
            const SizedBox(width: 10),
            const Text('Smart Scheduler'),
          ],
        ),
      ),
      body: _scheduledPreview != null
          ? _buildPreview(accent, isDark)
          : _buildForm(accent, isDark),
    );
  }

  Widget _buildForm(Color accent, bool isDark) {
    final cardBg = isDark ? const Color(0xFF0E0E1C) : Colors.white;
    final border = isDark
        ? Colors.white.withValues(alpha: 0.07)
        : Colors.black.withValues(alpha: 0.06);

    return ListView(
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.all(20),
      children: [
        // ── Tip card ────────────────────────────────────
        FadeInDown(
          duration: const Duration(milliseconds: 380),
          child: Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  accent.withValues(alpha: 0.10),
                  accent.withValues(alpha: 0.04),
                ],
              ),
              borderRadius: BorderRadius.circular(16),
              border:
                  Border.all(color: accent.withValues(alpha: 0.20), width: 1),
              boxShadow: isDark ? NeonColors.softGlow(accent) : null,
            ),
            child: Row(
              children: [
                Container(
                  width: 32,
                  height: 32,
                  decoration: BoxDecoration(
                    color: accent.withValues(alpha: 0.14),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(Icons.lightbulb_rounded, color: accent, size: 16),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'Enter your tasks — FocusFlow auto-schedules them throughout the day.',
                    style: TextStyle(
                        fontSize: 13,
                        color: accent,
                        fontWeight: FontWeight.w500),
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 14),

        // ── Date picker ─────────────────────────────────
        FadeInDown(
          duration: const Duration(milliseconds: 400),
          delay: const Duration(milliseconds: 60),
          child: GestureDetector(
            onTap: _pickDate,
            child: Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              decoration: BoxDecoration(
                color: cardBg,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: border, width: 1),
                boxShadow: isDark ? NeonColors.crystalCard() : NeonColors.lightCard(),
              ),
              child: Row(
                children: [
                  Container(
                    width: 32,
                    height: 32,
                    decoration: BoxDecoration(
                      color: accent.withValues(alpha: 0.10),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Icon(Icons.calendar_today_rounded,
                        color: accent, size: 15),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Schedule for',
                            style: Theme.of(context).textTheme.bodyMedium),
                        const SizedBox(height: 1),
                        Text(
                          DateFormat('EEEE, MMM d').format(_scheduleDate),
                          style: Theme.of(context)
                              .textTheme
                              .titleMedium
                              ?.copyWith(fontWeight: FontWeight.w600),
                        ),
                      ],
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
          ),
        ),
        const SizedBox(height: 20),

        // ── Tasks header ────────────────────────────────
        FadeInDown(
          duration: const Duration(milliseconds: 420),
          delay: const Duration(milliseconds: 80),
          child: Row(
            children: [
              Text('Tasks to schedule',
                  style: Theme.of(context).textTheme.titleLarge),
              const Spacer(),
              Text(
                '${_inputs.length}',
                style: TextStyle(
                    color: accent, fontWeight: FontWeight.w700, fontSize: 13),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),

        // ── Task inputs ─────────────────────────────────
        ...List.generate(
          _inputs.length,
          (i) => FadeInUp(
            duration: const Duration(milliseconds: 300),
            delay: Duration(milliseconds: 40 * i),
            child: _buildTaskInput(i, accent, isDark, cardBg, border),
          ),
        ),

        // ── Add another ─────────────────────────────────
        GestureDetector(
          onTap: _addInput,
          child: Container(
            margin: const EdgeInsets.only(bottom: 14),
            padding: const EdgeInsets.symmetric(vertical: 13),
            decoration: BoxDecoration(
              color: accent.withValues(alpha: 0.06),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                  color: accent.withValues(alpha: 0.18), width: 1),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.add_rounded, color: accent, size: 18),
                const SizedBox(width: 6),
                Text(
                  'Add another task',
                  style: TextStyle(
                      color: accent,
                      fontSize: 13,
                      fontWeight: FontWeight.w700),
                ),
              ],
            ),
          ),
        ),

        // ── Schedule button ─────────────────────────────
        Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            boxShadow: isDark ? NeonColors.glow(accent, intensity: 0.75) : null,
          ),
          child: SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              icon: _loading
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: Colors.white))
                  : const Icon(Icons.auto_awesome_rounded, size: 17),
              label: const Text('Auto-Schedule'),
              onPressed: _loading ? null : _schedule,
            ),
          ),
        ),
        const SizedBox(height: 100),
      ],
    );
  }

  Widget _buildTaskInput(
      int i, Color accent, bool isDark, Color cardBg, Color border) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: border, width: 1),
        boxShadow: isDark ? NeonColors.crystalCard() : NeonColors.lightCard(),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Number strip
              Container(
                width: 42,
                color: accent.withValues(alpha: 0.06),
                child: Center(
                  child: Text(
                    '${i + 1}',
                    style: TextStyle(
                      fontSize: 13,
                      color: accent,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
              ),
              // Content
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(12, 12, 10, 12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: TextField(
                              controller: _inputs[i].title,
                              decoration: const InputDecoration(
                                hintText: 'Task title',
                                border: InputBorder.none,
                                isDense: true,
                                contentPadding: EdgeInsets.zero,
                              ),
                              style: const TextStyle(
                                  fontWeight: FontWeight.w600, fontSize: 15),
                            ),
                          ),
                          if (_inputs.length > 1)
                            GestureDetector(
                              onTap: () => _removeInput(i),
                              child: Icon(
                                Icons.close_rounded,
                                size: 16,
                                color: isDark
                                    ? Colors.white.withValues(alpha: 0.28)
                                    : Colors.black.withValues(alpha: 0.28),
                              ),
                            ),
                        ],
                      ),
                      const SizedBox(height: 5),
                      TextField(
                        controller: _inputs[i].desc,
                        decoration: const InputDecoration(
                          hintText: 'Short description (optional)',
                          border: InputBorder.none,
                          isDense: true,
                          contentPadding: EdgeInsets.zero,
                        ),
                        style: const TextStyle(fontSize: 13),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPreview(Color accent, bool isDark) {
    return Column(
      children: [
        FadeInDown(
          duration: const Duration(milliseconds: 380),
          child: Container(
            margin: const EdgeInsets.all(16),
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  const Color(0xFF22C55E).withValues(alpha: 0.10),
                  const Color(0xFF22C55E).withValues(alpha: 0.04),
                ],
              ),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                  color: const Color(0xFF22C55E).withValues(alpha: 0.25),
                  width: 1),
              boxShadow: isDark
                  ? NeonColors.softGlow(const Color(0xFF22C55E))
                  : null,
            ),
            child: Row(
              children: [
                Container(
                  width: 32,
                  height: 32,
                  decoration: BoxDecoration(
                    color: const Color(0xFF22C55E).withValues(alpha: 0.14),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(Icons.check_circle_rounded,
                      color: Color(0xFF22C55E), size: 17),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    '${_scheduledPreview!.length} tasks scheduled for ${DateFormat('MMM d').format(_scheduleDate)}',
                    style: const TextStyle(
                        color: Color(0xFF22C55E),
                        fontWeight: FontWeight.w700,
                        fontSize: 14),
                  ),
                ),
              ],
            ),
          ),
        ),
        Expanded(
          child: ListView.builder(
            physics: const BouncingScrollPhysics(),
            padding: const EdgeInsets.only(bottom: 120),
            itemCount: _scheduledPreview!.length,
            itemBuilder: (ctx, i) {
              final task = _scheduledPreview![i];
              return FadeInUp(
                duration: const Duration(milliseconds: 300),
                delay: Duration(milliseconds: 50 * i),
                child: TaskCard(
                  task: task,
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                        builder: (_) => TaskDetailScreen(taskId: task.id)),
                  ),
                ),
              );
            },
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
          child: SizedBox(
            width: double.infinity,
            child: OutlinedButton(
              onPressed: () => setState(() => _scheduledPreview = null),
              style: OutlinedButton.styleFrom(
                foregroundColor: accent,
                side: BorderSide(
                    color: accent.withValues(alpha: 0.45), width: 1.5),
                padding: const EdgeInsets.symmetric(vertical: 15),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14)),
              ),
              child: Text('Schedule More',
                  style: TextStyle(
                      color: accent, fontWeight: FontWeight.w700)),
            ),
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
        .map((i) =>
            (title: i.title.text.trim(), description: i.desc.text.trim()))
        .toList();

    if (validInputs.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text('Please enter at least one task title')),
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
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Error: $e')));
      }
    }
  }
}
