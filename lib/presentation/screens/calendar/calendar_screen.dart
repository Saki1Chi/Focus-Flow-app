import 'package:animate_do/animate_do.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:table_calendar/table_calendar.dart';
import '../../../core/theme/app_theme.dart';
import '../../../data/models/task_model.dart';
import '../../providers/task_provider.dart';
import '../../providers/settings_provider.dart';
import '../../widgets/task_card.dart';
import '../task_detail_screen.dart';
import 'add_task_screen.dart';

class CalendarScreen extends ConsumerStatefulWidget {
  const CalendarScreen({super.key});

  @override
  ConsumerState<CalendarScreen> createState() => _CalendarScreenState();
}

class _CalendarScreenState extends ConsumerState<CalendarScreen> {
  DateTime _focusedDay  = DateTime.now();
  DateTime _selectedDay = DateTime.now();
  CalendarFormat _calFormat = CalendarFormat.month;

  @override
  Widget build(BuildContext context) {
    final tasks  = ref.watch(taskProvider);
    final accent = ref.watch(settingsProvider).accentColor;
    final tokens = Theme.of(context).extension<MinimalTheme>();
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final selectedDayTasks = tasks
        .where((t) {
          final d = DateTime(t.date.year, t.date.month, t.date.day);
          final s = DateTime(_selectedDay.year, _selectedDay.month, _selectedDay.day);
          return d == s;
        })
        .toList()
      ..sort((a, b) => a.dayOrder.compareTo(b.dayOrder));

    final calBg        = tokens?.surface ?? (isDark ? const Color(0xFF0E0E1C) : Colors.white);
    final borderColor  = tokens?.border ??
        (isDark ? Colors.white.withValues(alpha: 0.07) : Colors.black.withValues(alpha: 0.06));
    final headerColor  = tokens?.text ?? (isDark ? const Color(0xFFF0F0FF) : const Color(0xFF080818));
    final weekdayColor = tokens?.textSub ?? (isDark ? const Color(0xFF484862) : const Color(0xFF9898B8));
    final defaultColor = tokens?.text ?? (isDark ? const Color(0xFFE0E0FF) : const Color(0xFF080818));
    final outsideColor = tokens?.textSub.withValues(alpha: 0.5) ??
        (isDark ? const Color(0xFF2A2A42) : const Color(0xFFCCCCDD));

    return Scaffold(
      appBar: AppBar(title: const Text('Calendar')),
      body: Column(
        children: [
          // ── Calendar card ──────────────────────────────
          FadeInDown(
            duration: const Duration(milliseconds: 400),
            child: Container(
              margin: const EdgeInsets.fromLTRB(16, 8, 16, 0),
              decoration: BoxDecoration(
                color: calBg,
                borderRadius: BorderRadius.circular(24),
                border: Border.all(color: borderColor, width: 1),
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(24),
                child: TableCalendar<Task>(
                  firstDay: DateTime.now().subtract(const Duration(days: 365)),
                  lastDay:  DateTime.now().add(const Duration(days: 730)),
                  focusedDay: _focusedDay,
                  selectedDayPredicate: (d) => isSameDay(d, _selectedDay),
                  calendarFormat: _calFormat,
                  eventLoader: (day) {
                    final d = DateTime(day.year, day.month, day.day);
                    return tasks
                        .where((t) => DateTime(t.date.year, t.date.month, t.date.day) == d)
                        .toList();
                  },
                  onDaySelected: (selected, focused) => setState(() {
                    _selectedDay = selected;
                    _focusedDay  = focused;
                  }),
                  onFormatChanged: (f) => setState(() => _calFormat = f),
                  onPageChanged: (f) => _focusedDay = f,
                  calendarStyle: CalendarStyle(
                    defaultTextStyle: TextStyle(color: defaultColor, fontSize: 13),
                    weekendTextStyle: TextStyle(color: defaultColor, fontSize: 13),
                    outsideTextStyle: TextStyle(color: outsideColor, fontSize: 13),
                    todayDecoration: BoxDecoration(
                      color: accent.withValues(alpha: 0.12),
                      shape: BoxShape.circle,
                      border: Border.all(color: accent.withValues(alpha: 0.4), width: 1.2),
                    ),
                    todayTextStyle: TextStyle(
                        color: tokens?.text ?? accent,
                        fontSize: 13,
                        fontWeight: FontWeight.w700),
                    selectedDecoration: BoxDecoration(
                      color: accent.withValues(alpha: 0.16),
                      shape: BoxShape.circle,
                      border: Border.all(color: accent, width: 1.4),
                    ),
                    selectedTextStyle: TextStyle(
                        color: tokens?.text ?? Colors.white,
                        fontSize: 13,
                        fontWeight: FontWeight.w700),
                    markerDecoration: BoxDecoration(
                      color: accent.withValues(alpha: 0.9),
                      shape: BoxShape.circle,
                    ),
                    markerSize: 5,
                    markersMaxCount: 3,
                    outsideDaysVisible: false,
                    cellMargin: const EdgeInsets.all(4),
                  ),
                  headerStyle: HeaderStyle(
                    formatButtonVisible: true,
                    titleCentered: true,
                    formatButtonShowsNext: false,
                    titleTextStyle: TextStyle(
                        color: headerColor,
                        fontSize: 15,
                        fontWeight: FontWeight.w700),
                    leftChevronIcon: Icon(Icons.chevron_left_rounded,
                        color: headerColor, size: 22),
                    rightChevronIcon: Icon(Icons.chevron_right_rounded,
                        color: headerColor, size: 22),
                    formatButtonDecoration: BoxDecoration(
                      color: accent.withValues(alpha: 0.10),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                          color: accent.withValues(alpha: 0.28), width: 1),
                    ),
                    formatButtonTextStyle: TextStyle(
                        color: accent, fontSize: 12, fontWeight: FontWeight.w700),
                    headerPadding:
                        const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
                  ),
                  daysOfWeekStyle: DaysOfWeekStyle(
                    weekdayStyle: TextStyle(
                        color: weekdayColor,
                        fontSize: 11,
                        fontWeight: FontWeight.w600),
                    weekendStyle: TextStyle(
                        color: weekdayColor,
                        fontSize: 11,
                        fontWeight: FontWeight.w600),
                  ),
                ),
              ),
            ),
          ),

          // ── Day header ────────────────────────────────
          Padding(
            padding: const EdgeInsets.fromLTRB(22, 18, 22, 8),
            child: Row(
              children: [
                Text(
                  isSameDay(_selectedDay, DateTime.now())
                      ? 'Today'
                      : DateFormat('EEEE, MMM d').format(_selectedDay),
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                const Spacer(),
                AnimatedSwitcher(
                  duration: const Duration(milliseconds: 250),
                  child: Text(
                    key: ValueKey(selectedDayTasks.length),
                    '${selectedDayTasks.length} task${selectedDayTasks.length == 1 ? '' : 's'}',
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                ),
              ],
            ),
          ),

          // ── Task list ────────────────────────────────
          Expanded(
            child: AnimatedSwitcher(
              duration: const Duration(milliseconds: 280),
              switchInCurve: Curves.easeOutCubic,
              switchOutCurve: Curves.easeInCubic,
              transitionBuilder: (child, anim) => FadeTransition(
                opacity: anim,
                child: SlideTransition(
                  position: Tween<Offset>(
                    begin: const Offset(0, 0.03),
                    end: Offset.zero,
                  ).animate(anim),
                  child: child,
                ),
              ),
              child: selectedDayTasks.isEmpty
                  ? _CalendarEmptyState(
                      key: ValueKey('empty_${_selectedDay.toIso8601String()}'),
                      accent: accent,
                      isDark: isDark,
                      selectedDay: _selectedDay,
                      onAddTap: () => Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) =>
                              AddTaskScreen(initialDate: _selectedDay),
                        ),
                      ),
                    )
                  : ListView.builder(
                      key: ValueKey('list_${_selectedDay.toIso8601String()}'),
                      physics: const BouncingScrollPhysics(),
                      padding: const EdgeInsets.only(bottom: 120),
                      itemCount: selectedDayTasks.length,
                      itemBuilder: (ctx, i) {
                        final task = selectedDayTasks[i];
                        return FadeInUp(
                          duration: const Duration(milliseconds: 280),
                          delay: Duration(milliseconds: 50 * i),
                          child: TaskCard(
                            task: task,
                            onTap: () => Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) =>
                                    TaskDetailScreen(taskId: task.id),
                              ),
                            ),
                          ),
                        );
                      },
                    ),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Empty state del calendario con ícono flotante ──────────────

class _CalendarEmptyState extends StatefulWidget {
  final Color accent;
  final bool isDark;
  final DateTime selectedDay;
  final VoidCallback onAddTap;

  const _CalendarEmptyState({
    super.key,
    required this.accent,
    required this.isDark,
    required this.selectedDay,
    required this.onAddTap,
  });

  @override
  State<_CalendarEmptyState> createState() => _CalendarEmptyStateState();
}

class _CalendarEmptyStateState extends State<_CalendarEmptyState>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  late final Animation<double> _float;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2600),
    )..repeat(reverse: true);
    _float = Tween<double>(begin: 0.0, end: -8.0).animate(
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
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          AnimatedBuilder(
            animation: _float,
            builder: (_, child) => Transform.translate(
              offset: Offset(0, _float.value),
              child: child,
            ),
            child: Container(
              width: 72,
              height: 72,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(colors: [
                  widget.isDark
                      ? Colors.white.withValues(alpha: 0.07)
                      : Colors.black.withValues(alpha: 0.04),
                  Colors.transparent,
                ]),
                boxShadow: widget.isDark
                    ? [
                        BoxShadow(
                          color: widget.accent.withValues(alpha: 0.06),
                          blurRadius: 20,
                          spreadRadius: -4,
                        )
                      ]
                    : null,
              ),
              child: Icon(
                Icons.event_available_rounded,
                size: 30,
                color: widget.isDark
                    ? Colors.white.withValues(alpha: 0.22)
                    : Colors.black.withValues(alpha: 0.18),
              ),
            ),
          ),
          const SizedBox(height: 16),
          Text(
            'No tasks on this day',
            style: Theme.of(context).textTheme.bodyLarge,
          ),
          const SizedBox(height: 14),
          _AddTaskButton(accent: widget.accent, isDark: widget.isDark, onTap: widget.onAddTap),
        ],
      ),
    );
  }
}

// ── Botón "Add task" animado ───────────────────────────────────

class _AddTaskButton extends StatefulWidget {
  final Color accent;
  final bool isDark;
  final VoidCallback onTap;

  const _AddTaskButton({
    required this.accent,
    required this.isDark,
    required this.onTap,
  });

  @override
  State<_AddTaskButton> createState() => _AddTaskButtonState();
}

class _AddTaskButtonState extends State<_AddTaskButton>
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
    _scale = Tween<double>(begin: 1.0, end: 0.93).animate(
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
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
          decoration: BoxDecoration(
            color: widget.accent.withValues(alpha: 0.10),
            borderRadius: BorderRadius.circular(22),
            border: Border.all(
                color: widget.accent.withValues(alpha: 0.25), width: 1),
            boxShadow: widget.isDark
                ? NeonColors.softGlow(widget.accent)
                : null,
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.add_rounded, size: 15, color: widget.accent),
              const SizedBox(width: 6),
              Text(
                'Add task',
                style: TextStyle(
                  fontSize: 13,
                  color: widget.accent,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
