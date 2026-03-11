import 'package:android_alarm_manager_plus/android_alarm_manager_plus.dart';
import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import '../data/models/task_model.dart';
import '../core/constants/app_constants.dart';

final FlutterLocalNotificationsPlugin _notif = FlutterLocalNotificationsPlugin();

// Top-level callback (required by android_alarm_manager_plus)
@pragma('vm:entry-point')
void alarmCallback(int id) async {
  WidgetsFlutterBinding.ensureInitialized();
  final plugin = FlutterLocalNotificationsPlugin();
  const androidInit = AndroidInitializationSettings('@mipmap/ic_launcher');
  await plugin.initialize(const InitializationSettings(android: androidInit));

  const androidDetails = AndroidNotificationDetails(
    AppConstants.alarmChannelId,
    AppConstants.alarmChannelName,
    importance: Importance.max,
    priority: Priority.high,
    playSound: true,
    enableVibration: true,
    fullScreenIntent: true,
  );
  await plugin.show(
    id,
    '⚠️ Task Alert — You\'re falling behind!',
    'One of your tasks has not been started yet. Open FocusFlow to catch up.',
    const NotificationDetails(android: androidDetails),
  );
}

class AlarmService {
  static final AlarmService _instance = AlarmService._();
  factory AlarmService() => _instance;
  AlarmService._();

  final _plugin = _notif;

  Future<void> init() async {
    const androidInit = AndroidInitializationSettings('@mipmap/ic_launcher');
    const initSettings = InitializationSettings(android: androidInit);
    await _plugin.initialize(
      initSettings,
      onDidReceiveNotificationResponse: _onNotifTap,
    );
    await _createChannels();
    await AndroidAlarmManager.initialize();
  }

  Future<void> _createChannels() async {
    final plugin = _plugin
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>();
    await plugin?.createNotificationChannel(
      const AndroidNotificationChannel(
        AppConstants.alarmChannelId,
        AppConstants.alarmChannelName,
        importance: Importance.max,
        playSound: true,
        enableVibration: true,
      ),
    );
    await plugin?.createNotificationChannel(
      const AndroidNotificationChannel(
        AppConstants.reminderChannelId,
        AppConstants.reminderChannelName,
        importance: Importance.high,
      ),
    );
  }

  void _onNotifTap(NotificationResponse response) {}

  /// Schedule an alarm [alertDelayMinutes] after task start time.
  Future<void> scheduleTaskAlert(Task task, int alertDelayMinutes) async {
    if (task.startTime == null) return;
    final fireAt = task.startTime!.add(Duration(minutes: alertDelayMinutes));
    if (fireAt.isBefore(DateTime.now())) return;

    final alarmId = task.id.hashCode.abs() % 100000;
    await AndroidAlarmManager.oneShotAt(
      fireAt,
      alarmId,
      alarmCallback,
      exact: true,
      wakeup: true,
      rescheduleOnReboot: true,
    );
  }

  Future<void> cancelTaskAlert(Task task) async {
    final alarmId = task.id.hashCode.abs() % 100000;
    await AndroidAlarmManager.cancel(alarmId);
  }

  /// Simple reminder notification (non-alarm).
  Future<void> showReminder({
    required int id,
    required String title,
    required String body,
  }) async {
    const androidDetails = AndroidNotificationDetails(
      AppConstants.reminderChannelId,
      AppConstants.reminderChannelName,
      importance: Importance.high,
      priority: Priority.high,
    );
    await _plugin.show(id, title, body,
        const NotificationDetails(android: androidDetails));
  }

  Future<void> showUnlockNotification(int minutes) async {
    await showReminder(
      id: 8888,
      title: '🎉 Apps Unlocked for $minutes minutes!',
      body: 'You completed 3 task blocks. Enjoy your break!',
    );
  }

  Future<void> showBlockResumedNotification() async {
    await showReminder(
      id: 8889,
      title: '🔒 Break time is over',
      body: 'Apps are blocked again. Back to focus!',
    );
  }

  Future<void> cancelAll() async {
    await _plugin.cancelAll();
  }
}
