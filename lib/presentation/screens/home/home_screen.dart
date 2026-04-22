import 'dart:async';
import 'package:animate_do/animate_do.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../../core/constants/app_constants.dart';
import '../../../core/theme/app_theme.dart';
import '../../../data/models/task_model.dart';
import '../../../services/api_service.dart';
import '../../providers/task_provider.dart';
import '../../providers/settings_provider.dart';
import '../../providers/sync_provider.dart';
import '../../widgets/task_card.dart';
import '../task_detail_screen.dart';

// Sin autoDispose: el resultado se cachea mientras la app está abierta.
// Para refrescar manualmente usa ref.invalidate(serverStatsProvider).
final serverStatsProvider = FutureProvider<Map<String, int>>(
  (_) => ApiService().getStats(),
);

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
      ref
          .read(taskProvider.notifier)
          .expandRecurringTasks(DateTime.now().add(const Duration(days: 30)));
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
    final tasks = ref.watch(todayTasksProvider);
    final settings = ref.watch(settingsProvider);
    final accent = settings.accentColor;
    final tokens = Theme.of(context).extension<MinimalTheme>();
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final completed = tasks
        .where((t) => t.status == TaskStatus.completed)
        .length;
    final total = tasks.length;
    final subColor =
        tokens?.textSub ??
        (isDark ? const Color(0xFF484862) : const Color(0xFF9898B8));
    final syncStatus = ref.watch(syncStatusProvider);
    final statsAsync = ref.watch(serverStatsProvider);

    return Scaffold(
      body: Stack(
        children: [
          // Sutil degradado de acento en la parte superior
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            height: 280,
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    accent.withValues(alpha: isDark ? 0.07 : 0.04),
                    Colors.transparent,
                  ],
                ),
              ),
            ),
          ),

          RefreshIndicator(
            onRefresh: () async {
              ref.invalidate(serverStatsProvider); // fuerza re-fetch de stats
              await ref.read(taskProvider.notifier).refreshFromServer();
            },
            color: accent,
            child: CustomScrollView(
              physics: const AlwaysScrollableScrollPhysics(
                parent: BouncingScrollPhysics(),
              ),
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
                                    style: Theme.of(
                                      context,
                                    ).textTheme.headlineMedium,
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    DateFormat(
                                      'EEEE, MMMM d',
                                    ).format(DateTime.now()),
                                    style: Theme.of(
                                      context,
                                    ).textTheme.bodyMedium,
                                  ),
                                  const SizedBox(height: 6),
                                  _SyncChip(
                                    status: syncStatus,
                                    accent: accent,
                                    isDark: isDark,
                                  ),
                                ],
                              ),
                            ),
                            if (settings.currentStreak > 0) ...[
                              _StreakBadge(
                                streak: settings.currentStreak,
                                isDark: isDark,
                              ),
                              const SizedBox(width: 8),
                            ],
                            _RefreshButton(
                              subColor: subColor,
                              isDark: isDark,
                              onTap: () => ref
                                  .read(taskProvider.notifier)
                                  .processCarryOvers(),
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

                // ── Server stats card ────────────────────────────────
                SliverToBoxAdapter(
                  child: statsAsync.when(
                    loading: () => const SizedBox.shrink(),
                    error: (_, __) => const SizedBox.shrink(),
                    data: (stats) => FadeInDown(
                      duration: const Duration(milliseconds: 540),
                      delay: const Duration(milliseconds: 80),
                      child: _StatsCard(
                        stats: stats,
                        accent: accent,
                        isDark: isDark,
                      ),
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
                                  horizontal: 10,
                                  vertical: 4,
                                ),
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
                              builder: (_) =>
                                  TaskDetailScreen(taskId: tasks[i].id),
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
          ), // RefreshIndicator
        ],
      ),
    );
  }
}

// ── Refresh button con animación de rotación ───────────────────

class _RefreshButton extends StatefulWidget {
  final Color subColor;
  final bool isDark;
  final VoidCallback onTap;

  const _RefreshButton({
    required this.subColor,
    required this.isDark,
    required this.onTap,
  });

  @override
  State<_RefreshButton> createState() => _RefreshButtonState();
}

