import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive_flutter/hive_flutter.dart';
import '../../core/constants/app_constants.dart';

class SettingsState {
  final int unlockDuration;
  final int alertDelayMinutes;
  final String defaultMode; // 'calendar' or 'smart'
  final String accentColorKey;
  final String? customAccentHex;
  final bool darkMode;
  final bool onboardingDone;
  final int completedBlocks;
  final int currentStreak;
  final String? lastStreakDate; // 'yyyy-MM-dd'
  final List<String> blockedApps;
  final String apiBaseUrl;

  const SettingsState({
    this.unlockDuration = AppConstants.defaultUnlockDuration,
    this.alertDelayMinutes = AppConstants.defaultAlertDelay,
    this.defaultMode = 'calendar',
    this.accentColorKey = AppConstants.defaultAccentColor,
    this.customAccentHex,
    this.darkMode = false,
    this.onboardingDone = false,
    this.completedBlocks = 0,
    this.currentStreak = 0,
    this.lastStreakDate,
    this.blockedApps = const [],
    this.apiBaseUrl = AppConstants.apiBaseUrl,
  });

  Color get accentColor {
    if (accentColorKey == 'custom' && customAccentHex != null) {
      var hex = customAccentHex!.replaceFirst('0x', '').replaceFirst('#', '');
      if (hex.length == 6) hex = 'FF$hex';
      return Color(int.parse(hex, radix: 16));
    }
    return AppConstants.accentColors[accentColorKey] ?? AppConstants.accentColors['blue']!;
  }

  SettingsState copyWith({
    int? unlockDuration,
    int? alertDelayMinutes,
    String? defaultMode,
    String? accentColorKey,
    String? customAccentHex,
    bool? darkMode,
    bool? onboardingDone,
    int? completedBlocks,
    int? currentStreak,
    String? lastStreakDate,
    List<String>? blockedApps,
    String? apiBaseUrl,
  }) =>
      SettingsState(
        unlockDuration: unlockDuration ?? this.unlockDuration,
        alertDelayMinutes: alertDelayMinutes ?? this.alertDelayMinutes,
        defaultMode: defaultMode ?? this.defaultMode,
        accentColorKey: accentColorKey ?? this.accentColorKey,
        customAccentHex: customAccentHex ?? this.customAccentHex,
        darkMode: darkMode ?? this.darkMode,
        onboardingDone: onboardingDone ?? this.onboardingDone,
        completedBlocks: completedBlocks ?? this.completedBlocks,
        currentStreak: currentStreak ?? this.currentStreak,
        lastStreakDate: lastStreakDate ?? this.lastStreakDate,
        blockedApps: blockedApps ?? this.blockedApps,
        apiBaseUrl: apiBaseUrl ?? this.apiBaseUrl,
      );
}

class SettingsNotifier extends StateNotifier<SettingsState> {
  SettingsNotifier() : super(const SettingsState()) {
    _load();
  }

  Box<dynamic> get _box => Hive.box(AppConstants.settingsBox);

  void _load() {
    state = SettingsState(
      unlockDuration: _box.get(AppConstants.keyUnlockDuration, defaultValue: AppConstants.defaultUnlockDuration),
      alertDelayMinutes: _box.get(AppConstants.keyAlertDelay, defaultValue: AppConstants.defaultAlertDelay),
      defaultMode: _box.get(AppConstants.keyDefaultMode, defaultValue: 'calendar'),
      accentColorKey: _box.get(AppConstants.keyAccentColor, defaultValue: AppConstants.defaultAccentColor),
      customAccentHex: _box.get(AppConstants.keyCustomAccent) as String?,
      darkMode: _box.get(AppConstants.keyDarkMode, defaultValue: false),
      onboardingDone: _box.get(AppConstants.keyOnboardingDone, defaultValue: false),
      completedBlocks: _box.get(AppConstants.keyCompletedBlocks, defaultValue: 0),
      currentStreak: _box.get(AppConstants.keyCurrentStreak, defaultValue: 0),
      lastStreakDate: _box.get(AppConstants.keyLastStreakDate) as String?,
      blockedApps: List<String>.from(_box.get('blocked_apps', defaultValue: <String>[])),
      apiBaseUrl: _box.get(AppConstants.keyApiBaseUrl, defaultValue: AppConstants.apiBaseUrl) as String,
    );
  }

