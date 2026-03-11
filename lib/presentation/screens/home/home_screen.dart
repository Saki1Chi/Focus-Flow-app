import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../../core/constants/app_constants.dart';
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

  @override
  Widget build(BuildContext context) {
    final tasks = ref.watch(todayTasksProvider);
    final settings = ref.watch(settingsProvider);
    final accent = settings.accentColor;
    final completed = tasks.where((t) => t.status == TaskStatus.completed).length;
    final total = tasks.length;

    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('FocusFlow', style: Theme.of(context).textTheme.headlineSmall),
            Text(DateFormat('EEEE, MMM d').format(DateTime.now()),
                style: Theme.of(context).textTheme.bodyMedium),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded),
            onPressed: () => ref.read(taskProvider.notifier).processCarryOvers(),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.only(bottom: 100),
        children: [
          // Progress card
          _ProgressCard(
            completed: completed,
            total: total,
            blocks: settings.completedBlocks,
            accent: accent,
            remainingSeconds: _remainingSeconds,
          ),
          const SizedBox(height: 8),

          // Section header
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
            child: Text("Today's Tasks",
                style: Theme.of(context).textTheme.titleLarge),
          ),

          if (tasks.isEmpty)
            _EmptyState(accent: accent)
          else
            ...tasks.map((task) => TaskCard(
                  task: task,
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                        builder: (_) => TaskDetailScreen(taskId: task.id)),
                  ),
                )),
        ],
      ),
    );
  }
}

class _ProgressCard extends StatelessWidget {
  final int completed;
  final int total;
  final int blocks;
  final Color accent;
  final int remainingSeconds;

  const _ProgressCard({
    required this.completed,
    required this.total,
    required this.blocks,
    required this.accent,
    required this.remainingSeconds,
  });

  @override
  Widget build(BuildContext context) {
    final progress = total == 0 ? 0.0 : completed / total;
    final blocksInCycle = blocks % AppConstants.blocksToUnlock;
    final isUnlocked = remainingSeconds > 0;

    return Container(
      margin: const EdgeInsets.fromLTRB(16, 16, 16, 8),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [accent, accent.withOpacity(0.7)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Text('Today\'s Progress',
                  style: TextStyle(color: Colors.white70, fontSize: 13)),
              const Spacer(),
              if (isUnlocked)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.lock_open_rounded, size: 12, color: Colors.white),
                      const SizedBox(width: 4),
                      Text(
                        '${remainingSeconds ~/ 60}:${(remainingSeconds % 60).toString().padLeft(2, '0')}',
                        style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w600),
                      ),
                    ],
                  ),
                ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            '$completed / $total tasks',
            style: const TextStyle(color: Colors.white, fontSize: 26, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 10),
          ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: LinearProgressIndicator(
              value: progress,
              backgroundColor: Colors.white.withOpacity(0.3),
              valueColor: const AlwaysStoppedAnimation<Color>(Colors.white),
              minHeight: 8,
            ),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              const Text('Block progress: ',
                  style: TextStyle(color: Colors.white70, fontSize: 12)),
              ...List.generate(AppConstants.blocksToUnlock, (i) => Padding(
                padding: const EdgeInsets.only(right: 6),
                child: Icon(
                  i < blocksInCycle
                      ? Icons.radio_button_checked_rounded
                      : Icons.radio_button_unchecked_rounded,
                  size: 16,
                  color: Colors.white,
                ),
              )),
              const Spacer(),
              Text(
                isUnlocked ? '🔓 Unlocked!' : '🔒 ${AppConstants.blocksToUnlock - blocksInCycle} to unlock',
                style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w600),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  final Color accent;
  const _EmptyState({required this.accent});

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 60, horizontal: 32),
    child: Column(
      children: [
        Icon(Icons.check_circle_outline_rounded, size: 64, color: accent.withOpacity(0.4)),
        const SizedBox(height: 16),
        Text('No tasks today!', style: Theme.of(context).textTheme.headlineSmall),
        const SizedBox(height: 8),
        Text('Tap + to add a task or use Smart Mode to auto-schedule.',
            style: Theme.of(context).textTheme.bodyMedium,
            textAlign: TextAlign.center),
      ],
    ),
  );
}
