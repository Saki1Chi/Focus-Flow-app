import 'package:flutter/material.dart';

class AppConstants {
  static const String appName = 'FocusFlow';
  static const String appVersion = '1.0.0';

  // Hive box names
  static const String tasksBox = 'tasks_box';
  static const String settingsBox = 'settings_box';
  static const String blockSessionsBox = 'block_sessions_box';

  // SharedPreferences keys (mirrored in Kotlin)
  static const String prefBlockingActive = 'focusflow_blocking_active';
  static const String prefBlockedApps = 'focusflow_blocked_apps';

  // Settings keys
  static const String keyUnlockDuration = 'unlock_duration_minutes';
  static const String keyAlertDelay = 'alert_delay_minutes';
  static const String keyDefaultMode = 'default_mode';
  static const String keyAccentColor = 'accent_color';
  static const String keyCustomAccent = 'custom_accent_hex';
  static const String keyDarkMode = 'dark_mode';
  static const String keyOnboardingDone = 'onboarding_done';
  static const String keyCompletedBlocks = 'completed_blocks';

  // Defaults
  static const int defaultUnlockDuration = 20; // minutes
  static const int defaultAlertDelay = 30; // minutes
  static const int blocksToUnlock = 3; // complete 3 task blocks to unlock

  // Notification channels
  static const String alarmChannelId = 'focusflow_alarms';
  static const String alarmChannelName = 'Task Alarms';
  static const String reminderChannelId = 'focusflow_reminders';
  static const String reminderChannelName = 'Task Reminders';

  // Accent colors (presets)
  static const Map<String, Color> accentColors = {
    'blue': Color(0xFF3B82F6),
    'green': Color(0xFF22C55E),
    'amber': Color(0xFFF59E0B),
    'coral': Color(0xFFF97369),
    'violet': Color(0xFFA855F7),
    'teal': Color(0xFF14B8A6),
    'gray': Color(0xFF9CA3AF),
    'custom': Color(0xFF3B82F6), // placeholder when custom selected
  };

  static const String defaultAccentColor = 'blue';

  // ── Backend API ─────────────────────────────────────────────────────────
  // Android emulator → host machine localhost: 10.0.2.2
  // Physical device (same Wi-Fi) → use your machine's local IP, e.g. 192.168.x.x
  static const String apiBaseUrl = 'http://10.0.2.2:8000';
}
