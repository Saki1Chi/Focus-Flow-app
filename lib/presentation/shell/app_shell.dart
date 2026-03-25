import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/settings_provider.dart';
import '../screens/home/home_screen.dart';
import '../screens/calendar/calendar_screen.dart';
import '../screens/smart_mode/smart_mode_screen.dart';
import '../screens/settings/settings_screen.dart';
import '../screens/calendar/add_task_screen.dart';

final _navIndexProvider = StateProvider<int>((ref) => 0);

class AppShell extends ConsumerWidget {
  const AppShell({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final index  = ref.watch(_navIndexProvider);
    final accent = ref.watch(settingsProvider).accentColor;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    const screens = [
      HomeScreen(),
      CalendarScreen(),
      SmartModeScreen(),
      SettingsScreen(),
    ];

    return Scaffold(
      extendBody: true,
      body: IndexedStack(index: index, children: screens),
      floatingActionButton: (index == 0 || index == 1)
          ? _NeonFAB(
              key: ValueKey('fab_$index'),
              accent: accent,
              onPressed: () => _openAddTask(context, ref),
            )
          : null,
      floatingActionButtonLocation: FloatingActionButtonLocation.endFloat,
      bottomNavigationBar: _FloatingNavBar(
        index: index,
        accent: accent,
        isDark: isDark,
        onTap: (i) => ref.read(_navIndexProvider.notifier).state = i,
      ),
    );
  }

  void _openAddTask(BuildContext context, WidgetRef ref) {
    Navigator.push(
      context,
      PageRouteBuilder(
        pageBuilder: (_, anim, __) => const AddTaskScreen(),
        transitionsBuilder: (_, anim, __, child) {
          return SlideTransition(
            position: Tween<Offset>(
              begin: const Offset(0, 1),
              end: Offset.zero,
            ).animate(CurvedAnimation(parent: anim, curve: Curves.easeOutQuart)),
            child: FadeTransition(
              opacity: CurvedAnimation(
                  parent: anim, curve: const Interval(0, 0.55)),
              child: child,
            ),
          );
        },
        transitionDuration: const Duration(milliseconds: 420),
      ),
    );
  }
}

// ── FAB with elastic entrance animation ────────────────────────

class _NeonFAB extends StatefulWidget {
  final Color accent;
  final VoidCallback onPressed;
  const _NeonFAB({super.key, required this.accent, required this.onPressed});

  @override
  State<_NeonFAB> createState() => _NeonFABState();
}

class _NeonFABState extends State<_NeonFAB>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  late final Animation<double> _scale;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 650));
    _scale = CurvedAnimation(parent: _ctrl, curve: Curves.elasticOut);
    _ctrl.forward();
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ScaleTransition(
      scale: _scale,
      child: Container(
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          boxShadow: [
            BoxShadow(
              color: widget.accent.withValues(alpha: 0.55),
              blurRadius: 24,
              spreadRadius: -2,
            ),
            BoxShadow(
              color: widget.accent.withValues(alpha: 0.22),
              blurRadius: 48,
              spreadRadius: -8,
            ),
          ],
        ),
        child: FloatingActionButton(
          onPressed: widget.onPressed,
          backgroundColor: widget.accent,
          foregroundColor: Colors.white,
          elevation: 0,
          highlightElevation: 0,
          child: const Icon(Icons.add_rounded, size: 28),
        ),
      ),
    );
  }
}

// ── Floating glassmorphism bottom nav ──────────────────────────

class _FloatingNavBar extends StatelessWidget {
  final int index;
  final Color accent;
  final bool isDark;
  final ValueChanged<int> onTap;

  const _FloatingNavBar({
    required this.index,
    required this.accent,
    required this.isDark,
    required this.onTap,
  });

  static const _items = [
    (
      icon: Icons.home_outlined,
      active: Icons.home_rounded,
      label: 'Home'
    ),
    (
      icon: Icons.calendar_month_outlined,
      active: Icons.calendar_month_rounded,
      label: 'Calendar'
    ),
    (
      icon: Icons.auto_awesome_outlined,
      active: Icons.auto_awesome_rounded,
      label: 'Smart'
    ),
    (
      icon: Icons.settings_outlined,
      active: Icons.settings_rounded,
      label: 'Settings'
    ),
  ];

  @override
  Widget build(BuildContext context) {
    final bg = isDark
        ? Colors.black.withValues(alpha: 0.72)
        : Colors.white.withValues(alpha: 0.90);
    final borderColor = isDark
        ? Colors.white.withValues(alpha: 0.08)
        : Colors.black.withValues(alpha: 0.06);

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 14),
      child: SafeArea(
        top: false,
        child: ClipRRect(
          borderRadius: BorderRadius.circular(30),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 26, sigmaY: 26),
            child: Container(
              height: 62,
              decoration: BoxDecoration(
                color: bg,
                borderRadius: BorderRadius.circular(30),
                border: Border.all(color: borderColor, width: 1),
                boxShadow: isDark
                    ? [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.55),
                          blurRadius: 32,
                          offset: const Offset(0, 12),
                        )
                      ]
                    : [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.09),
                          blurRadius: 24,
                          offset: const Offset(0, 8),
                        )
                      ],
              ),
              child: Row(
                children: List.generate(_items.length, (i) {
                  final selected = i == index;
                  final item = _items[i];
                  final color = selected
                      ? accent
                      : (isDark
                          ? const Color(0xFF363650)
                          : const Color(0xFFB0B0C8));

                  return Expanded(
                    child: GestureDetector(
                      onTap: () => onTap(i),
                      behavior: HitTestBehavior.opaque,
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          AnimatedContainer(
                            duration: const Duration(milliseconds: 240),
                            curve: Curves.easeOutCubic,
                            padding: const EdgeInsets.symmetric(
                                horizontal: 14, vertical: 5),
                            decoration: BoxDecoration(
                              color: selected
                                  ? accent.withValues(alpha: 0.14)
                                  : Colors.transparent,
                              borderRadius: BorderRadius.circular(18),
                              boxShadow: selected
                                  ? [
                                      BoxShadow(
                                        color: accent.withValues(alpha: 0.24),
                                        blurRadius: 12,
                                        spreadRadius: -2,
                                      )
                                    ]
                                  : null,
                            ),
                            child: Icon(
                              selected ? item.active : item.icon,
                              color: color,
                              size: 21,
                            ),
                          ),
                          const SizedBox(height: 1),
                          AnimatedDefaultTextStyle(
                            duration: const Duration(milliseconds: 240),
                            style: TextStyle(
                              fontSize: 9.5,
                              fontWeight: selected
                                  ? FontWeight.w700
                                  : FontWeight.w400,
                              color: color,
                              letterSpacing: 0.2,
                            ),
                            child: Text(item.label),
                          ),
                        ],
                      ),
                    ),
                  );
                }),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
