import 'package:animate_do/animate_do.dart';
import 'package:flutter/material.dart';
import 'package:flutter_colorpicker/flutter_colorpicker.dart';
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

              _Divider(isDark: isDark),

              // ── Server Sync ─────────────────────────────
              FadeInDown(
                duration: const Duration(milliseconds: 660),
                delay: const Duration(milliseconds: 190),
                child: _SectionHeader(title: 'SERVER SYNC', accent: accent),
              ),

              FadeInDown(
                duration: const Duration(milliseconds: 680),
                delay: const Duration(milliseconds: 200),
                child: _SyncTile(accent: accent, isDark: isDark),
              ),

              FadeInDown(
                delay: const Duration(milliseconds: 200),
                child: _PullTile(accent: accent, isDark: isDark),
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

class _NeonTile extends StatefulWidget {
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
  State<_NeonTile> createState() => _NeonTileState();
}

class _NeonTileState extends State<_NeonTile>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  late final Animation<double> _scale;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 80),
      reverseDuration: const Duration(milliseconds: 180),
    );
    _scale = Tween<double>(begin: 1.0, end: 0.97).animate(
      CurvedAnimation(parent: _ctrl, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final bg     = widget.isDark ? const Color(0xFF0E0E1C) : Colors.white;
    final border = widget.isDark
        ? Colors.white.withValues(alpha: 0.07)
        : Colors.black.withValues(alpha: 0.06);

    return GestureDetector(
      onTapDown: widget.onTap != null ? (_) => _ctrl.forward() : null,
      onTapUp: widget.onTap != null
          ? (_) {
              _ctrl.reverse();
              widget.onTap!();
            }
          : null,
      onTapCancel: widget.onTap != null ? () => _ctrl.reverse() : null,
      child: ScaleTransition(
        scale: _scale,
        child: Container(
          margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          decoration: BoxDecoration(
            color: bg,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: border, width: 1),
            boxShadow:
                widget.isDark ? NeonColors.crystalCard() : NeonColors.lightCard(),
          ),
          child: Row(
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: widget.accent.withValues(alpha: 0.10),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(widget.icon, color: widget.accent, size: 18),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(widget.title,
                        style: Theme.of(context).textTheme.titleMedium),
                    const SizedBox(height: 2),
                    Text(widget.subtitle,
                        style: Theme.of(context).textTheme.bodyMedium),
                  ],
                ),
              ),
              widget.trailing,
            ],
          ),
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
    final customHex = settings.customAccentHex ??
        settings.accentColor.value.toRadixString(16).padLeft(8, '0').toUpperCase();
    final presets = AppConstants.accentColors.entries
        .where((e) => e.key != 'custom')
        .toList();

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
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              ...presets.map((entry) {
                final isSelected = settings.accentColorKey == entry.key;
                return GestureDetector(
                  onTap: () => notifier.setAccentColor(entry.key),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    width: isSelected ? 44 : 38,
                    height: isSelected ? 44 : 38,
                    decoration: BoxDecoration(
                      color: entry.value,
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: isSelected ? Colors.white : Colors.transparent,
                        width: 2,
                      ),
                    ),
                    child: isSelected
                        ? const Icon(Icons.check_rounded,
                            color: Colors.white, size: 18)
                        : null,
                  ),
                );
              }),
              GestureDetector(
                onTap: () async {
                  Color temp = settings.accentColor;
                  final controller = TextEditingController(text: '#${customHex.substring(2)}');
                  await showModalBottomSheet(
                    context: context,
                    isScrollControlled: true,
                    backgroundColor: Theme.of(context).colorScheme.surface,
                    shape: const RoundedRectangleBorder(
                        borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
                    builder: (ctx) {
                      return StatefulBuilder(
                        builder: (ctx, setSheetState) {
                          void updateFromColor(Color c) {
                            temp = c;
                            final hex = c.value.toRadixString(16).padLeft(8, '0').substring(2).toUpperCase();
                            controller.value = TextEditingValue(
                              text: '#$hex',
                              selection: TextSelection.collapsed(offset: hex.length + 1),
                            );
                            setSheetState(() {});
                          }

                          void updateFromText(String v) {
                            final cleaned = v.replaceAll('#', '').replaceAll('0x', '');
                            if (cleaned.length == 6 || cleaned.length == 8) {
                              temp = Color(int.parse(
                                  cleaned.length == 6 ? 'FF$cleaned' : cleaned,
                                  radix: 16));
                              setSheetState(() {});
                            }
                          }

                          return SafeArea(
                            child: SingleChildScrollView(
                              padding: EdgeInsets.only(
                                left: 16,
                                right: 16,
                                top: 18,
                                bottom: 16 + MediaQuery.of(context).viewInsets.bottom,
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text('Custom accent color',
                                      style: Theme.of(context).textTheme.titleMedium),
                                  const SizedBox(height: 14),
                                  SizedBox(
                                    height: 240,
                                    child: ColorPicker(
                                      pickerColor: temp,
                                      onColorChanged: updateFromColor,
                                      paletteType: PaletteType.hsvWithHue,
                                      enableAlpha: false,
                                      labelTypes: const [],
                                      portraitOnly: true,
                                    ),
                                  ),
                                  const SizedBox(height: 12),
                                  TextField(
                                    controller: controller,
                                    decoration: const InputDecoration(
                                      labelText: 'Hex color (e.g. #3B82F6)',
                                    ),
                                    onChanged: updateFromText,
                                  ),
                                  const SizedBox(height: 14),
                                  Row(
                                    mainAxisAlignment: MainAxisAlignment.end,
                                    children: [
                                      TextButton(
                                          onPressed: () => Navigator.pop(ctx),
                                          child: const Text('Cancel')),
                                      const SizedBox(width: 8),
                                      ElevatedButton(
                                        onPressed: () async {
                                          final hex = controller.text.replaceAll('#', '').replaceAll('0x', '');
                                          if (hex.isEmpty) return;
                                          final saveHex = hex.length == 6 ? 'FF$hex' : hex;
                                          await notifier.setCustomAccent(saveHex);
                                          Navigator.pop(ctx);
                                        },
                                        child: const Text('Use'),
                                      ),
                                    ],
                                  )
                                ],
                              ),
                            ),
                          );
                        },
                      );
                    },
                  );
                },
                child: Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: settings.accentColorKey == 'custom'
                        ? settings.accentColor
                        : Colors.transparent,
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: settings.accentColorKey == 'custom'
                          ? Colors.white
                          : Theme.of(context).dividerColor,
                      width: 2,
                    ),
                  ),
                  child: Icon(
                    Icons.add_rounded,
                    color: settings.accentColorKey == 'custom'
                        ? Colors.white
                        : Theme.of(context).colorScheme.onSurface,
                  ),
                ),
              ),
            ],
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

