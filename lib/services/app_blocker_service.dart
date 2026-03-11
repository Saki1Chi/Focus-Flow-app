import 'dart:convert';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../core/constants/app_constants.dart';
import '../data/models/task_model.dart';
import '../data/repositories/task_repository.dart';
import '../services/alarm_service.dart';

class AppBlockerService {
  static final AppBlockerService _instance = AppBlockerService._();
  factory AppBlockerService() => _instance;
  AppBlockerService._();

  static const _channel = MethodChannel('com.example.calendario/app_blocker');

  final _repo = TaskRepository();
  final _alarm = AlarmService();

  // ─── Accessibility Service ────────────────────────────────────

  Future<bool> isAccessibilityEnabled() async {
    try {
      final result = await _channel.invokeMethod<bool>('isAccessibilityEnabled');
      return result ?? false;
    } catch (_) {
      return false;
    }
  }

  Future<void> openAccessibilitySettings() async {
    try {
      await _channel.invokeMethod('openAccessibilitySettings');
    } catch (_) {}
  }

  Future<void> openUsageAccessSettings() async {
    try {
      await _channel.invokeMethod('openUsageAccessSettings');
    } catch (_) {}
  }

  // ─── Blocking state (shared with Kotlin via SharedPreferences) ─

  Future<void> setBlockingActive(bool active) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(AppConstants.prefBlockingActive, active);
  }

  Future<bool> isBlockingActive() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(AppConstants.prefBlockingActive) ?? false;
  }

  Future<void> setBlockedApps(List<String> packageNames) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      AppConstants.prefBlockedApps,
      jsonEncode(packageNames),
    );
  }

  Future<List<String>> getBlockedApps() async {
    final prefs = await SharedPreferences.getInstance();
    final json = prefs.getString(AppConstants.prefBlockedApps) ?? '[]';
    return List<String>.from(jsonDecode(json));
  }

  // ─── Block / Unlock logic ─────────────────────────────────────

  /// Call this after completing a task. Returns true if apps are unlocked.
  Future<bool> onTaskCompleted({
    required int completedBlocksToday,
    required int unlockDurationMinutes,
  }) async {
    if (completedBlocksToday % AppConstants.blocksToUnlock == 0) {
      await _unlockApps(unlockDurationMinutes);
      await _alarm.showUnlockNotification(unlockDurationMinutes);
      return true;
    }
    return false;
  }

  Future<void> _unlockApps(int durationMinutes) async {
    await setBlockingActive(false);
    // Auto-relock after duration
    Future.delayed(Duration(minutes: durationMinutes), () async {
      await setBlockingActive(true);
      await _alarm.showBlockResumedNotification();
    });
  }

  Future<void> enableBlocking() async {
    await setBlockingActive(true);
  }

  Future<void> disableBlocking() async {
    await setBlockingActive(false);
  }

  // ─── Carry-over check ─────────────────────────────────────────

  /// Should be called on app start / midnight to handle expired tasks.
  Future<void> processCarryOver({
    required Function(String taskId) onCarryOver,
  }) async {
    final now = DateTime.now();
    final tasks = _repo.getAllTasks();

    for (final task in tasks) {
      if (task.status == TaskStatus.completed) continue;
      if (task.endTime == null) continue;
      if (now.isAfter(task.endTime!)) {
        onCarryOver(task.id);
      }
    }
  }
}
