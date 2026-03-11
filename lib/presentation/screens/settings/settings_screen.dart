import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/constants/app_constants.dart';
import '../../../services/app_blocker_service.dart';
import '../../../services/installed_apps_service.dart';
import '../../providers/settings_provider.dart';
import '../../providers/task_provider.dart';

class SettingsScreen extends ConsumerStatefulWidget {
  const SettingsScreen({super.key});

  @override
  ConsumerState<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends ConsumerState<SettingsScreen> {
  final _blocker = AppBlockerService();
  bool _accessibilityEnabled = false;
  List<InstalledApp> _installedApps = [];
  bool _loadingApps = false;

  @override
  void initState() {
    super.initState();
    _checkAccessibility();
  }

  Future<void> _checkAccessibility() async {
    final enabled = await _blocker.isAccessibilityEnabled();
    if (mounted) setState(() => _accessibilityEnabled = enabled);
  }

  Future<void> _loadApps() async {
    setState(() => _loadingApps = true);
    final apps = await InstalledAppsService.getInstalledApps();
    if (mounted) setState(() { _installedApps = apps; _loadingApps = false; });
  }

  @override
  Widget build(BuildContext context) {
    final settings = ref.watch(settingsProvider);
    final notifier = ref.read(settingsProvider.notifier);
    final accent = settings.accentColor;

    return Scaffold(
      appBar: AppBar(title: const Text('Settings')),
      body: ListView(
        padding: const EdgeInsets.symmetric(vertical: 8),
        children: [

          // ─── App Blocking ─────────────────────────────────────
          _SectionHeader(title: 'App Blocking'),
          _StatusTile(
            icon: Icons.accessibility_new_rounded,
            title: 'Accessibility Service',
            subtitle: _accessibilityEnabled ? 'Enabled' : 'Tap to enable',
            enabled: _accessibilityEnabled,
            accent: accent,
            onTap: () async {
              await _blocker.openAccessibilitySettings();
              await Future.delayed(const Duration(seconds: 2));
              await _checkAccessibility();
            },
          ),

          // Blocked apps
          ExpansionTile(
            leading: Icon(Icons.block_rounded, color: accent),
            title: const Text('Blocked Apps'),
            subtitle: Text('${settings.blockedApps.length} selected'),
            onExpansionChanged: (expanded) {
              if (expanded && _installedApps.isEmpty) _loadApps();
            },
            children: [
              if (_loadingApps)
                const Padding(
                  padding: EdgeInsets.all(20),
                  child: CircularProgressIndicator(),
                )
              else
                ..._installedApps.map((app) {
                  final selected = settings.blockedApps.contains(app.packageName);
                  return CheckboxListTile(
                    value: selected,
                    onChanged: (v) async {
                      final updated = [...settings.blockedApps];
                      if (v == true) updated.add(app.packageName);
                      else updated.remove(app.packageName);
                      await notifier.setBlockedApps(updated);
                      await _blocker.setBlockedApps(updated);
                    },
                    title: Text(app.appName, style: const TextStyle(fontSize: 14)),
                    secondary: const CircleAvatar(radius: 16, child: Icon(Icons.android_rounded, size: 16)),
                    activeColor: accent,
                    controlAffinity: ListTileControlAffinity.trailing,
                    dense: true,
                  );
                }),
            ],
          ),

          const Divider(),

          // ─── Focus Settings ───────────────────────────────────
          _SectionHeader(title: 'Focus Settings'),

          // Unlock duration
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(Icons.lock_open_rounded, color: accent, size: 20),
                    const SizedBox(width: 10),
                    const Text('Unlock Duration', style: TextStyle(fontWeight: FontWeight.w500)),
                    const Spacer(),
                    Text('${settings.unlockDuration} min',
                        style: TextStyle(color: accent, fontWeight: FontWeight.w600)),
                  ],
                ),
                Slider(
                  value: settings.unlockDuration.toDouble(),
                  min: 15,
                  max: 30,
                  divisions: 15,
                  activeColor: accent,
                  onChanged: (v) => notifier.setUnlockDuration(v.round()),
                ),
                Text('Apps unlock for ${settings.unlockDuration} minutes after every 3 completed tasks.',
                    style: Theme.of(context).textTheme.bodyMedium),
              ],
            ),
          ),