class _RefreshButtonState extends State<_RefreshButton>
    with SingleTickerProviderStateMixin {
  late final AnimationController _rotCtrl;
  late final Animation<double> _rotation;

  @override
  void initState() {
    super.initState();
    _rotCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );
    _rotation = Tween<double>(
      begin: 0,
      end: 1,
    ).animate(CurvedAnimation(parent: _rotCtrl, curve: Curves.easeOutCubic));
  }

  @override
  void dispose() {
    _rotCtrl.dispose();
    super.dispose();
  }

  void _handleTap() {
    _rotCtrl.forward(from: 0);
    widget.onTap();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: _handleTap,
      child: RotationTransition(
        turns: _rotation,
        child: Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: widget.isDark ? const Color(0xFF0E0E1C) : Colors.white,
            border: Border.all(
              color: widget.isDark
                  ? Colors.white.withValues(alpha: 0.10)
                  : Colors.black.withValues(alpha: 0.08),
            ),
          ),
          child: Icon(Icons.refresh_rounded, size: 18, color: widget.subColor),
        ),
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
    final progress = total == 0 ? 0.0 : completed / total;
    final blocksInCycle = blocks % AppConstants.blocksToUnlock;
    final isUnlocked = remainingSeconds > 0;
    final tokens = Theme.of(context).extension<MinimalTheme>();
    final cardBg =
        tokens?.surface ?? (isDark ? const Color(0xFF0E0E1C) : Colors.white);
    final borderColor =
        tokens?.border ??
        (isDark
            ? Colors.white.withValues(alpha: 0.07)
            : Colors.black.withValues(alpha: 0.05));
    final subColor =
        tokens?.textSub ??
        (isDark ? const Color(0xFF484862) : const Color(0xFF9898B8));

    return Container(
      margin: const EdgeInsets.fromLTRB(16, 14, 16, 0),
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: borderColor, width: 1),
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
                  seconds: remainingSeconds,
                  accent: accent,
                  isDark: isDark,
                ),
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
                builder: (context, val, child) => Text(
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
                  builder: (context, val, child) => Text(
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
                    duration: const Duration(milliseconds: 400),
                    curve: Curves.easeOutBack,
                    width: filled ? 11 : 8,
                    height: filled ? 11 : 8,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: filled ? accent : Colors.transparent,
                      border: Border.all(
                        color: filled
                            ? accent
                            : (tokens?.border ??
                                  (isDark
                                      ? Colors.white.withValues(alpha: 0.18)
                                      : Colors.black.withValues(alpha: 0.14))),
                        width: 1.5,
                      ),
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
  const _NeonProgressBar({
    required this.progress,
    required this.accent,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    final tokens = Theme.of(context).extension<MinimalTheme>();
    return TweenAnimationBuilder<double>(
      duration: const Duration(milliseconds: 900),
      curve: Curves.easeOutCubic,
      tween: Tween(begin: 0.0, end: progress),
      builder: (context, value, _) => Container(
        height: 6,
        decoration: BoxDecoration(
          color:
              tokens?.border.withValues(alpha: 0.35) ??
              (isDark
                  ? Colors.white.withValues(alpha: 0.06)
                  : Colors.black.withValues(alpha: 0.07)),
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

// ── Unlock badge con glow pulsante ─────────────────────────────

class _UnlockBadge extends StatefulWidget {
  final int seconds;
  final Color accent;
  final bool isDark;
  const _UnlockBadge({
    required this.seconds,
    required this.accent,
    required this.isDark,
  });

  @override
  State<_UnlockBadge> createState() => _UnlockBadgeState();
}

class _UnlockBadgeState extends State<_UnlockBadge>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  late final Animation<double> _pulse;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    )..repeat(reverse: true);
    _pulse = Tween<double>(
      begin: 0.6,
      end: 1.2,
    ).animate(CurvedAnimation(parent: _ctrl, curve: Curves.easeInOut));
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _pulse,
      builder: (_, __) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration: BoxDecoration(
          color: widget.accent.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: widget.accent.withValues(alpha: 0.28),
            width: 1,
          ),
          boxShadow: [
            BoxShadow(
              color: widget.accent.withValues(alpha: 0.18 * _pulse.value),
              blurRadius: 18 * _pulse.value,
              spreadRadius: -2,
            ),
          ],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.lock_open_rounded, size: 11, color: widget.accent),
            const SizedBox(width: 5),
            Text(
              '${widget.seconds ~/ 60}:${(widget.seconds % 60).toString().padLeft(2, '0')}',
              style: TextStyle(
                color: widget.accent,
                fontSize: 11,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Streak badge ───────────────────────────────────────────────

class _StreakBadge extends StatelessWidget {
  final int streak;
  final bool isDark;
  const _StreakBadge({required this.streak, required this.isDark});

  @override
  Widget build(BuildContext context) {
    const fire = Color(0xFFF97316); // orange-500
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
      decoration: BoxDecoration(
        color: fire.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: fire.withValues(alpha: 0.30), width: 1),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Text('🔥', style: TextStyle(fontSize: 11)),
          const SizedBox(width: 3),
          Text(
            '$streak',
            style: const TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w800,
              color: fire,
            ),
          ),
        ],
      ),
    );
  }
}

// ── Sync status chip ──────────────────────────────────────────

class _SyncChip extends StatelessWidget {
  final SyncStatus status;
  final Color accent;
  final bool isDark;
  const _SyncChip({
    required this.status,
    required this.accent,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    final (icon, label, color) = switch (status) {
      SyncStatus.syncing => (Icons.sync_rounded, 'Syncing…', accent),
      SyncStatus.synced => (
        Icons.cloud_done_rounded,
        'Synced',
        const Color(0xFF22C55E),
      ),
      SyncStatus.offline => (Icons.cloud_off_rounded, 'Offline', Colors.orange),
      SyncStatus.idle => (
        Icons.cloud_outlined,
        'Online',
        isDark ? const Color(0xFF484862) : const Color(0xFF9898B8),
      ),
    };

    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 300),
      child: Row(
        key: ValueKey(status),
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 11, color: color),
          const SizedBox(width: 4),
          Text(
            label,
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w600,
              color: color,
              letterSpacing: 0.2,
            ),
          ),
        ],
      ),
    );
  }
}

