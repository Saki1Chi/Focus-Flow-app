import 'package:animate_do/animate_do.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/constants/app_constants.dart';
import '../../../core/theme/app_theme.dart';
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
    if (mounted) {
      setState(() {
        _installedApps = apps;
        _loadingApps = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final settings = ref.watch(settingsProvider);
    final notifier = ref.read(settingsProvider.notifier);
    final accent   = settings.accentColor;
    final isDark   = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      body: CustomScrollView(
        physics: const BouncingScrollPhysics(),
        slivers: [
          // ── App bar ──────────────────────────────────────
          SliverAppBar(
            pinned: true,
            expandedHeight: 110,
            flexibleSpace: FlexibleSpaceBar(
              titlePadding: const EdgeInsets.fromLTRB(22, 0, 22, 14),
              title: Text('Settings',
                  style: Theme.of(context).textTheme.headlineSmall),
              collapseMode: CollapseMode.pin,
            ),
            backgroundColor: isDark ? const Color(0xFF06060F) : const Color(0xFFF3F4FF),
            surfaceTintColor: Colors.transparent,
            scrolledUnderElevation: 0,
          ),

          SliverList(
            delegate: SliverChildListDelegate([
              // ── App Blocking ────────────────────────────
              FadeInDown(
                duration: const Duration(milliseconds: 400),
                child: _SectionHeader(title: 'APP BLOCKING', accent: accent),
              ),

              FadeInDown(
                duration: const Duration(milliseconds: 420),
                delay: const Duration(milliseconds: 40),
                child: _NeonTile(
                  icon: Icons.accessibility_new_rounded,
                  title: 'Accessibility Service',
                  subtitle:
                      _accessibilityEnabled ? 'Enabled' : 'Tap to enable',
                  accent: _accessibilityEnabled
                      ? const Color(0xFF22C55E)
                      : accent,
                  isDark: isDark,
                  trailing: _accessibilityEnabled
                      ? Icon(Icons.check_circle_rounded,
                          color: const Color(0xFF22C55E), size: 20)
                      : Icon(Icons.arrow_forward_ios_rounded,
                          size: 13,
                          color: isDark
                              ? Colors.white.withValues(alpha: 0.3)
                              : Colors.black.withValues(alpha: 0.3)),
                  onTap: _accessibilityEnabled
                      ? null
                      : () async {
                          await _blocker.openAccessibilitySettings();
                          await Future.delayed(const Duration(seconds: 2));
                          await _checkAccessibility();
                        },
                ),
              ),

              FadeInDown(
                duration: const Duration(milliseconds: 440),
                delay: const Duration(milliseconds: 60),
                child: _buildExpansionTile(settings, notifier, accent, isDark),
              ),

              _Divider(isDark: isDark),

              // ── Focus Settings ──────────────────────────
              FadeInDown(
                duration: const Duration(milliseconds: 460),
                delay: const Duration(milliseconds: 80),
                child:
                    _SectionHeader(title: 'FOCUS SETTINGS', accent: accent),
              ),

              FadeInDown(
                duration: const Duration(milliseconds: 480),
                delay: const Duration(milliseconds: 100),
                child: _SliderTile(
                  icon: Icons.lock_open_rounded,
                  title: 'Unlock Duration',
                  value: settings.unlockDuration.toDouble(),
                  label: '${settings.unlockDuration} min',
                  min: 15,
                  max: 30,
                  divisions: 15,
                  hint:
                      'Apps unlock for ${settings.unlockDuration} min after every 3 completed tasks.',
                  accent: accent,
                  isDark: isDark,
                  onChanged: (v) => notifier.setUnlockDuration(v.round()),
                ),
              ),

              FadeInDown(
                duration: const Duration(milliseconds: 500),
                delay: const Duration(milliseconds: 110),
                child: _SliderTile(
                  icon: Icons.alarm_rounded,
                  title: 'Alert Delay',
                  value: settings.alertDelayMinutes.toDouble(),
                  label: '${settings.alertDelayMinutes} min',
                  min: 5,
                  max: 60,
                  divisions: 11,
                  hint:
                      'Alert fires ${settings.alertDelayMinutes} min after task start if not started.',
                  accent: accent,
                  isDark: isDark,
                  onChanged: (v) => notifier.setAlertDelay(v.round()),
                ),
              ),

              FadeInDown(
                duration: const Duration(milliseconds: 520),
                delay: const Duration(milliseconds: 120),
                child: _DefaultModeTile(
                    settings: settings, notifier: notifier, accent: accent, isDark: isDark),
              ),

              _Divider(isDark: isDark),

              // ── Appearance ──────────────────────────────
              FadeInDown(
                duration: const Duration(milliseconds: 540),
                delay: const Duration(milliseconds: 130),
                child: _SectionHeader(title: 'APPEARANCE', accent: accent),
              ),

              FadeInDown(
                duration: const Duration(milliseconds: 560),
                delay: const Duration(milliseconds: 140),
                child: _DarkModeTile(
                    settings: settings, notifier: notifier, accent: accent, isDark: isDark),
              ),

              FadeInDown(
                duration: const Duration(milliseconds: 580),
                delay: const Duration(milliseconds: 150),
                child: _AccentColorTile(
                    settings: settings, notifier: notifier, isDark: isDark),
              ),

              _Divider(isDark: isDark),

              // ── Stats ───────────────────────────────────
              FadeInDown(
                duration: const Duration(milliseconds: 600),
                delay: const Duration(milliseconds: 160),
                child: _SectionHeader(title: 'STATS', accent: accent),
              ),

              FadeInDown(
                duration: const Duration(milliseconds: 620),
                delay: const Duration(milliseconds: 170),
                child: _StatTile(
                  icon: Icons.bar_chart_rounded,
                  title: 'Completed Blocks Today',
                  value: '${ref.watch(settingsProvider).completedBlocks}',
                  accent: accent,
                  isDark: isDark,
                ),
              ),
              FadeInDown(
                duration: const Duration(milliseconds: 640),
                delay: const Duration(milliseconds: 180),
                child: _StatTile(
                  icon: Icons.task_alt_rounded,
                  title: 'Total Tasks',
                  value: '${ref.watch(taskProvider).length}',
                  accent: accent,
                  isDark: isDark,
                ),
              ),

              const SizedBox(height: 120),
            ]),
          ),
        ],
      ),
    );
  }

  Widget _buildExpansionTile(
      settings, notifier, Color accent, bool isDark) {
    final bg     = isDark ? const Color(0xFF0E0E1C) : Colors.white;
    final border = isDark
        ? Colors.white.withValues(alpha: 0.07)
        : Colors.black.withValues(alpha: 0.06);

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: border, width: 1),
        boxShadow: isDark ? NeonColors.crystalCard() : NeonColors.lightCard(),
      ),
      child: ExpansionTile(
        leading: Icon(Icons.block_rounded, color: accent, size: 20),
        title: Text('Blocked Apps',
            style: Theme.of(context).textTheme.titleMedium),
        subtitle: Text('${settings.blockedApps.length} selected',
            style: Theme.of(context).textTheme.bodyMedium),
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(18)),
        collapsedShape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(18)),
        onExpansionChanged: (expanded) {
          if (expanded && _installedApps.isEmpty) _loadApps();
        },
        children: [
          if (_loadingApps)
            const Padding(
                padding: EdgeInsets.all(20),
                child: CircularProgressIndicator())
          else
            ..._installedApps.map((app) {
              final selected =
                  settings.blockedApps.contains(app.packageName);
              return CheckboxListTile(
                value: selected,
                onChanged: (v) async {
                  final updated = <String>[...settings.blockedApps];
                  if (v == true) updated.add(app.packageName);
                  else updated.remove(app.packageName);
                  await notifier.setBlockedApps(updated);
                  await _blocker.setBlockedApps(updated);
                },
                title: Text(app.appName,
                    style: const TextStyle(fontSize: 13)),
                secondary: const CircleAvatar(
                    radius: 14,
                    child: Icon(Icons.android_rounded, size: 14)),
                activeColor: accent,
                controlAffinity: ListTileControlAffinity.trailing,
                dense: true,
              );
            }),
        ],
      ),
    );
  }
}

