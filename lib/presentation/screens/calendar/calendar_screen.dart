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
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final selectedDayTasks = tasks
        .where((t) {
          final d = DateTime(t.date.year, t.date.month, t.date.day);
          final s = DateTime(_selectedDay.year, _selectedDay.month, _selectedDay.day);
          return d == s;
        })
        .toList()
      ..sort((a, b) => a.dayOrder.compareTo(b.dayOrder));

    final calBg        = isDark ? const Color(0xFF0E0E1C) : Colors.white;
    final headerColor  = isDark ? const Color(0xFFF0F0FF) : const Color(0xFF080818);
    final weekdayColor = isDark ? const Color(0xFF484862) : const Color(0xFF9898B8);
    final defaultColor = isDark ? const Color(0xFFE0E0FF) : const Color(0xFF080818);
    final outsideColor = isDark ? const Color(0xFF2A2A42) : const Color(0xFFCCCCDD);

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
                border: Border.all(
                  color: isDark
                      ? Colors.white.withValues(alpha: 0.07)
                      : Colors.black.withValues(alpha: 0.06),
                  width: 1,
                ),
                boxShadow: isDark ? NeonColors.crystalCard() : NeonColors.lightCard(),
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
                      color: accent.withValues(alpha: 0.14),
                      shape: BoxShape.circle,
                      border: Border.all(
                          color: accent.withValues(alpha: 0.5), width: 1.5),
                    ),
                    todayTextStyle: TextStyle(
                        color: accent, fontSize: 13, fontWeight: FontWeight.w700),
                    selectedDecoration: BoxDecoration(
                      color: accent,
                      shape: BoxShape.circle,
                      boxShadow: NeonColors.glow(accent, intensity: 0.85),
                    ),
                    selectedTextStyle: const TextStyle(
                        color: Colors.white,
                        fontSize: 13,
                        fontWeight: FontWeight.w700),
                    markerDecoration: BoxDecoration(
                      color: accent,
                      shape: BoxShape.circle,
                      boxShadow: NeonColors.glow(accent, intensity: 0.55),
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
            child: selectedDayTasks.isEmpty
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Container(
                          width: 64,
                          height: 64,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            gradient: RadialGradient(colors: [
                              isDark
                                  ? Colors.white.withValues(alpha: 0.06)
                                  : Colors.black.withValues(alpha: 0.04),
                              Colors.transparent,
                            ]),
                          ),
                          child: Icon(
                            Icons.event_available_rounded,
                            size: 28,
                            color: isDark
                                ? Colors.white.withValues(alpha: 0.20)
                                : Colors.black.withValues(alpha: 0.18),
                          ),
                        ),
                        const SizedBox(height: 14),
                        Text(
                          'No tasks on this day',
                          style: Theme.of(context).textTheme.bodyLarge,
                        ),
                        const SizedBox(height: 12),
                        GestureDetector(
                          onTap: () => Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) =>
                                  AddTaskScreen(initialDate: _selectedDay),
                            ),
                          ),
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 16, vertical: 9),
                            decoration: BoxDecoration(
                              color: accent.withValues(alpha: 0.10),
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(
                                  color: accent.withValues(alpha: 0.25),
                                  width: 1),
                              boxShadow: isDark
                                  ? NeonColors.softGlow(accent)
                                  : null,
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(Icons.add_rounded, size: 15, color: accent),
                                const SizedBox(width: 6),
                                Text(
                                  'Add task',
                                  style: TextStyle(
                                    fontSize: 13,
                                    color: accent,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  )
                : ListView.builder(
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
        ],
      ),
    );
  }
}
