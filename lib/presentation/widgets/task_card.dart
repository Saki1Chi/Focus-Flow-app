import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../core/theme/app_theme.dart';
import '../../data/models/task_model.dart';
import '../providers/task_provider.dart';
import '../providers/settings_provider.dart';

class TaskCard extends ConsumerStatefulWidget {
  final Task task;
  final bool showDate;
  final VoidCallback? onTap;

  const TaskCard({
    super.key,
    required this.task,
    this.showDate = false,
    this.onTap,
  });

  @override
  ConsumerState<TaskCard> createState() => _TaskCardState();
}

class _TaskCardState extends ConsumerState<TaskCard>
    with SingleTickerProviderStateMixin {
  late final AnimationController _pressCtrl;
  late final Animation<double> _pressScale;

  @override
  void initState() {
    super.initState();
    _pressCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 100),
      reverseDuration: const Duration(milliseconds: 200),
    );
    _pressScale = Tween<double>(begin: 1.0, end: 0.97).animate(
      CurvedAnimation(parent: _pressCtrl, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _pressCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context, ) {
    final accent      = ref.watch(settingsProvider).accentColor;
    final isDark      = Theme.of(context).brightness == Brightness.dark;
    final textTheme   = Theme.of(context).textTheme;

    final isInProgress = widget.task.status == TaskStatus.inProgress;
    final isCompleted  = widget.task.status == TaskStatus.completed;

    final borderColor = isDark
        ? (isInProgress
            ? accent.withValues(alpha: 0.45)
            : isCompleted
                ? const Color(0xFF22C55E).withValues(alpha: 0.18)
                : Colors.white.withValues(alpha: 0.07))
        : (isInProgress
            ? accent.withValues(alpha: 0.32)
            : const Color(0x0D000000));

    final glowShadows = isDark && isInProgress
        ? NeonColors.glow(accent, intensity: 0.5)
        : isDark
            ? NeonColors.crystalCard()
            : NeonColors.lightCard();

    final cardBg  = isDark ? const Color(0xFF0E0E1C) : Colors.white;
    final dimColor = isDark
        ? Colors.white.withValues(alpha: 0.25)
        : Colors.black.withValues(alpha: 0.25);

    return GestureDetector(
      onTapDown: (_) => _pressCtrl.forward(),
      onTapUp: (_) {
        _pressCtrl.reverse();
        widget.onTap?.call();
      },
      onTapCancel: () => _pressCtrl.reverse(),
      child: ScaleTransition(
        scale: _pressScale,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 280),
          curve: Curves.easeOutCubic,
          margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 5),
          decoration: BoxDecoration(
            color: cardBg,
            borderRadius: BorderRadius.circular(22),
            border: Border.all(color: borderColor, width: 1),
            boxShadow: glowShadows,
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(22),
            child: IntrinsicHeight(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // ── Left accent strip (only for in-progress) ──
                  AnimatedContainer(
                    duration: const Duration(milliseconds: 280),
                    curve: Curves.easeOutCubic,
                    width: isInProgress ? 4 : 0,
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          accent,
                          accent.withValues(alpha: 0.4),
                        ],
                      ),
                      boxShadow: isInProgress
                          ? [
                              BoxShadow(
                                color: accent.withValues(alpha: 0.6),
                                blurRadius: 8,
                              )
                            ]
                          : null,
                    ),
                  ),

                  // ── Card content ──────────────────────────────
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Title row
                          Row(
                            children: [
                              _StatusDot(
                                  task: widget.task,
                                  accent: accent,
                                  isDark: isDark),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Text(
                                  widget.task.title,
                                  style: textTheme.titleLarge?.copyWith(
                                    decoration: isCompleted
                                        ? TextDecoration.lineThrough
                                        : null,
                                    decorationColor: dimColor,
                                    color: isCompleted ? dimColor : null,
                                  ),
                                ),
                              ),
                              if (widget.task.isCarriedOver)
                                _CarriedBadge(isDark: isDark),
                            ],
                          ),

                          if (widget.task.description.isNotEmpty) ...[
                            const SizedBox(height: 6),
                            Text(
                              widget.task.description,
                              style: textTheme.bodyMedium,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],

                          const SizedBox(height: 10),

                          // Meta row
                          Row(
                            children: [
                              if (widget.task.startTime != null) ...[
                                Icon(
                                  Icons.access_time_rounded,
                                  size: 12,
                                  color: isDark
                                      ? Colors.white.withValues(alpha: 0.28)
                                      : Colors.black.withValues(alpha: 0.28),
                                ),
                                const SizedBox(width: 4),
                                Text(
                                  '${DateFormat.Hm().format(widget.task.startTime!)} – '
                                  '${widget.task.endTime != null ? DateFormat.Hm().format(widget.task.endTime!) : '?'}',
                                  style: textTheme.bodyMedium,
                                ),
                                const SizedBox(width: 12),
                              ],
                              if (widget.showDate) ...[
                                Icon(
                                  Icons.calendar_today_rounded,
                                  size: 12,
                                  color: isDark
                                      ? Colors.white.withValues(alpha: 0.28)
                                      : Colors.black.withValues(alpha: 0.28),
                                ),
                                const SizedBox(width: 4),
                                Text(
                                  DateFormat('MMM d').format(widget.task.date),
                                  style: textTheme.bodyMedium,
                                ),
                                const SizedBox(width: 12),
                              ],
                              if (widget.task.mode == TaskMode.smart)
                                Icon(Icons.auto_awesome_rounded,
                                    size: 12,
                                    color: accent.withValues(alpha: 0.8)),
                              if (widget.task.recurrence != null)
                                Padding(
                                  padding: const EdgeInsets.only(left: 8),
                                  child: Icon(
                                    Icons.repeat_rounded,
                                    size: 12,
                                    color: isDark
                                        ? Colors.white.withValues(alpha: 0.22)
                                        : Colors.black.withValues(alpha: 0.22),
                                  ),
                                ),
                            ],
                          ),

                          const SizedBox(height: 12),
                          _ActionButtons(
                              task: widget.task,
                              accent: accent,
                              isDark: isDark),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// ── Status dot ─────────────────────────────────────────────────

class _StatusDot extends StatelessWidget {
  final Task task;
  final Color accent;
  final bool isDark;
  const _StatusDot(
      {required this.task, required this.accent, required this.isDark});

  @override
  Widget build(BuildContext context) {
    Color color;
    IconData icon;

    switch (task.status) {
      case TaskStatus.completed:
        color = const Color(0xFF22C55E);
        icon  = Icons.check_circle_rounded;
        break;
      case TaskStatus.inProgress:
        color = accent;
        icon  = Icons.play_circle_rounded;
        break;
      case TaskStatus.pending:
        color = isDark
            ? Colors.white.withValues(alpha: 0.20)
            : Colors.black.withValues(alpha: 0.20);
        icon  = Icons.circle_outlined;
        break;
    }

    return Container(
      width: 22,
      height: 22,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        boxShadow: task.status != TaskStatus.pending
            ? NeonColors.glow(color, intensity: 0.65)
            : null,
      ),
      child: Icon(icon, color: color, size: 22),
    );
  }
}

