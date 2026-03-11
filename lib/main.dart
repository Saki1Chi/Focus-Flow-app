import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'core/constants/app_constants.dart';
import 'core/theme/app_theme.dart';
import 'presentation/providers/settings_provider.dart';
import 'presentation/screens/onboarding/onboarding_screen.dart';
import 'presentation/shell/app_shell.dart';
import 'services/alarm_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Init Hive
  await Hive.initFlutter();
  await Hive.openBox<String>(AppConstants.tasksBox);
  await Hive.openBox<String>(AppConstants.blockSessionsBox);
  await Hive.openBox(AppConstants.settingsBox);

  // Init alarm & notifications
  await AlarmService().init();

  runApp(const ProviderScope(child: FocusFlowApp()));
}

class FocusFlowApp extends ConsumerWidget {
  const FocusFlowApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(settingsProvider);
    final accent = settings.accentColor;

    return MaterialApp(
      title: AppConstants.appName,
      debugShowCheckedModeBanner: false,
      theme: AppTheme.lightTheme(accent),
      darkTheme: AppTheme.darkTheme(accent),
      themeMode: settings.darkMode ? ThemeMode.dark : ThemeMode.light,
      home: settings.onboardingDone ? const AppShell() : const OnboardingScreen(),
    );
  }
}
