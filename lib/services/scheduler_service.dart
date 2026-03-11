import 'package:flutter/material.dart' show TimeOfDay;
import '../data/models/task_model.dart';

class SchedulerService {
  static final SchedulerService _instance = SchedulerService._();
  factory SchedulerService() => _instance;
  SchedulerService._();

  static const Duration _taskDuration = Duration(hours: 1, minutes: 30);
  static const TimeOfDay _workdayStart = TimeOfDay(hour: 8, minute: 0);
  static const TimeOfDay _workdayEnd = TimeOfDay(hour: 20, minute: 0);

  /// Auto-schedule a list of bare tasks (title+description only) for [date].
  /// [existingTasks] = tasks already on that day (used for conflict detection).
  List<Task> scheduleTasks({
    required List<Task> bareTasks,
    required DateTime date,
    required List<Task> existingTasks,
  }) {
    final scheduled = <Task>[];
    final occupiedSlots = _getOccupiedSlots(existingTasks, date);

    var cursor = _toDateTime(date, _workdayStart);
    final dayEnd = _toDateTime(date, _workdayEnd);

    for (int i = 0; i < bareTasks.length; i++) {
      final task = bareTasks[i];

      // Skip duplicates
      if (existingTasks.any(
        (e) => e.title.toLowerCase() == task.title.toLowerCase(),
      )) continue;

      // Find next free slot
      DateTime? slotStart = _findFreeSlot(cursor, occupiedSlots, dayEnd);
      if (slotStart == null) break; // no more room today

      final slotEnd = slotStart.add(_taskDuration);
      occupiedSlots.add(_TimeSlot(slotStart, slotEnd));

      scheduled.add(task.copyWith(
        date: date,
        startTime: slotStart,
        endTime: slotEnd,
        dayOrder: i,
        mode: TaskMode.smart,
        status: TaskStatus.pending,
      ));

      cursor = slotEnd;
    }

    return scheduled;
  }

  /// Re-slot a single carried-over task into the next available day.
  Task? reSlotCarriedOver({
    required Task task,
    required DateTime fromDate,
    required List<Task> Function(DateTime) tasksForDate,
    int maxDaysAhead = 7,
  }) {
    for (int d = 1; d <= maxDaysAhead; d++) {
      final candidate = fromDate.add(Duration(days: d));
      final dayTasks = tasksForDate(candidate);

      // Duplicate check
      if (dayTasks.any(
        (t) => t.title.toLowerCase() == task.title.toLowerCase(),
      )) continue;

      final slots = _getOccupiedSlots(dayTasks, candidate);
      final dayEnd = _toDateTime(candidate, _workdayEnd);
      final slotStart = _findFreeSlot(
          _toDateTime(candidate, _workdayStart), slots, dayEnd);
      if (slotStart == null) continue;

      return task.copyWith(
        date: candidate,
        startTime: slotStart,
        endTime: slotStart.add(_taskDuration),
        dayOrder: dayTasks.length,
        isCarriedOver: true,
        status: TaskStatus.pending,
      );
    }
    return null;
  }

  List<_TimeSlot> _getOccupiedSlots(List<Task> tasks, DateTime date) {
    return tasks
        .where((t) => t.startTime != null && t.endTime != null)
        .map((t) => _TimeSlot(t.startTime!, t.endTime!))
        .toList();
  }

  DateTime? _findFreeSlot(
    DateTime cursor,
    List<_TimeSlot> occupied,
    DateTime dayEnd,
  ) {
    while (cursor.add(_taskDuration).isBefore(dayEnd) ||
        cursor.add(_taskDuration) == dayEnd) {
      final proposed = _TimeSlot(cursor, cursor.add(_taskDuration));
      final conflict = occupied.any((s) => s.overlaps(proposed));
      if (!conflict) return cursor;
      // Advance past the conflicting slot
      final blocking =
          occupied.firstWhere((s) => s.overlaps(proposed));
      cursor = blocking.end;
    }
    return null;
  }

  DateTime _toDateTime(DateTime date, TimeOfDay time) =>
      DateTime(date.year, date.month, date.day, time.hour, time.minute);
}

class _TimeSlot {
  final DateTime start;
  final DateTime end;
  _TimeSlot(this.start, this.end);
  bool overlaps(_TimeSlot other) => start.isBefore(other.end) && end.isAfter(other.start);
}
