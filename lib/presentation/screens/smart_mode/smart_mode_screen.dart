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
    final tokens = Theme.of(context).extension<MinimalTheme>();
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
      // AnimatedSwitcher para la transición form ↔ preview
      body: AnimatedSwitcher(
        duration: const Duration(milliseconds: 380),
        switchInCurve: Curves.easeOutCubic,
        switchOutCurve: Curves.easeInCubic,
        transitionBuilder: (child, anim) => FadeTransition(
          opacity: anim,
          child: SlideTransition(
            position: Tween<Offset>(
              begin: const Offset(0, 0.04),
              end: Offset.zero,
            ).animate(anim),
            child: child,
          ),
        ),
        child: _scheduledPreview != null
            ? _buildPreview(accent, isDark, key: const ValueKey('preview'))
            : _buildForm(accent, isDark, key: const ValueKey('form')),
      ),
    );
  }

  Widget _buildForm(Color accent, bool isDark, {Key? key}) {
    final tokens = Theme.of(context).extension<MinimalTheme>();
    final cardBg = tokens?.surface ?? (isDark ? const Color(0xFF0E0E1C) : Colors.white);
    final border = tokens?.border ??
        (isDark ? Colors.white.withValues(alpha: 0.07) : Colors.black.withValues(alpha: 0.06));

    return ListView(
      key: key,
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
          child: _AnimatedTapContainer(
            onTap: _pickDate,
            child: Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              decoration: BoxDecoration(
                color: cardBg,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: border, width: 1),
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
              AnimatedSwitcher(
                duration: const Duration(milliseconds: 250),
                child: Text(
                  key: ValueKey(_inputs.length),
                  '${_inputs.length}',
                  style: TextStyle(
                      color: accent,
                      fontWeight: FontWeight.w700,
                      fontSize: 13),
                ),
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
        _AnimatedTapContainer(
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

        // ── Schedule button con glow pulsante ───────────
        _PulsingScheduleButton(
          accent: accent,
          isDark: isDark,
          loading: _loading,
          onPressed: _loading ? null : _schedule,
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

  Widget _buildPreview(Color accent, bool isDark, {Key? key}) {
    return Column(
      key: key,
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
          child: _AnimatedTapContainer(
            onTap: () => setState(() => _scheduledPreview = null),
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 15),
              decoration: BoxDecoration(
                color: Colors.transparent,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(
                    color: accent.withValues(alpha: 0.45), width: 1.5),
              ),
              child: Center(
                child: Text(
                  'Schedule More',
                  style: TextStyle(
                      color: accent, fontWeight: FontWeight.w700, fontSize: 15),
                ),
              ),
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

// ── Botón Auto-Schedule con glow pulsante ──────────────────────

class _PulsingScheduleButton extends StatefulWidget {
  final Color accent;
  final bool isDark;
  final bool loading;
  final VoidCallback? onPressed;

  const _PulsingScheduleButton({
    required this.accent,
    required this.isDark,
    required this.loading,
    required this.onPressed,
  });

  @override
  State<_PulsingScheduleButton> createState() => _PulsingScheduleButtonState();
}

class _PulsingScheduleButtonState extends State<_PulsingScheduleButton>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  late final Animation<double> _glow;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1800),
    )..repeat(reverse: true);
    _glow = Tween<double>(begin: 0.5, end: 1.0).animate(
      CurvedAnimation(parent: _ctrl, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _glow,
      builder: (_, child) => Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(14),
          boxShadow: widget.isDark && !widget.loading
              ? [
                  BoxShadow(
                    color: widget.accent.withValues(
                        alpha: 0.45 * _glow.value),
                    blurRadius: 20 + (8 * _glow.value),
                    spreadRadius: -4,
                  ),
                ]
              : null,
        ),
        child: child,
      ),
      child: SizedBox(
        width: double.infinity,
        child: ElevatedButton.icon(
          icon: widget.loading
              ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(
                      strokeWidth: 2, color: Colors.white))
              : const Icon(Icons.auto_awesome_rounded, size: 17),
          label: const Text('Auto-Schedule'),
          onPressed: widget.onPressed,
        ),
      ),
    );
  }
}

// ── Contenedor con animación de tap genérico ───────────────────

class _AnimatedTapContainer extends StatefulWidget {
  final Widget child;
  final VoidCallback onTap;

  const _AnimatedTapContainer({
    required this.child,
    required this.onTap,
  });

  @override
  State<_AnimatedTapContainer> createState() => _AnimatedTapContainerState();
}

class _AnimatedTapContainerState extends State<_AnimatedTapContainer>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  late final Animation<double> _scale;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 80),
      reverseDuration: const Duration(milliseconds: 160),
    );
    _scale = Tween<double>(begin: 1.0, end: 0.97).animate(
      CurvedAnimation(parent: _ctrl, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: (_) => _ctrl.forward(),
      onTapUp: (_) {
        _ctrl.reverse();
        widget.onTap();
      },
      onTapCancel: () => _ctrl.reverse(),
      child: ScaleTransition(
        scale: _scale,
        child: widget.child,
      ),
    );
  }
}
