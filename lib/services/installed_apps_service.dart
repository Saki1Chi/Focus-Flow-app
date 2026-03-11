import 'package:flutter/services.dart';

class InstalledApp {
  final String packageName;
  final String appName;
  const InstalledApp({required this.packageName, required this.appName});
}

class InstalledAppsService {
  static const _channel = MethodChannel('com.example.calendario/app_blocker');

  static Future<List<InstalledApp>> getInstalledApps() async {
    try {
      final result = await _channel.invokeMethod<List>('getInstalledApps');
      if (result == null) return [];
      return result
          .cast<Map>()
          .map((m) => InstalledApp(
                packageName: m['packageName'] as String,
                appName: m['appName'] as String,
              ))
          .toList();
    } catch (_) {
      return [];
    }
  }
}