// ── Section header ─────────────────────────────────────────────

class _SectionHeader extends StatelessWidget {
  final String title;
  final Color accent;
  const _SectionHeader({required this.title, required this.accent});

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.fromLTRB(22, 22, 22, 8),
        child: Row(
          children: [
            Container(
              width: 3,
              height: 12,
              decoration: BoxDecoration(
                color: accent,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(width: 8),
            Text(
              title,
              style: TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w800,
                color: accent,
                letterSpacing: 1.2,
              ),
            ),
          ],
        ),
      );
}

// ── Divider ────────────────────────────────────────────────────

class _Divider extends StatelessWidget {
  final bool isDark;
  const _Divider({required this.isDark});

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 6),
        child: Divider(
          color: isDark
              ? Colors.white.withValues(alpha: 0.06)
              : Colors.black.withValues(alpha: 0.06),
          height: 1,
        ),
      );
}

// ── Neon tile ──────────────────────────────────────────────────

class _NeonTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final Color accent;
  final bool isDark;
  final Widget trailing;
  final VoidCallback? onTap;

  const _NeonTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.accent,
    required this.isDark,
    required this.trailing,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final bg     = isDark ? const Color(0xFF0E0E1C) : Colors.white;
    final border = isDark
        ? Colors.white.withValues(alpha: 0.07)
        : Colors.black.withValues(alpha: 0.06);

    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: border, width: 1),
          boxShadow: isDark ? NeonColors.crystalCard() : NeonColors.lightCard(),
        ),
        child: Row(
          children: [
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: accent.withValues(alpha: 0.10),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(icon, color: accent, size: 18),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: Theme.of(context).textTheme.titleMedium),
                  const SizedBox(height: 2),
                  Text(subtitle,
                      style: Theme.of(context).textTheme.bodyMedium),
                ],
              ),
            ),
            trailing,
          ],
        ),
      ),
    );
  }
}