// ── Sync tile ───────────────────────────────────────────────────

class _SyncTile extends ConsumerStatefulWidget {
  final Color accent;
  final bool isDark;
  const _SyncTile({required this.accent, required this.isDark});

  @override // otro cambio
  ConsumerState<_SyncTile> createState() => _SyncTileState();
}

// ─── Pull tile ──────────────────────────────────────────────────────
//otro cambio
class _PullTile extends ConsumerStatefulWidget {
  final Color accent;
  final bool isDark;
  const _PullTile({required this.accent, required this.isDark});

  @override
  ConsumerState<_PullTile> createState() => _PullTileState();
}

class _PullTileState extends ConsumerState<_PullTile> {
  bool _loading = false;
  String? _lastResult;

  Future<void> _pull() async {
    setState(() { _loading = true; _lastResult = null; });
    try {
      await ref.read(taskProvider.notifier).refreshFromServer();
      setState(() => _lastResult = 'Tareas descargadas del panel');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Sincronizado con el panel')),
        );
      }
    } catch (e) {
      setState(() => _lastResult = 'Error: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error al sincronizar: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final bg     = widget.isDark ? const Color(0xFF0E0E1C) : Colors.white;
    final border = widget.isDark
        ? Colors.white.withValues(alpha: 0.07)
        : Colors.black.withValues(alpha: 0.06);
    final subColor = widget.isDark ? const Color(0xFF484862) : const Color(0xFF9898B8);
    final taskCount = ref.watch(taskProvider).length;

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: border, width: 1),
        boxShadow: widget.isDark ? NeonColors.crystalCard() : NeonColors.lightCard(),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: widget.accent.withValues(alpha: 0.10),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(Icons.download_rounded, color: widget.accent, size: 18),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Pull from Server',
                        style: Theme.of(context).textTheme.titleMedium),
                    const SizedBox(height: 2),
                    Text(
                      'Descarga tareas del panel y reemplaza las locales ($taskCount actuales)',
                      style: TextStyle(fontSize: 11, color: subColor),
                    ),
                  ],
                ),
              ),
            ],
          ),
          if (_lastResult != null) ...[
            const SizedBox(height: 10),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: _lastResult!.startsWith('Error')
                    ? const Color(0xFFEF4444).withValues(alpha: 0.10)
                    : const Color(0xFF22C55E).withValues(alpha: 0.10),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                  color: _lastResult!.startsWith('Error')
                      ? const Color(0xFFEF4444).withValues(alpha: 0.25)
                      : const Color(0xFF22C55E).withValues(alpha: 0.25),
                ),
              ),
              child: Text(
                _lastResult!,
                style: TextStyle(
                  fontSize: 12,
                  color: _lastResult!.startsWith('Error')
                      ? const Color(0xFFEF4444)
                      : const Color(0xFF22C55E),
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: _loading ? null : _pull,
              icon: _loading
                  ? SizedBox(
                      width: 14,
                      height: 14,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: widget.accent,
                      ),
                    )
                  : const Icon(Icons.download_outlined, size: 16),
              label: Text(_loading ? 'Cargando…' : 'Traer tareas'),
              style: ElevatedButton.styleFrom(
                backgroundColor: widget.accent.withValues(alpha: 0.12),
                foregroundColor: widget.accent,
                elevation: 0,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                side: BorderSide(color: widget.accent.withValues(alpha: 0.25)),
                textStyle: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700),
              ),
            ),
          ),
        ],
      ),
    );
  }
} // aqui termina el cambio


