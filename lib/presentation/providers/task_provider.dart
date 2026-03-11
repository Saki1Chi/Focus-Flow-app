import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';
import '../../data/models/task_model.dart';
import '../../data/models/block_session.dart';
import '../../data/repositories/task_repository.dart';
import '../../services/alarm_service.dart';
import '../../services/app_blocker_service.dart';
import '../../services/scheduler_service.dart';
import 'settings_provider.dart';

final _uuid = Uuid();

class TaskNotifier extends StateNotifier<List<Task>> {
  TaskNotifier(this._ref) : super([]) {
    _load();
  }

  final Ref _ref;
  final _repo = TaskRepository();
  final _alarm = AlarmService();
  final _blocker = AppBlockerService();
  final _scheduler = SchedulerService();

  void _load() {
    state = _repo.getAllTasks();
  }

  List<Task> tasksForDate(DateTime date) {
    final d = DateTime(date.year, date.month, date.day);
    return state
        .where((t) {
          final td = DateTime(t.date.year, t.date.month, t.date.day);
          return td == d;
        })
        .toList()
      ..sort((a, b) => a.dayOrder.compareTo(b.dayOrder));
  }

  // ─── CRUD ─────────────────────────────────────────────────────

  Future<Task> addTask({
    required String title,
    String description = '',
    required DateTime date,
    DateTime? startTime,
    DateTime? endTime,
    TaskMode mode = TaskMode.calendar,
    recurrence,
  }) async {
    final tasks = tasksForDate(date);
    final task = Task(
      id: _uuid.v4(),
      title: title,
      description: description,
      date: date,
      startTime: startTime,
      endTime: endTime,
      mode: mode,
      recurrence: recurrence,
      dayOrder: tasks.length,
      status: TaskStatus.pending,
    );
    await _repo.saveTask(task);
    state = [...state, task];

    final settings = _ref.read(settingsProvider);
    await _alarm.scheduleTaskAlert(task, settings.alertDelayMinutes);

    return task;
  }

  Future<void> updateTask(Task task) async {
    await _repo.saveTask(task);
    state = state.map((t) => t.id == task.id ? task : t).toList();
  }

  Future<void> deleteTask(String id) async {
    final task = _repo.getTaskById(id);
    if (task != null) await _alarm.cancelTaskAlert(task);
    await _repo.deleteTask(id);
    state = state.where((t) => t.id != id).toList();
  }

  // ─── Status management ────────────────────────────────────────

  Future<void> markInProgress(String id) async {
    final task = state.firstWhere((t) => t.id == id);
    final dayTasks = tasksForDate(task.date)..sort((a, b) => a.dayOrder.compareTo(b.dayOrder));

    // Sequential lock: previous task must be completed or in progress
    final idx = dayTasks.indexWhere((t) => t.id == id);
    if (idx > 0) {
      final prev = dayTasks[idx - 1];
      if (prev.status == TaskStatus.pending) return; // blocked
    }

    await updateTask(task.copyWith(status: TaskStatus.inProgress));
  }

  Future<void> markCompleted(String id) async {
    final task = state.firstWhere((t) => t.id == id);
    final dayTasks = tasksForDate(task.date)..sort((a, b) => a.dayOrder.compareTo(b.dayOrder));

    final idx = dayTasks.indexWhere((t) => t.id == id);
    if (idx > 0) {
      final prev = dayTasks[idx - 1];
      if (prev.status != TaskStatus.completed) return; // sequential lock
    }

    await updateTask(task.copyWith(status: TaskStatus.completed));
    await _alarm.cancelTaskAlert(task);

    // Update blocks counter & check for unlock
    await _ref.read(settingsProvider.notifier).incrementCompletedBlocks();
    final settings = _ref.read(settingsProvider);
    final blocks = settings.completedBlocks;

    final unlocked = await _blocker.onTaskCompleted(
      completedBlocksToday: blocks,
      unlockDurationMinutes: settings.unlockDuration,
    );

    if (unlocked) {
      // Save block session
      final session = BlockSession(
        id: _uuid.v4(),
        unlockedAt: DateTime.now(),
        expiresAt: DateTime.now().add(Duration(minutes: settings.unlockDuration)),
      );
      await _repo.saveSession(session);
    }
  }

  Future<void> markPending(String id) async {
    final task = state.firstWhere((t) => t.id == id);
    await updateTask(task.copyWith(status: TaskStatus.pending));
  }