// ── Carried-over badge ─────────────────────────────────────────

class _CarriedBadge extends StatelessWidget {
  final bool isDark;
  const _CarriedBadge({required this.isDark});

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
        decoration: BoxDecoration(
          color: Colors.orange.withValues(alpha: 0.10),
          borderRadius: BorderRadius.circular(8),
          border:
              Border.all(color: Colors.orange.withValues(alpha: 0.25), width: 1),
        ),
        child: const Text(
          'carried',
          style: TextStyle(
              fontSize: 9,
              color: Colors.orange,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.4),
        ),
      );
}

// ── Action buttons ─────────────────────────────────────────────

class _ActionButtons extends ConsumerWidget {
  final Task task;
  final Color accent;
  final bool isDark;
  const _ActionButtons(
      {required this.task, required this.accent, required this.isDark});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final notifier = ref.read(taskProvider.notifier);

    if (task.status == TaskStatus.completed) {
      return Row(children: [
        const Spacer(),
        _chip(
          label: 'Undo',
          icon: Icons.undo_rounded,
          color: isDark
              ? Colors.white.withValues(alpha: 0.30)
              : Colors.black.withValues(alpha: 0.28),
          onTap: () => notifier.markPending(task.id),
          isDark: isDark,
        ),
      ]);
    }

    return Row(
      mainAxisAlignment: MainAxisAlignment.end,
      children: [
        if (task.status == TaskStatus.pending)
          _chip(
            label: 'Start',
            icon: Icons.play_arrow_rounded,
            color: accent,
            onTap: () => notifier.markInProgress(task.id),
            isDark: isDark,
          ),
        if (task.status == TaskStatus.inProgress) ...[
          _chip(
            label: 'Done',
            icon: Icons.check_rounded,
            color: const Color(0xFF22C55E),
            onTap: () => notifier.markCompleted(task.id),
            isDark: isDark,
          ),
          const SizedBox(width: 8),
          _chip(
            label: 'Pause',
            icon: Icons.pause_rounded,
            color: Colors.orange,
            onTap: () => notifier.markPending(task.id),
            isDark: isDark,
          ),
        ],
      ],
    );
  }

  Widget _chip({
    required String label,
    required IconData icon,
    required Color color,
    required VoidCallback onTap,
    required bool isDark,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.10),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: color.withValues(alpha: 0.24), width: 1),
          boxShadow: isDark ? NeonColors.glow(color, intensity: 0.28) : null,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 13, color: color),
            const SizedBox(width: 4),
            Text(
              label,
              style: TextStyle(
                  fontSize: 11,
                  color: color,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.2),
            ),
          ],
        ),
      ),
    );
  }
}