class _SyncTileState extends ConsumerState<_SyncTile> {
  bool _syncing = false;
  String? _lastResult;

  Future<void> _sync() async {
    setState(() { _syncing = true; _lastResult = null; });
    try {
      final result = await ref.read(taskProvider.notifier).syncWithServer();
      setState(() => _lastResult =
          'Synced: ${result['created']} created, ${result['updated']} updated');
    } catch (e) {
      setState(() => _lastResult = 'Error: $e');
    } finally {
      setState(() => _syncing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final bg     = widget.isDark ? const Color(0xFF0E0E1C) : Colors.white;
    final border = widget.isDark
        ? Colors.white.withValues(alpha: 0.07)
        : Colors.black.withValues(alpha: 0.06);
    final subColor = widget.isDark ? const Color(0xFF484862) : const Color(0xFF9898B8);
    final taskCount = ref.watch(taskProvider).length;

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: border, width: 1),
        boxShadow: widget.isDark ? NeonColors.crystalCard() : NeonColors.lightCard(),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: widget.accent.withValues(alpha: 0.10),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(Icons.cloud_sync_rounded, color: widget.accent, size: 18),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Sync with Server',
                        style: Theme.of(context).textTheme.titleMedium),
                    const SizedBox(height: 2),
                    Text(
                      'Push $taskCount local tasks to CMS',
                      style: TextStyle(fontSize: 11, color: subColor),
                    ),
                  ],
                ),
              ),
            ],
          ),
          if (_lastResult != null) ...[
            const SizedBox(height: 10),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: _lastResult!.startsWith('Error')
                    ? const Color(0xFFEF4444).withValues(alpha: 0.10)
                    : const Color(0xFF22C55E).withValues(alpha: 0.10),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                  color: _lastResult!.startsWith('Error')
                      ? const Color(0xFFEF4444).withValues(alpha: 0.25)
                      : const Color(0xFF22C55E).withValues(alpha: 0.25),
                ),
              ),
              child: Text(
                _lastResult!,
                style: TextStyle(
                  fontSize: 12,
                  color: _lastResult!.startsWith('Error')
                      ? const Color(0xFFEF4444)
                      : const Color(0xFF22C55E),
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: _syncing ? null : _sync,
              icon: _syncing
                  ? SizedBox(
                      width: 14,
                      height: 14,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: widget.accent,
                      ),
                    )
                  : const Icon(Icons.cloud_upload_outlined, size: 16),
              label: Text(_syncing ? 'Syncing…' : 'Sync Now'),
              style: ElevatedButton.styleFrom(
                backgroundColor: widget.accent.withValues(alpha: 0.12),
                foregroundColor: widget.accent,
                elevation: 0,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                side: BorderSide(color: widget.accent.withValues(alpha: 0.25)),
                textStyle: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