  // ─── Smart scheduling ─────────────────────────────────────────

  Future<List<Task>> smartSchedule({
    required List<({String title, String description})> inputs,
    required DateTime date,
  }) async {
    final existing = tasksForDate(date);
    final bareTasks = inputs
        .map((i) => Task(
              id: _uuid.v4(),
              title: i.title,
              description: i.description,
              date: date,
              mode: TaskMode.smart,
            ))
        .toList();

    final scheduled = _scheduler.scheduleTasks(
      bareTasks: bareTasks,
      date: date,
      existingTasks: existing,
    );

    for (final task in scheduled) {
      await _repo.saveTask(task);
      final settings = _ref.read(settingsProvider);
      await _alarm.scheduleTaskAlert(task, settings.alertDelayMinutes);
    }

    state = [...state, ...scheduled];
    return scheduled;
  }

  // ─── Carry-over ───────────────────────────────────────────────

  Future<void> processCarryOvers() async {
    final now = DateTime.now();
    final overdueTasks = state.where((t) {
      if (t.status == TaskStatus.completed) return false;
      if (t.endTime == null) return false;
      return now.isAfter(t.endTime!);
    }).toList();

    for (final task in overdueTasks) {
      Task? reSlotted;

      if (task.mode == TaskMode.smart) {
        reSlotted = _scheduler.reSlotCarriedOver(
          task: task,
          fromDate: task.date,
          tasksForDate: tasksForDate,
        );
      } else {
        // Calendar mode: try same time slot next day
        final nextDay = task.date.add(const Duration(days: 1));
        if (!_repo.taskExistsOnDate(task.title, nextDay)) {
          reSlotted = task.copyWith(
            id: _uuid.v4(),
            date: nextDay,
            startTime: task.startTime != null
                ? DateTime(nextDay.year, nextDay.month, nextDay.day,
                    task.startTime!.hour, task.startTime!.minute)
                : null,
            endTime: task.endTime != null
                ? DateTime(nextDay.year, nextDay.month, nextDay.day,
                    task.endTime!.hour, task.endTime!.minute)
                : null,
            status: TaskStatus.pending,
            isCarriedOver: true,
            dayOrder: tasksForDate(nextDay).length,
          );
        }
      }

      // Delete original
      await _repo.deleteTask(task.id);
      state = state.where((t) => t.id != task.id).toList();

      // Save reSlotted version
      if (reSlotted != null) {
        await _repo.saveTask(reSlotted);
        state = [...state, reSlotted];
        final settings = _ref.read(settingsProvider);
        await _alarm.scheduleTaskAlert(reSlotted, settings.alertDelayMinutes);
      }
    }
  }

  // ─── Recurrence expansion ─────────────────────────────────────

  Future<void> expandRecurringTasks(DateTime upTo) async {
    final parents = state.where((t) => t.isRecurringParent && t.recurrence != null).toList();

    for (final parent in parents) {
      DateTime? next = parent.recurrence!.nextOccurrence(parent.date);
      while (next != null && !next.isAfter(upTo)) {
        if (!_repo.taskExistsOnDate(parent.title, next)) {
          final instance = parent.copyWith(
            id: _uuid.v4(),
            date: next,
            startTime: parent.startTime != null
                ? DateTime(next.year, next.month, next.day,
                    parent.startTime!.hour, parent.startTime!.minute)
                : null,
            endTime: parent.endTime != null
                ? DateTime(next.year, next.month, next.day,
                    parent.endTime!.hour, parent.endTime!.minute)
                : null,
            status: TaskStatus.pending,
            parentId: parent.id,
            isRecurringParent: false,
          );
          await _repo.saveTask(instance);
          state = [...state, instance];
        }
        next = parent.recurrence!.nextOccurrence(next);
      }
    }
  }

  // ─── Active block session ─────────────────────────────────────

  BlockSession? getActiveSession() => _repo.getActiveSession();
}

final taskProvider = StateNotifierProvider<TaskNotifier, List<Task>>(
  (ref) => TaskNotifier(ref),
);

final todayTasksProvider = Provider<List<Task>>((ref) {
  final all = ref.watch(taskProvider);
  final today = DateTime.now();
  final d = DateTime(today.year, today.month, today.day);
  return all
      .where((t) => DateTime(t.date.year, t.date.month, t.date.day) == d)
      .toList()
    ..sort((a, b) => a.dayOrder.compareTo(b.dayOrder));
});
