import 'dart:developer' as dev;

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';
import '../../data/models/task_model.dart';
import '../../data/models/block_session.dart';
import '../../data/repositories/task_repository.dart';
import '../../services/alarm_service.dart';
import '../../services/app_blocker_service.dart';
import '../../services/scheduler_service.dart';
import '../../services/api_service.dart';
import 'settings_provider.dart';
import 'sync_provider.dart';
import 'social_provider.dart';

final _uuid = Uuid();

class TaskNotifier extends StateNotifier<List<Task>> {
  /// Las dependencias son opcionales para facilitar el testing con mocks.
  TaskNotifier(
    this._ref, {
    TaskRepository? repo,
    AlarmService? alarm,
    AppBlockerService? blocker,
    SchedulerService? scheduler,
  })  : _repo = repo ?? TaskRepository(),
        _alarm = alarm ?? AlarmService(),
        _blocker = blocker ?? AppBlockerService(),
        _scheduler = scheduler ?? SchedulerService(),
        super([]) {
    _init();
  }

  final Ref _ref;
  final TaskRepository _repo;
  final AlarmService _alarm;
  final AppBlockerService _blocker;
  final SchedulerService _scheduler;

  void _load() {
    state = _repo.getAllTasks();
  }

  /// Secuencia de arranque: carga local (síncrona) → pull servidor → expande recurrencias.
  /// Si el servidor falla, expande igual con datos locales. Solo un camino de expansión.
  Future<void> _init() async {
    _load(); // UI muestra datos locales inmediatamente
    try {
      await refreshFromServer(); // pull + expansión en caso de éxito
    } catch (e, st) {
      dev.log('Sin conexión al arrancar — usando datos locales',
          name: 'TaskNotifier', error: e, stackTrace: st);
      await _expandInitialRecurrences();
    }
  }