          // Alert delay
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(Icons.alarm_rounded, color: accent, size: 20),
                    const SizedBox(width: 10),
                    const Text('Alert Delay', style: TextStyle(fontWeight: FontWeight.w500)),
                    const Spacer(),
                    Text('${settings.alertDelayMinutes} min',
                        style: TextStyle(color: accent, fontWeight: FontWeight.w600)),
                  ],
                ),
                Slider(
                  value: settings.alertDelayMinutes.toDouble(),
                  min: 5,
                  max: 60,
                  divisions: 11,
                  activeColor: accent,
                  onChanged: (v) => notifier.setAlertDelay(v.round()),
                ),
                Text('Alert fires ${settings.alertDelayMinutes} min after task start if not started.',
                    style: Theme.of(context).textTheme.bodyMedium),
              ],
            ),
          ),

          // Default mode
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(children: [
                  Icon(Icons.view_list_rounded, color: accent, size: 20),
                  const SizedBox(width: 10),
                  const Text('Default Mode', style: TextStyle(fontWeight: FontWeight.w500)),
                ]),
                const SizedBox(height: 8),
                SegmentedButton<String>(
                  segments: const [
                    ButtonSegment(value: 'calendar', label: Text('Calendar'), icon: Icon(Icons.calendar_month_rounded)),
                    ButtonSegment(value: 'smart', label: Text('Smart'), icon: Icon(Icons.auto_awesome_rounded)),
                  ],
                  selected: {settings.defaultMode},
                  onSelectionChanged: (s) => notifier.setDefaultMode(s.first),
                  style: ButtonStyle(
                    backgroundColor: WidgetStateProperty.resolveWith(
                      (s) => s.contains(WidgetState.selected) ? accent : null,
                    ),
                  ),
                ),
              ],
            ),
          ),

          const Divider(),

          // ─── Appearance ───────────────────────────────────────
          _SectionHeader(title: 'Appearance'),

          // Dark mode
          SwitchListTile(
            secondary: Icon(Icons.dark_mode_rounded, color: accent),
            title: const Text('Dark Mode'),
            value: settings.darkMode,
            onChanged: (v) => notifier.setDarkMode(v),
            activeColor: accent,
          ),

          // Accent color
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(children: [
                  Icon(Icons.palette_rounded, color: accent, size: 20),
                  const SizedBox(width: 10),
                  const Text('Accent Color', style: TextStyle(fontWeight: FontWeight.w500)),
                ]),
                const SizedBox(height: 12),
                Row(
                  children: AppConstants.accentColors.entries.map((entry) {
                    final isSelected = settings.accentColorKey == entry.key;
                    return GestureDetector(
                      onTap: () => notifier.setAccentColor(entry.key),
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 200),
                        margin: const EdgeInsets.only(right: 12),
                        width: 36,
                        height: 36,
                        decoration: BoxDecoration(
                          color: entry.value,
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: isSelected ? Colors.white : Colors.transparent,
                            width: 2,
                          ),
                          boxShadow: isSelected
                              ? [BoxShadow(color: entry.value.withOpacity(0.5), blurRadius: 8)]
                              : [],
                        ),
                        child: isSelected
                            ? const Icon(Icons.check_rounded, color: Colors.white, size: 18)
                            : null,
                      ),
                    );
                  }).toList(),
                ),
              ],
            ),
          ),

          const Divider(),

          // ─── Stats ────────────────────────────────────────────
          _SectionHeader(title: 'Stats'),
          ListTile(
            leading: Icon(Icons.bar_chart_rounded, color: accent),
            title: const Text('Completed Blocks Today'),
            trailing: Text(
              '${ref.watch(settingsProvider).completedBlocks}',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: accent),
            ),
          ),
          ListTile(
            leading: Icon(Icons.task_alt_rounded, color: accent),
            title: const Text('Total Tasks'),
            trailing: Text(
              '${ref.watch(taskProvider).length}',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: accent),
            ),
          ),
          const SizedBox(height: 40),
        ],
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  final String title;
  const _SectionHeader({required this.title});

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.fromLTRB(20, 16, 20, 4),
    child: Text(title,
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w600,
          color: Theme.of(context).colorScheme.primary,
          letterSpacing: 0.8,
        )),
  );
}

class _StatusTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final bool enabled;
  final Color accent;
  final VoidCallback onTap;

  const _StatusTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.enabled,
    required this.accent,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) => ListTile(
    leading: Icon(icon, color: enabled ? Colors.green : accent),
    title: Text(title),
    subtitle: Text(subtitle, style: TextStyle(color: enabled ? Colors.green : Colors.grey)),
    trailing: enabled
        ? const Icon(Icons.check_circle_rounded, color: Colors.green)
        : const Icon(Icons.arrow_forward_ios_rounded, size: 14),
    onTap: enabled ? null : onTap,
  );
}