// ── Server stats card ─────────────────────────────────────────

class _StatsCard extends StatelessWidget {
  final Map<String, int> stats;
  final Color accent;
  final bool isDark;
  const _StatsCard({
    required this.stats,
    required this.accent,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    final tokens = Theme.of(context).extension<MinimalTheme>();
    final cardBg =
        tokens?.surface ?? (isDark ? const Color(0xFF0E0E1C) : Colors.white);
    final borderColor =
        tokens?.border ??
        (isDark
            ? Colors.white.withValues(alpha: 0.07)
            : Colors.black.withValues(alpha: 0.05));
    final subColor =
        tokens?.textSub ??
        (isDark ? const Color(0xFF484862) : const Color(0xFF9898B8));

    final items = <(IconData, String, String)>[
      (Icons.task_alt_rounded, 'Total', '${stats['total'] ?? 0}'),
      (Icons.check_circle_rounded, 'Done', '${stats['completed'] ?? 0}'),
      (Icons.pending_rounded, 'Pending', '${stats['pending'] ?? 0}'),
      (Icons.category_rounded, 'Categories', '${stats['categories'] ?? 0}'),
    ];

    return Container(
      margin: const EdgeInsets.fromLTRB(16, 10, 16, 0),
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: borderColor, width: 1),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.bar_chart_rounded, size: 13, color: accent),
              const SizedBox(width: 6),
              Text(
                'SERVER STATS',
                style: TextStyle(
                  color: accent,
                  fontSize: 9.5,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 1.0,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: items
                .map(
                  (item) => _StatItem(
                    icon: item.$1,
                    label: item.$2,
                    value: item.$3,
                    accent: accent,
                    subColor: subColor,
                    isDark: isDark,
                  ),
                )
                .toList(),
          ),
        ],
      ),
    );
  }
}

class _StatItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final Color accent;
  final Color subColor;
  final bool isDark;

  const _StatItem({
    required this.icon,
    required this.label,
    required this.value,
    required this.accent,
    required this.subColor,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) => Column(
    children: [
      Icon(icon, size: 16, color: accent.withValues(alpha: 0.75)),
      const SizedBox(height: 4),
      Text(
        value,
        style: TextStyle(
          fontSize: 16,
          fontWeight: FontWeight.w800,
          color: isDark ? Colors.white : const Color(0xFF080818),
          letterSpacing: -0.5,
        ),
      ),
      const SizedBox(height: 2),
      Text(
        label,
        style: TextStyle(
          fontSize: 9,
          fontWeight: FontWeight.w600,
          color: subColor,
          letterSpacing: 0.3,
        ),
      ),
    ],
  );
}

// ── Empty state con ícono flotante ─────────────────────────────

class _EmptyState extends StatefulWidget {
  final Color accent;
  final bool isDark;
  const _EmptyState({required this.accent, required this.isDark});

  @override
  State<_EmptyState> createState() => _EmptyStateState();
}

class _EmptyStateState extends State<_EmptyState>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  late final Animation<double> _float;
  late final Animation<double> _breathe;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2800),
    )..repeat(reverse: true);
    _float = Tween<double>(
      begin: 0.0,
      end: -10.0,
    ).animate(CurvedAnimation(parent: _ctrl, curve: Curves.easeInOut));
    _breathe = Tween<double>(
      begin: 1.0,
      end: 1.06,
    ).animate(CurvedAnimation(parent: _ctrl, curve: Curves.easeInOut));
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 64, horizontal: 32),
    child: Column(
      children: [
        AnimatedBuilder(
          animation: _ctrl,
          builder: (_, child) => Transform.translate(
            offset: Offset(0, _float.value),
            child: Transform.scale(scale: _breathe.value, child: child),
          ),
          child: Container(
            width: 88,
            height: 88,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: RadialGradient(
                colors: [
                  widget.accent.withValues(alpha: 0.18),
                  widget.accent.withValues(alpha: 0.04),
                ],
              ),
              border: Border.all(
                color: widget.accent.withValues(alpha: 0.22),
                width: 1,
              ),
              boxShadow: [
                BoxShadow(
                  color: widget.accent.withValues(alpha: 0.12),
                  blurRadius: 24,
                  spreadRadius: -4,
                ),
              ],
            ),
            child: Icon(
              Icons.task_alt_rounded,
              size: 36,
              color: widget.accent.withValues(alpha: 0.7),
            ),
          ),
        ),
        const SizedBox(height: 24),
        Text('All clear!', style: Theme.of(context).textTheme.headlineSmall),
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
