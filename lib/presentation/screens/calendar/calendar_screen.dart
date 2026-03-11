import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:table_calendar/table_calendar.dart';
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
  DateTime _focusedDay = DateTime.now();
  DateTime _selectedDay = DateTime.now();
  CalendarFormat _calFormat = CalendarFormat.month;

  @override
  Widget build(BuildContext context) {
    final tasks = ref.watch(taskProvider);
    final accent = ref.watch(settingsProvider).accentColor;

    final selectedDayTasks = tasks
        .where((t) {
          final d = DateTime(t.date.year, t.date.month, t.date.day);
          final s = DateTime(_selectedDay.year, _selectedDay.month, _selectedDay.day);
          return d == s;
        })
        .toList()
      ..sort((a, b) => a.dayOrder.compareTo(b.dayOrder));

    return Scaffold(
      appBar: AppBar(title: const Text('Calendar')),
      body: Column(
        children: [
          TableCalendar<Task>(
            firstDay: DateTime.now().subtract(const Duration(days: 365)),
            lastDay: DateTime.now().add(const Duration(days: 730)),
            focusedDay: _focusedDay,
            selectedDayPredicate: (d) => isSameDay(d, _selectedDay),
            calendarFormat: _calFormat,
            eventLoader: (day) {
              final d = DateTime(day.year, day.month, day.day);
              return tasks
                  .where((t) =>
                      DateTime(t.date.year, t.date.month, t.date.day) == d)
                  .toList();
            },
            onDaySelected: (selected, focused) {
              setState(() {
                _selectedDay = selected;
                _focusedDay = focused;
              });
            },
            onFormatChanged: (f) => setState(() => _calFormat = f),
            onPageChanged: (f) => _focusedDay = f,
            calendarStyle: CalendarStyle(
              todayDecoration: BoxDecoration(
                color: accent.withOpacity(0.3),
                shape: BoxShape.circle,
              ),
              selectedDecoration: BoxDecoration(
                color: accent,
                shape: BoxShape.circle,
              ),
              markerDecoration: BoxDecoration(
                color: accent,
                shape: BoxShape.circle,
              ),
              outsideDaysVisible: false,
            ),
            headerStyle: const HeaderStyle(
              formatButtonVisible: true,
              titleCentered: true,
              formatButtonShowsNext: false,
            ),
          ),
          const Divider(height: 1),

          // Day header
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
            child: Row(
              children: [
                Text(
                  DateFormat('EEEE, MMM d').format(_selectedDay),
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                const Spacer(),
                Text('${selectedDayTasks.length} tasks',
                    style: Theme.of(context).textTheme.bodyMedium),
              ],
            ),
          ),

          Expanded(
            child: selectedDayTasks.isEmpty
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.event_available_rounded,
                            size: 48, color: accent.withOpacity(0.4)),
                        const SizedBox(height: 12),
                        Text('No tasks on this day',
                            style: Theme.of(context).textTheme.bodyLarge),
                        const SizedBox(height: 8),
                        TextButton.icon(
                          icon: const Icon(Icons.add_rounded),
                          label: const Text('Add task'),
                          onPressed: () => Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) =>
                                  AddTaskScreen(initialDate: _selectedDay),
                            ),
                          ),
                        ),
                      ],
                    ),
                  )
                : ListView.builder(
                    padding: const EdgeInsets.only(bottom: 100),
                    itemCount: selectedDayTasks.length,
                    itemBuilder: (ctx, i) {
                      final task = selectedDayTasks[i];
                      return TaskCard(
                        task: task,
                        onTap: () => Navigator.push(
                          context,
                          MaterialPageRoute(
                              builder: (_) =>
                                  TaskDetailScreen(taskId: task.id)),
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