  Future<void> setApiBaseUrl(String url) async {
    final trimmed = url.trim().replaceAll(RegExp(r'/+$'), '');
    await _box.put(AppConstants.keyApiBaseUrl, trimmed);
    state = state.copyWith(apiBaseUrl: trimmed);
  }

  Future<void> setUnlockDuration(int minutes) async {
    await _box.put(AppConstants.keyUnlockDuration, minutes);
    state = state.copyWith(unlockDuration: minutes);
  }

  Future<void> setAlertDelay(int minutes) async {
    await _box.put(AppConstants.keyAlertDelay, minutes);
    state = state.copyWith(alertDelayMinutes: minutes);
  }

  Future<void> setDefaultMode(String mode) async {
    await _box.put(AppConstants.keyDefaultMode, mode);
    state = state.copyWith(defaultMode: mode);
  }

  Future<void> setAccentColor(String key) async {
    await _box.put(AppConstants.keyAccentColor, key);
    state = state.copyWith(accentColorKey: key);
  }

  Future<void> setCustomAccent(String hex) async {
    await _box.put(AppConstants.keyCustomAccent, hex);
    state = state.copyWith(customAccentHex: hex, accentColorKey: 'custom');
  }

  Future<void> setDarkMode(bool value) async {
    await _box.put(AppConstants.keyDarkMode, value);
    state = state.copyWith(darkMode: value);
  }

  Future<void> setOnboardingDone(bool value) async {
    await _box.put(AppConstants.keyOnboardingDone, value);
    state = state.copyWith(onboardingDone: value);
  }

  Future<void> setBlockedApps(List<String> apps) async {
    await _box.put('blocked_apps', apps);
    state = state.copyWith(blockedApps: apps);
  }

  /// Call once per completed task to update the daily streak.
  /// Returns the new streak value.
  Future<int> recordTaskCompletion() async {
    final today = DateTime.now();
    final todayStr =
        '${today.year}-${today.month.toString().padLeft(2, '0')}-${today.day.toString().padLeft(2, '0')}';

    // Mismo día: no cambia nada
    if (state.lastStreakDate == todayStr) return state.currentStreak;

    final newStreak = computeStreak(
      currentStreak: state.currentStreak,
      lastStreakDate: state.lastStreakDate,
      todayStr: todayStr,
    );

    // Es un día nuevo: resetear el contador diario de bloques
    await _box.put(AppConstants.keyCompletedBlocks, 0);
    await _box.put(AppConstants.keyCurrentStreak, newStreak);
    await _box.put(AppConstants.keyLastStreakDate, todayStr);
    state = state.copyWith(currentStreak: newStreak, lastStreakDate: todayStr, completedBlocks: 0);
    return newStreak;
  }

  Future<void> incrementCompletedBlocks() async {
    final newVal = state.completedBlocks + 1;
    await _box.put(AppConstants.keyCompletedBlocks, newVal);
    state = state.copyWith(completedBlocks: newVal);
  }

  Future<void> resetCompletedBlocks() async {
    await _box.put(AppConstants.keyCompletedBlocks, 0);
    state = state.copyWith(completedBlocks: 0);
  }
}

final settingsProvider = StateNotifierProvider<SettingsNotifier, SettingsState>(
  (ref) => SettingsNotifier(),
);

/// Calcula el nuevo valor de racha a partir del estado anterior.
/// Función pura sin efectos secundarios — fácil de testear.
///
/// - [lastStreakDate]: fecha de la última tarea completada ('yyyy-MM-dd') o null.
/// - [todayStr]: fecha de hoy en el mismo formato.
/// - [currentStreak]: valor actual de la racha.
int computeStreak({
  required int currentStreak,
  required String? lastStreakDate,
  required String todayStr,
}) {
  if (lastStreakDate == null) return 1;
  if (lastStreakDate == todayStr) return currentStreak; // ya registrado hoy
  final lastDate = DateTime.parse(lastStreakDate);
  final today = DateTime.parse(todayStr);
  final diff = today.difference(lastDate).inDays;
  return diff == 1 ? currentStreak + 1 : 1;
}
