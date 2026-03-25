import 'dart:async';
import 'package:animate_do/animate_do.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../../core/constants/app_constants.dart';
import '../../../core/theme/app_theme.dart';
import '../../../data/models/task_model.dart';
import '../../providers/task_provider.dart';
import '../../providers/settings_provider.dart';
import '../../widgets/task_card.dart';
import '../task_detail_screen.dart';

class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> {
  Timer? _timer;
  int _remainingSeconds = 0;

  @override
  void initState() {
    super.initState();
    _startTimer();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(taskProvider.notifier).processCarryOvers();
      ref.read(taskProvider.notifier).expandRecurringTasks(
            DateTime.now().add(const Duration(days: 30)),
          );
    });
  }

  void _startTimer() {
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      final session = ref.read(taskProvider.notifier).getActiveSession();
      if (session != null && !session.isExpired) {
        setState(() => _remainingSeconds = session.remainingSeconds);
      } else {
        setState(() => _remainingSeconds = 0);
      }
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  String get _greeting {
    final h = DateTime.now().hour;
    if (h < 12) return 'Good morning';
    if (h < 17) return 'Good afternoon';
    return 'Good evening';
  }

  @override
  Widget build(BuildContext context) {
    final tasks     = ref.watch(todayTasksProvider);
    final settings  = ref.watch(settingsProvider);
    final accent    = settings.accentColor;
    final isDark    = Theme.of(context).brightness == Brightness.dark;
    final completed = tasks.where((t) => t.status == TaskStatus.completed).length;
    final total     = tasks.length;
    final subColor  = isDark ? const Color(0xFF484862) : const Color(0xFF9898B8);

    return Scaffold(
      body: CustomScrollView(
        physics: const BouncingScrollPhysics(),
        slivers: [
          // ── Header ──────────────────────────────────────────
          SliverToBoxAdapter(
            child: FadeInDown(
              duration: const Duration(milliseconds: 480),
              child: SafeArea(
                bottom: false,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(22, 20, 22, 0),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              _greeting,
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w500,
                                color: subColor,
                                letterSpacing: 0.1,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              'FocusFlow',
                              style: Theme.of(context).textTheme.headlineMedium,
                            ),
                            const SizedBox(height: 2),
                            Text(
                              DateFormat('EEEE, MMMM d').format(DateTime.now()),
                              style: Theme.of(context).textTheme.bodyMedium,
                            ),
                          ],
                        ),
                      ),
                      GestureDetector(
                        onTap: () =>
                            ref.read(taskProvider.notifier).processCarryOvers(),
                        child: Container(
                          width: 40,
                          height: 40,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: isDark
                                ? const Color(0xFF0E0E1C)
                                : Colors.white,
                            border: Border.all(
                              color: isDark
                                  ? Colors.white.withValues(alpha: 0.08)
                                  : Colors.black.withValues(alpha: 0.07),
                            ),
                            boxShadow: isDark
                                ? NeonColors.crystalCard()
                                : NeonColors.lightCard(),
                          ),
                          child: Icon(
                            Icons.refresh_rounded,
                            size: 18,
                            color: subColor,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),

          // ── Progress card ────────────────────────────────────
          SliverToBoxAdapter(
            child: FadeInDown(
              duration: const Duration(milliseconds: 520),
              delay: const Duration(milliseconds: 60),
              child: _ProgressCard(
                completed: completed,
                total: total,
                blocks: settings.completedBlocks,
                accent: accent,
                remainingSeconds: _remainingSeconds,
                isDark: isDark,
              ),
            ),
          ),

          // ── Section header ───────────────────────────────────
          SliverToBoxAdapter(
            child: FadeIn(
              duration: const Duration(milliseconds: 400),
              delay: const Duration(milliseconds: 120),
              child: Padding(
                padding: const EdgeInsets.fromLTRB(22, 24, 22, 10),
                child: Row(
                  children: [
                    Text(
                      "Today's Tasks",
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                    const Spacer(),
                    if (total > 0)
                      AnimatedSwitcher(
                        duration: const Duration(milliseconds: 300),
                        child: Container(
                          key: ValueKey('$completed/$total'),
                          padding: const EdgeInsets.symmetric(
                              horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(
                            color: accent.withValues(alpha: 0.10),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Text(
                            '$completed / $total',
                            style: TextStyle(
                              color: accent,
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ),

          // ── Task list ────────────────────────────────────────
          if (tasks.isEmpty)
            SliverToBoxAdapter(
              child: FadeIn(
                duration: const Duration(milliseconds: 400),
                delay: const Duration(milliseconds: 160),
                child: _EmptyState(accent: accent, isDark: isDark),
              ),
            )
          else
            SliverList(
              delegate: SliverChildBuilderDelegate(
                (ctx, i) => FadeInUp(
                  duration: const Duration(milliseconds: 340),
                  delay: Duration(milliseconds: 80 * i),
                  child: TaskCard(
                    task: tasks[i],
                    onTap: () => Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => TaskDetailScreen(taskId: tasks[i].id),
                      ),
                    ),
                  ),
                ),
                childCount: tasks.length,
              ),
            ),

          const SliverToBoxAdapter(child: SizedBox(height: 120)),
        ],
      ),
    );
  }
}

// ── Progress card ──────────────────────────────────────────────

class _ProgressCard extends StatelessWidget {
  final int completed;
  final int total;
  final int blocks;
  final Color accent;
  final int remainingSeconds;
  final bool isDark;

  const _ProgressCard({
    required this.completed,
    required this.total,
    required this.blocks,
    required this.accent,
    required this.remainingSeconds,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    final progress      = total == 0 ? 0.0 : completed / total;
    final blocksInCycle = blocks % AppConstants.blocksToUnlock;
    final isUnlocked    = remainingSeconds > 0;
    final cardBg        = isDark ? const Color(0xFF0E0E1C) : Colors.white;
    final borderColor   = isDark
        ? Colors.white.withValues(alpha: 0.07)
        : Colors.black.withValues(alpha: 0.05);
    final subColor      = isDark ? const Color(0xFF484862) : const Color(0xFF9898B8);

    return Container(
      margin: const EdgeInsets.fromLTRB(16, 14, 16, 0),
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: borderColor, width: 1),
        boxShadow: isDark
            ? [...NeonColors.glow(accent, intensity: 0.16), ...NeonColors.crystalCard()]
            : NeonColors.lightCard(),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Label + badge ──────────────────────────────────
          Row(
            children: [
              Text(
                "TODAY'S PROGRESS",
                style: TextStyle(
                  color: subColor,
                  fontSize: 10,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 1.0,
                ),
              ),
              const Spacer(),
              if (isUnlocked)
                _UnlockBadge(
                    seconds: remainingSeconds, accent: accent, isDark: isDark),
            ],
          ),
          const SizedBox(height: 14),

          // ── Animated counter ───────────────────────────────
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              TweenAnimationBuilder<double>(
                duration: const Duration(milliseconds: 700),
                curve: Curves.easeOutCubic,
                tween: Tween(begin: 0, end: completed.toDouble()),
                builder: (_, val, __) => Text(
                  '${val.round()}',
                  style: TextStyle(
                    fontSize: 48,
                    fontWeight: FontWeight.w800,
                    color: isDark ? Colors.white : const Color(0xFF080818),
                    height: 1.0,
                    letterSpacing: -3,
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.only(bottom: 8, left: 4),
                child: Text(
                  '/ $total tasks',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                    color: subColor,
                  ),
                ),
              ),
              const Spacer(),
              if (total > 0)
                TweenAnimationBuilder<double>(
                  duration: const Duration(milliseconds: 700),
                  curve: Curves.easeOutCubic,
                  tween: Tween(begin: 0, end: progress),
                  builder: (_, val, __) => Text(
                    '${(val * 100).round()}%',
                    style: TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.w700,
                      color: accent,
                      letterSpacing: -0.5,
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 14),

          // ── Progress bar ───────────────────────────────────
          _NeonProgressBar(progress: progress, accent: accent, isDark: isDark),
          const SizedBox(height: 20),

          // ── Focus blocks ───────────────────────────────────
          Row(
            children: [
              Text(
                'FOCUS BLOCKS',
                style: TextStyle(
                  color: subColor,
                  fontSize: 9.5,
                  letterSpacing: 0.9,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(width: 10),
              ...List.generate(AppConstants.blocksToUnlock, (i) {
                final filled = i < blocksInCycle;
                return Padding(
                  padding: const EdgeInsets.only(right: 5),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 350),
                    curve: Curves.easeOutBack,
                    width: filled ? 10 : 8,
                    height: filled ? 10 : 8,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: filled ? accent : Colors.transparent,
                      border: Border.all(
                        color: filled
                            ? accent
                            : (isDark
                                ? Colors.white.withValues(alpha: 0.18)
                                : Colors.black.withValues(alpha: 0.14)),
                        width: 1.5,
                      ),
                      boxShadow: filled
                          ? [
                              BoxShadow(
                                color: accent.withValues(alpha: 0.5),
                                blurRadius: 8,
                                spreadRadius: -1,
                              )
                            ]
                          : null,
                    ),
                  ),
                );
              }),
              const Spacer(),
              Text(
                isUnlocked
                    ? 'Unlocked'
                    : '${AppConstants.blocksToUnlock - blocksInCycle} to unlock',
                style: TextStyle(
                  color: isUnlocked ? accent : subColor,
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 0.2,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// ── Progress bar ───────────────────────────────────────────────

class _NeonProgressBar extends StatelessWidget {
  final double progress;
  final Color accent;
  final bool isDark;
  const _NeonProgressBar(
      {required this.progress, required this.accent, required this.isDark});

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      duration: const Duration(milliseconds: 900),
      curve: Curves.easeOutCubic,
      tween: Tween(begin: 0.0, end: progress),
      builder: (context, value, _) => Container(
        height: 6,
        decoration: BoxDecoration(
          color: isDark
              ? Colors.white.withValues(alpha: 0.06)
              : Colors.black.withValues(alpha: 0.07),
          borderRadius: BorderRadius.circular(6),
        ),
        child: LayoutBuilder(
          builder: (ctx, constraints) => Stack(
            children: [
              AnimatedContainer(
                duration: Duration.zero,
                width: constraints.maxWidth * value,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [accent.withValues(alpha: 0.75), accent],
                  ),
                  borderRadius: BorderRadius.circular(6),
                  boxShadow: [
                    BoxShadow(
                      color: accent.withValues(alpha: 0.65),
                      blurRadius: 10,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ── Unlock badge ───────────────────────────────────────────────

class _UnlockBadge extends StatelessWidget {
  final int seconds;
  final Color accent;
  final bool isDark;
  const _UnlockBadge(
      {required this.seconds, required this.accent, required this.isDark});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: accent.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: accent.withValues(alpha: 0.28), width: 1),
        boxShadow: NeonColors.softGlow(accent),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.lock_open_rounded, size: 11, color: accent),
          const SizedBox(width: 5),
          Text(
            '${seconds ~/ 60}:${(seconds % 60).toString().padLeft(2, '0')}',
            style: TextStyle(
                color: accent, fontSize: 11, fontWeight: FontWeight.w700),
          ),
        ],
      ),
    );
  }
}

// ── Empty state ────────────────────────────────────────────────

class _EmptyState extends StatelessWidget {
  final Color accent;
  final bool isDark;
  const _EmptyState({required this.accent, required this.isDark});

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 64, horizontal: 32),
        child: Column(
          children: [
            Container(
              width: 84,
              height: 84,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: [
                    accent.withValues(alpha: 0.16),
                    accent.withValues(alpha: 0.04),
                  ],
                ),
                border: Border.all(
                    color: accent.withValues(alpha: 0.20), width: 1),
              ),
              child: Icon(Icons.task_alt_rounded,
                  size: 36, color: accent.withValues(alpha: 0.7)),
            ),
            const SizedBox(height: 22),
            Text('All clear!',
                style: Theme.of(context).textTheme.headlineSmall),
            const SizedBox(height: 8),
            Text(
              'No tasks for today.\nTap + to add one or try Smart Mode.',
              style: Theme.of(context).textTheme.bodyMedium,
              textAlign: TextAlign.center,
            ),
          ],
        ),
      );
}