// ── Slider tile ────────────────────────────────────────────────

class _SliderTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final double value;
  final String label;
  final double min, max;
  final int divisions;
  final String hint;
  final Color accent;
  final bool isDark;
  final ValueChanged<double> onChanged;

  const _SliderTile({
    required this.icon,
    required this.title,
    required this.value,
    required this.label,
    required this.min,
    required this.max,
    required this.divisions,
    required this.hint,
    required this.accent,
    required this.isDark,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final bg     = isDark ? const Color(0xFF0E0E1C) : Colors.white;
    final border = isDark
        ? Colors.white.withValues(alpha: 0.07)
        : Colors.black.withValues(alpha: 0.06);

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 10),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: border, width: 1),
        boxShadow: isDark ? NeonColors.crystalCard() : NeonColors.lightCard(),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: accent.withValues(alpha: 0.10),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(icon, color: accent, size: 18),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(title,
                  style: Theme.of(context).textTheme.titleMedium),
            ),
            Text(label,
                style: TextStyle(
                    color: accent,
                    fontSize: 13,
                    fontWeight: FontWeight.w700)),
          ]),
          SliderTheme(
            data: SliderThemeData(
              activeTrackColor: accent,
              inactiveTrackColor: isDark
                  ? Colors.white.withValues(alpha: 0.08)
                  : Colors.black.withValues(alpha: 0.08),
              thumbColor: accent,
              overlayColor: accent.withValues(alpha: 0.14),
              thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 7),
              trackHeight: 3,
            ),
            child: Slider(
                value: value,
                min: min,
                max: max,
                divisions: divisions,
                onChanged: onChanged),
          ),
          Padding(
            padding: const EdgeInsets.only(left: 2),
            child: Text(hint,
                style: Theme.of(context).textTheme.bodyMedium),
          ),
        ],
      ),
    );
  }
}

// ── Default mode tile ──────────────────────────────────────────

class _DefaultModeTile extends StatelessWidget {
  final dynamic settings;
  final dynamic notifier;
  final Color accent;
  final bool isDark;
  const _DefaultModeTile(
      {required this.settings,
      required this.notifier,
      required this.accent,
      required this.isDark});

  @override
  Widget build(BuildContext context) {
    final bg     = isDark ? const Color(0xFF0E0E1C) : Colors.white;
    final border = isDark
        ? Colors.white.withValues(alpha: 0.07)
        : Colors.black.withValues(alpha: 0.06);

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: border, width: 1),
        boxShadow: isDark ? NeonColors.crystalCard() : NeonColors.lightCard(),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: accent.withValues(alpha: 0.10),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(Icons.view_list_rounded, color: accent, size: 18),
            ),
            const SizedBox(width: 12),
            Text('Default Mode',
                style: Theme.of(context).textTheme.titleMedium),
          ]),
          const SizedBox(height: 12),
          SegmentedButton<String>(
            segments: const [
              ButtonSegment(
                value: 'calendar',
                label: Text('Calendar'),
                icon: Icon(Icons.calendar_month_rounded, size: 15),
              ),
              ButtonSegment(
                value: 'smart',
                label: Text('Smart'),
                icon: Icon(Icons.auto_awesome_rounded, size: 15),
              ),
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
    );
  }
}