  Future<void> _expandInitialRecurrences() async {
    try {
      await expandRecurringTasks(DateTime.now().add(const Duration(days: 60)));
    } catch (_) {}
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

  // ─── Sync helper ──────────────────────────────────────────────

  void _setSyncing() =>
      _ref.read(syncStatusProvider.notifier).state = SyncStatus.syncing;

  void _setSynced() =>
      _ref.read(syncStatusProvider.notifier).state = SyncStatus.synced;

  void _setOffline() =>
      _ref.read(syncStatusProvider.notifier).state = SyncStatus.offline;

  /// Fire-and-forget: runs [fn] without blocking the UI.
  void _bgSync(Future<void> Function() fn) {
    _setSyncing();
    fn().then((_) => _setSynced()).catchError((_) => _setOffline());
  }

  // ─── CRUD ─────────────────────────────────────────────────────

  Future<void> refreshFromServer() async {
    final api = ApiService(baseUrl: _ref.read(settingsProvider).apiBaseUrl);
    final remote = await api.getTasks();
    await _repo.replaceAll(remote);
    state = remote;
    await _expandInitialRecurrences();
    // Opcional: reprogramar alarmas para pendientes con hora
    final settings = _ref.read(settingsProvider);
    for (final t in remote) {
      if (t.startTime != null && t.status == TaskStatus.pending) {
        await _alarm.scheduleTaskAlert(t, settings.alertDelayMinutes);
      }
    }
  }


  Future<Task> addTask({
    required String title,
    String description = '',
    required DateTime date,
    DateTime? startTime,
    DateTime? endTime,
    TaskMode mode = TaskMode.calendar,
    recurrence,
    bool isRecurringParent = false,
    int? categoryId,
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
      isRecurringParent: isRecurringParent,
      dayOrder: tasks.length,
      status: TaskStatus.pending,
      categoryId: categoryId,
    );
    await _repo.saveTask(task);
    state = [...state, task];

    final settings = _ref.read(settingsProvider);
    await _alarm.scheduleTaskAlert(task, settings.alertDelayMinutes);

    // Sync to backend in background
    _bgSync(() => ApiService(baseUrl: _ref.read(settingsProvider).apiBaseUrl).createTask(task));

    if (recurrence != null) {
      await expandRecurringTasks(DateTime.now().add(const Duration(days: 60)));
    }

    return task;
  }

  Future<void> updateTask(Task task) async {
    await _repo.saveTask(task);
    state = state.map((t) => t.id == task.id ? task : t).toList();
    // Sync to backend in background
    _bgSync(() => ApiService(baseUrl: _ref.read(settingsProvider).apiBaseUrl).updateTask(task));
  }

  Future<void> deleteTask(String id) async {
    final task = _repo.getTaskById(id);
    if (task != null) await _alarm.cancelTaskAlert(task);
    await _repo.deleteTask(id);
    state = state.where((t) => t.id != id).toList();
    // Sync to backend in background
    _bgSync(() => ApiService(baseUrl: _ref.read(settingsProvider).apiBaseUrl).deleteTask(id));
  }

  // ─── Status management ────────────────────────────────────────

  Future<void> markInProgress(String id) async {
    final idx = state.indexWhere((t) => t.id == id);
    if (idx == -1) return;
    await updateTask(state[idx].copyWith(status: TaskStatus.inProgress));
  }

  /// Marca la tarea como completada. Devuelve [false] si el sequential lock
  /// bloquea la acción (la tarea anterior del día no está completada).
  Future<bool> markCompleted(String id) async {
    final stateIdx = state.indexWhere((t) => t.id == id);
    if (stateIdx == -1) return false;
    final task = state[stateIdx];
    final dayTasks = tasksForDate(task.date)..sort((a, b) => a.dayOrder.compareTo(b.dayOrder));

    final idx = dayTasks.indexWhere((t) => t.id == id);
    if (idx > 0) {
      final prev = dayTasks[idx - 1];
      if (prev.status != TaskStatus.completed) return false; // sequential lock
    }

    await updateTask(task.copyWith(status: TaskStatus.completed));
    await _alarm.cancelTaskAlert(task);

    // Update blocks counter & check for unlock
    await _ref.read(settingsProvider.notifier).incrementCompletedBlocks();
    final streak = await _ref.read(settingsProvider.notifier).recordTaskCompletion();
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

    // ── Social: fire-and-forget ───────────────────────────────
    final social = _ref.read(socialProvider.notifier);
    social.logActivity(
      type: 'task_completed',
      description: 'Completed: ${task.title}',
    );
    social.syncUserStats(
      completedBlocks: blocks,
      currentStreak: streak,
    );
    _updateChallengeProgress(social, 'tasks', blocks);
    return true;
  }

  void _updateChallengeProgress(
      SocialNotifier social, String type, int progress) {
    final userId = _ref.read(socialProvider).currentUser?.id;
    if (userId == null) return;
    final active = _ref
        .read(socialProvider)
        .challenges
        .where((c) => c.status == 'active' && c.type == type)
        .toList();
    for (final c in active) {
      social.updateChallengeProgress(
        challengeId: c.id,
        myUserId: userId,
        progress: progress,
      );
    }
  }

  Future<void> markPending(String id) async {
    final idx = state.indexWhere((t) => t.id == id);
    if (idx == -1) return;
    await updateTask(state[idx].copyWith(status: TaskStatus.pending));
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
    final today = DateTime(now.year, now.month, now.day);

    final overdueTasks = state.where((t) {
      if (t.status == TaskStatus.completed) return false;
      if (t.endTime != null) return now.isAfter(t.endTime!);
      // Sin hora: lleva si la fecha de la tarea es anterior a hoy
      final taskDay = DateTime(t.date.year, t.date.month, t.date.day);
      return taskDay.isBefore(today);
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
        // Sin hora → llevar a hoy; con hora → al día siguiente
        final targetDay = task.endTime == null
            ? today
            : task.date.add(const Duration(days: 1));
        if (!_repo.taskExistsOnDate(task.title, targetDay)) {
          reSlotted = task.copyWith(
            id: _uuid.v4(),
            date: targetDay,
            startTime: task.startTime != null
                ? DateTime(targetDay.year, targetDay.month, targetDay.day,
                    task.startTime!.hour, task.startTime!.minute)
                : null,
            endTime: task.endTime != null
                ? DateTime(targetDay.year, targetDay.month, targetDay.day,
                    task.endTime!.hour, task.endTime!.minute)
                : null,
            status: TaskStatus.pending,
            isCarriedOver: true,
            dayOrder: tasksForDate(targetDay).length,
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
    if (parents.isEmpty) return;

    // Set de claves 'título|yyyy-m-d' construido una sola vez → O(1) por lookup
    // en lugar de O(n) por cada llamada a taskExistsOnDate.
    final existingKeys = <String>{
      for (final t in state)
        '${t.title.toLowerCase()}|${t.date.year}-${t.date.month}-${t.date.day}'
    };

    for (final parent in parents) {
      DateTime? next = parent.recurrence!.nextOccurrence(parent.date);
      while (next != null && !next.isAfter(upTo)) {
        final key = '${parent.title.toLowerCase()}|${next.year}-${next.month}-${next.day}';
        if (!existingKeys.contains(key)) {
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
          existingKeys.add(key); // mantener el Set sincronizado
        }
        next = parent.recurrence!.nextOccurrence(next);
      }
    }
  }

  // ─── Active block session ─────────────────────────────────────

  BlockSession? getActiveSession() => _repo.getActiveSession();

  // ─── CMS sync ─────────────────────────────────────────────────

  /// Pushes all local tasks to the CMS backend via a bulk upsert.
  /// Returns a map with 'created' and 'updated' counts on success.
  /// Throws an [Exception] if the server is unreachable or returns an error.
  Future<Map<String, int>> syncWithServer() async {
    final api = ApiService(baseUrl: _ref.read(settingsProvider).apiBaseUrl);
    return api.bulkSync(state);
  }
}

final taskProvider = StateNotifierProvider<TaskNotifier, List<Task>>(
  (ref) => TaskNotifier(ref),
);

final todayTasksProvider = Provider<List<Task>>((ref) {
  final today = DateTime.now();
  final d = DateTime(today.year, today.month, today.day);
  // select: Riverpod solo propaga el cambio si el valor devuelto cambia (==).
  // Para List esto usa igualdad por referencia; si Task implementa == por valor
  // en el futuro, las actualizaciones de otros días no causarán rebuild aquí.
  return ref.watch(
    taskProvider.select((all) => all
        .where((t) => DateTime(t.date.year, t.date.month, t.date.day) == d)
        .toList()
      ..sort((a, b) => a.dayOrder.compareTo(b.dayOrder))),
  );
});
