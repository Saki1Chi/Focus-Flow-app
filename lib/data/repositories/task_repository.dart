import 'package:hive_flutter/hive_flutter.dart';
import '../models/task_model.dart';
import '../models/block_session.dart';
import '../../core/constants/app_constants.dart';

class TaskRepository {
  Box<String> get _tasksBox => Hive.box<String>(AppConstants.tasksBox);
  Box<String> get _sessionsBox =>
      Hive.box<String>(AppConstants.blockSessionsBox);

  // ─── Tasks ───────────────────────────────────────────────────

  List<Task> getAllTasks() {
    return _tasksBox.values
        .map((s) {
          try {
            return Task.fromJsonString(s);
          } catch (_) {
            return null;
          }
        })
        .whereType<Task>()
        .toList();
  }

  List<Task> getTasksForDate(DateTime date) {
    final d = _dateOnly(date);
    return getAllTasks().where((t) => _dateOnly(t.date) == d).toList()
      ..sort((a, b) => a.dayOrder.compareTo(b.dayOrder));
  }

  Task? getTaskById(String id) {
    final s = _tasksBox.get(id);
    if (s == null) return null;
    try {
      return Task.fromJsonString(s);
    } catch (_) {
      return null;
    }
  }

  Future<void> saveTask(Task task) async {
    await _tasksBox.put(task.id, task.toJsonString());
  }

  Future<void> deleteTask(String id) async {
    await _tasksBox.delete(id);
  }

  Future<void> deleteTasksByParentId(String parentId) async {
    final toDelete = getAllTasks()
        .where((t) => t.parentId == parentId)
        .map((t) => t.id)
        .toList();
    for (final id in toDelete) {
      await _tasksBox.delete(id);
    }
  }

  bool taskExistsOnDate(String title, DateTime date) {
    final d = _dateOnly(date);
    return getAllTasks().any(
      (t) =>
          t.title.toLowerCase() == title.toLowerCase() &&
          _dateOnly(t.date) == d,
    );
  }

  List<Task> getTasksBetween(DateTime start, DateTime end) {
    return getAllTasks().where((t) {
      final d = _dateOnly(t.date);
      return !d.isBefore(_dateOnly(start)) && !d.isAfter(_dateOnly(end));
    }).toList();
  }

  int countCompletedToday() {
    final today = _dateOnly(DateTime.now());
    return getAllTasks()
        .where(
          (t) => _dateOnly(t.date) == today && t.status == TaskStatus.completed,
        )
        .length;
  }

  // ─── Block Sessions ───────────────────────────────────────────

  BlockSession? getActiveSession() {
    for (final s in _sessionsBox.values) {
      try {
        final session = BlockSession.fromJsonString(s);
        if (session.isActive && !session.isExpired) return session;
      } catch (_) {}
    }
    return null;
  }

  Future<void> saveSession(BlockSession session) async {
    await _sessionsBox.put(session.id, session.toJsonString());
  }

  Future<void> expireAllSessions() async {
    final all = _sessionsBox.keys.toList();
    for (final k in all) {
      final s = _sessionsBox.get(k as String);
      if (s != null) {
        try {
          final session = BlockSession.fromJsonString(s)..isActive = false;
          await _sessionsBox.put(k, session.toJsonString());
        } catch (_) {}
      }
    }
  }

  // PRIMER CAMBIO REALIZADO
  Future<void> replaceAll(List<Task> tasks) async {
    await _tasksBox.clear();
    final map = {for (final t in tasks) t.id: t.toJsonString()};
    await _tasksBox.putAll(map);
  }

  // ─── Helpers ──────────────────────────────────────────────────

  DateTime _dateOnly(DateTime dt) => DateTime(dt.year, dt.month, dt.day);
}