// ── Dark mode tile ─────────────────────────────────────────────

class _DarkModeTile extends StatelessWidget {
  final dynamic settings;
  final dynamic notifier;
  final Color accent;
  final bool isDark;
  const _DarkModeTile(
      {required this.settings,
      required this.notifier,
      required this.accent,
      required this.isDark});

  @override
  Widget build(BuildContext context) {
    final bg     = isDark ? const Color(0xFF0E0E1C) : Colors.white;
    final border = isDark
        ? Colors.white.withValues(alpha: 0.07)
        : Colors.black.withValues(alpha: 0.06);

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: border, width: 1),
        boxShadow: isDark ? NeonColors.crystalCard() : NeonColors.lightCard(),
      ),
      child: SwitchListTile(
        secondary: Container(
          width: 36,
          height: 36,
          decoration: BoxDecoration(
            color: accent.withValues(alpha: 0.10),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(Icons.dark_mode_rounded, color: accent, size: 18),
        ),
        title: Text('Dark Mode',
            style: Theme.of(context).textTheme.titleMedium),
        value: settings.darkMode,
        onChanged: (v) => notifier.setDarkMode(v),
        activeColor: accent,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      ),
    );
  }
}

// ── Accent color tile ──────────────────────────────────────────

class _AccentColorTile extends StatelessWidget {
  final dynamic settings;
  final dynamic notifier;
  final bool isDark;
  const _AccentColorTile(
      {required this.settings, required this.notifier, required this.isDark});

  @override
  Widget build(BuildContext context) {
    final bg     = isDark ? const Color(0xFF0E0E1C) : Colors.white;
    final border = isDark
        ? Colors.white.withValues(alpha: 0.07)
        : Colors.black.withValues(alpha: 0.06);

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: border, width: 1),
        boxShadow: isDark ? NeonColors.crystalCard() : NeonColors.lightCard(),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: settings.accentColor.withValues(alpha: 0.10),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(Icons.palette_rounded,
                  color: settings.accentColor, size: 18),
            ),
            const SizedBox(width: 12),
            Text('Accent Color',
                style: Theme.of(context).textTheme.titleMedium),
          ]),
          const SizedBox(height: 16),
          Row(
            children: AppConstants.accentColors.entries.map((entry) {
              final isSelected = settings.accentColorKey == entry.key;
              return GestureDetector(
                onTap: () => notifier.setAccentColor(entry.key),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 240),
                  curve: Curves.easeOutCubic,
                  margin: const EdgeInsets.only(right: 12),
                  width: isSelected ? 40 : 36,
                  height: isSelected ? 40 : 36,
                  decoration: BoxDecoration(
                    color: entry.value,
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: isSelected ? Colors.white : Colors.transparent,
                      width: 2.5,
                    ),
                    boxShadow: isSelected
                        ? NeonColors.glow(entry.value, intensity: 1.2)
                        : null,
                  ),
                  child: isSelected
                      ? const Icon(Icons.check_rounded,
                          color: Colors.white, size: 18)
                      : null,
                ),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }
}

// ── Stat tile ──────────────────────────────────────────────────

class _StatTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final String value;
  final Color accent;
  final bool isDark;

  const _StatTile({
    required this.icon,
    required this.title,
    required this.value,
    required this.accent,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    final bg     = isDark ? const Color(0xFF0E0E1C) : Colors.white;
    final border = isDark
        ? Colors.white.withValues(alpha: 0.07)
        : Colors.black.withValues(alpha: 0.06);

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: border, width: 1),
        boxShadow: isDark ? NeonColors.crystalCard() : NeonColors.lightCard(),
      ),
      child: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: accent.withValues(alpha: 0.10),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: accent, size: 18),
          ),
          const SizedBox(width: 14),
          Expanded(
              child: Text(title,
                  style: Theme.of(context).textTheme.titleMedium)),
          Container(
            padding:
                const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
            decoration: BoxDecoration(
              color: accent.withValues(alpha: 0.10),
              borderRadius: BorderRadius.circular(12),
              border:
                  Border.all(color: accent.withValues(alpha: 0.22), width: 1),
              boxShadow:
                  isDark ? NeonColors.softGlow(accent) : null,
            ),
            child: Text(
              value,
              style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w800,
                  color: accent),
            ),
          ),
        ],
      ),
    );
  }
}
