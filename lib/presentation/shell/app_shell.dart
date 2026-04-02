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
    final reduceMotion = MediaQuery.of(context).disableAnimations;

    const screens = [
      HomeScreen(),
      CalendarScreen(),
      SmartModeScreen(),
      SettingsScreen(),
    ];

    return Scaffold(
      extendBody: true,
      body: Stack(
        children: List.generate(screens.length, (i) {
          final isActive = i == index;
          return IgnorePointer(
            ignoring: !isActive,
            child: AnimatedOpacity(
              duration: reduceMotion ? Duration.zero : const Duration(milliseconds: 220),
              curve: Curves.easeOutCubic,
              opacity: isActive ? 1.0 : 0.0,
              child: AnimatedSlide(
                duration: reduceMotion ? Duration.zero : const Duration(milliseconds: 260),
                curve: Curves.easeOutCubic,
                offset: isActive ? Offset.zero : const Offset(0.04, 0),
                child: TickerMode(
                  enabled: isActive,
                  child: screens[i],
                ),
              ),
            ),
          );
        }),
      ),
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
        pageBuilder: (context, anim, secondaryAnim) => const AddTaskScreen(),
        transitionsBuilder: (context, anim, secondaryAnim, child) {
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

// ── FAB con animación de entrada elástica + respiración ────────

class _NeonFAB extends StatefulWidget {
  final Color accent;
  final VoidCallback onPressed;
  const _NeonFAB({super.key, required this.accent, required this.onPressed});

  @override
  State<_NeonFAB> createState() => _NeonFABState();
}

class _NeonFABState extends State<_NeonFAB>
    with TickerProviderStateMixin {
  late final AnimationController _entranceCtrl;
  late final AnimationController _breatheCtrl;
  late final Animation<double> _entranceScale;
  late final Animation<double> _breatheScale;
  late final Animation<double> _glowPulse;

  @override
  void initState() {
    super.initState();
    _entranceCtrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 650));
    _breatheCtrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 2200));

    _entranceScale = CurvedAnimation(
        parent: _entranceCtrl, curve: Curves.elasticOut);
    _breatheScale = Tween<double>(begin: 1.0, end: 1.07).animate(
      CurvedAnimation(parent: _breatheCtrl, curve: Curves.easeInOut),
    );
    _glowPulse = Tween<double>(begin: 0.5, end: 1.0).animate(
      CurvedAnimation(parent: _breatheCtrl, curve: Curves.easeInOut),
    );

    _entranceCtrl.forward().then((_) {
      if (mounted) _breatheCtrl.repeat(reverse: true);
    });
  }

  @override
  void dispose() {
    _entranceCtrl.dispose();
    _breatheCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ScaleTransition(
      scale: _entranceScale,
      child: AnimatedBuilder(
        animation: _breatheCtrl,
        builder: (_, child) => Transform.scale(
          scale: _breatheScale.value,
          child: Container(
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: widget.accent.withValues(alpha: 0.55 * _glowPulse.value),
                  blurRadius: 28,
                  spreadRadius: -2,
                ),
                BoxShadow(
                  color: widget.accent.withValues(alpha: 0.20 * _glowPulse.value),
                  blurRadius: 52,
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
              height: 66,
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
                            duration: const Duration(milliseconds: 260),
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
                            child: AnimatedScale(
                              scale: selected ? 1.12 : 1.0,
                              duration: const Duration(milliseconds: 220),
                              curve: Curves.easeOutBack,
                              child: Icon(
                                selected ? item.active : item.icon,
                                color: color,
                                size: 21,
                              ),
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
                          const SizedBox(height: 3),
                          // Indicador deslizante bajo el ítem activo
                          AnimatedContainer(
                            duration: const Duration(milliseconds: 280),
                            curve: Curves.easeOutBack,
                            width: selected ? 18 : 0,
                            height: 3,
                            decoration: BoxDecoration(
                              color: accent,
                              borderRadius: BorderRadius.circular(2),
                              boxShadow: selected
                                  ? [
                                      BoxShadow(
                                        color: accent.withValues(alpha: 0.65),
                                        blurRadius: 6,
                                      )
                                    ]
                                  : null,
                            ),
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
