import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../providers/settings_provider.dart';
import '../../providers/social_provider.dart';
import '../../screens/auth/auth_screen.dart';
import '../../../data/models/social_models.dart';

class SocialScreen extends ConsumerStatefulWidget {
  const SocialScreen({super.key});

  @override
  ConsumerState<SocialScreen> createState() => _SocialScreenState();
}

class _SocialScreenState extends ConsumerState<SocialScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabCtrl;

  @override
  void initState() {
    super.initState();
    _tabCtrl = TabController(length: 3, vsync: this);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final social = ref.read(socialProvider);
      if (social.isLoggedIn) {
        ref.read(socialProvider.notifier).loadAll();
      }
    });
  }

  @override
  void dispose() {
    _tabCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final social = ref.watch(socialProvider);

    if (!social.isLoggedIn) {
      return const AuthScreen();
    }

    final accent = ref.watch(settingsProvider).accentColor;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final user   = social.currentUser!;

    return Scaffold(
      body: NestedScrollView(
        headerSliverBuilder: (context, innerBoxIsScrolled) => [
          SliverAppBar(
            expandedHeight: 130,
            floating: false,
            pinned: true,
            backgroundColor:
                isDark ? const Color(0xFF0A0A0A) : const Color(0xFFF5F5F7),
            elevation: 0,
            flexibleSpace: FlexibleSpaceBar(
              background: _ProfileHeader(user: user, accent: accent),
            ),
            bottom: TabBar(
              controller: _tabCtrl,
              indicatorColor: accent,
              labelColor: accent,
              unselectedLabelColor: Colors.grey,
              labelStyle:
                  const TextStyle(fontWeight: FontWeight.w700, fontSize: 13),
              dividerColor: Colors.transparent,
              tabs: const [
                Tab(icon: Icon(Icons.rss_feed_rounded, size: 18), text: 'Feed'),
                Tab(icon: Icon(Icons.people_rounded, size: 18), text: 'Amigos'),
                Tab(icon: Icon(Icons.emoji_events_rounded, size: 18), text: 'Retos'),
              ],
            ),
            actions: [
              IconButton(
                icon: const Icon(Icons.refresh_rounded),
                onPressed: () =>
                    ref.read(socialProvider.notifier).loadAll(),
                tooltip: 'Actualizar',
              ),
              IconButton(
                icon: const Icon(Icons.logout_rounded),
                onPressed: _confirmLogout,
                tooltip: 'Cerrar sesión',
              ),
            ],
          ),
        ],
        body: TabBarView(
          controller: _tabCtrl,
          children: [
            _FeedTab(social: social, accent: accent),
            _FriendsTab(social: social, accent: accent),
            _ChallengesTab(social: social, accent: accent),
          ],
        ),
      ),
    );
  }

  void _confirmLogout() {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Cerrar sesión'),
        content: const Text('¿Salir de FocusFlow Social?'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancelar')),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              ref.read(socialProvider.notifier).logout();
            },
            child: const Text('Salir', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }
}

// ─── Profile header ───────────────────────────────────────────────────────────

class _ProfileHeader extends StatelessWidget {
  final UserProfile user;
  final Color accent;

  const _ProfileHeader({required this.user, required this.accent});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 52, 20, 0),
      child: Row(
        children: [
          // Avatar
          Container(
            width: 52,
            height: 52,
            decoration: BoxDecoration(
              color: _hexColor(user.avatarColor).withValues(alpha: 0.18),
              shape: BoxShape.circle,
              border: Border.all(
                  color: _hexColor(user.avatarColor).withValues(alpha: 0.5),
                  width: 2),
            ),
            child: Center(
                child: Text(user.avatarEmoji,
                    style: const TextStyle(fontSize: 26))),
          ),
          const SizedBox(width: 14),
          // Info
          Expanded(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(user.displayName,
                    style: const TextStyle(
                        fontWeight: FontWeight.w800, fontSize: 17)),
                Text('@${user.username}',
                    style:
                        const TextStyle(color: Colors.grey, fontSize: 12)),
              ],
            ),
          ),
          // Stats
          _statPill('🔥', '${user.completedBlocks}', 'blocks'),
          const SizedBox(width: 10),
          _statPill('⚡', '${user.currentStreak}', 'días'),
        ],
      ),
    );
  }

  Widget _statPill(String emoji, String value, String label) => Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(emoji, style: const TextStyle(fontSize: 18)),
          Text(value,
              style:
                  const TextStyle(fontWeight: FontWeight.w800, fontSize: 14)),
          Text(label,
              style: const TextStyle(color: Colors.grey, fontSize: 10)),
        ],
      );

  Color _hexColor(String hex) {
    final h = hex.replaceFirst('#', '');
    return Color(int.parse('FF$h', radix: 16));
  }
}

// ══════════════════════════════════════════════════════════════════════════════
//  TAB: FEED
// ══════════════════════════════════════════════════════════════════════════════

class _FeedTab extends ConsumerWidget {
  final SocialState social;
  final Color accent;

  const _FeedTab({required this.social, required this.accent});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (social.activityFeed.isEmpty) {
      return _EmptyState(
        icon: Icons.rss_feed_rounded,
        message: 'Tu feed está vacío.\nAgrega amigos para ver su actividad.',
        accent: accent,
      );
    }

    return RefreshIndicator(
      color: accent,
      onRefresh: () => ref.read(socialProvider.notifier).loadFeed(),
      child: ListView.builder(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 100),
        itemCount: social.activityFeed.length,
        itemBuilder: (ctx, i) =>
            _ActivityCard(log: social.activityFeed[i], accent: accent),
      ),
    );
  }
}

class _ActivityCard extends StatelessWidget {
  final ActivityLog log;
  final Color accent;

  const _ActivityCard({required this.log, required this.accent});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: isDark
            ? Colors.white.withValues(alpha: 0.04)
            : Colors.black.withValues(alpha: 0.03),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isDark
              ? Colors.white.withValues(alpha: 0.07)
              : Colors.black.withValues(alpha: 0.06),
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Icon
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: accent.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Center(
                child: Text(log.emoji,
                    style: const TextStyle(fontSize: 20))),
          ),
          const SizedBox(width: 12),
          // Content
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (log.user != null)
                  Text(
                    log.user!.displayName,
                    style: const TextStyle(
                        fontWeight: FontWeight.w700, fontSize: 13),
                  ),
                const SizedBox(height: 2),
                Text(log.description,
                    style: const TextStyle(fontSize: 13)),
                const SizedBox(height: 4),
                Text(
                  _timeAgo(log.createdAt),
                  style: const TextStyle(
                      color: Colors.grey, fontSize: 11),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  String _timeAgo(DateTime? dt) {
    if (dt == null) return '';
    final diff = DateTime.now().difference(dt);
    if (diff.inMinutes < 1) return 'ahora';
    if (diff.inHours < 1) return 'hace ${diff.inMinutes}m';
    if (diff.inDays < 1) return 'hace ${diff.inHours}h';
    return 'hace ${diff.inDays}d';
  }
}

// ══════════════════════════════════════════════════════════════════════════════
//  TAB: AMIGOS
// ══════════════════════════════════════════════════════════════════════════════

class _FriendsTab extends ConsumerStatefulWidget {
  final SocialState social;
  final Color accent;

  const _FriendsTab({required this.social, required this.accent});

  @override
  ConsumerState<_FriendsTab> createState() => _FriendsTabState();
}

class _FriendsTabState extends ConsumerState<_FriendsTab> {
  final _searchCtrl = TextEditingController();

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final myId = widget.social.currentUser!.id;
    final friends = widget.social.friends;
    final accepted = friends.where((f) => f.status == 'accepted').toList();
    final pending  = friends.where((f) =>
        f.status == 'pending' && f.receiverId == myId).toList();
    final sent     = friends.where((f) =>
        f.status == 'pending' && f.requesterId == myId).toList();

    return RefreshIndicator(
      color: widget.accent,
      onRefresh: () => ref.read(socialProvider.notifier).loadFriends(),
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 100),
        children: [
          // ── Search / add friend ─────────────────────────────────
          _AddFriendBar(accent: widget.accent),
          const SizedBox(height: 20),

          // ── Pending received ────────────────────────────────────
          if (pending.isNotEmpty) ...[
            _SectionLabel(
                label: 'Solicitudes recibidas',
                count: pending.length,
                accent: widget.accent),
            ...pending.map((f) => _FriendRequestCard(
                friendship: f,
                myId: myId,
                accent: widget.accent,
                onAccept: () => ref
                    .read(socialProvider.notifier)
                    .respondToFriendRequest(f.id, 'accepted'),
                onReject: () => ref
                    .read(socialProvider.notifier)
                    .respondToFriendRequest(f.id, 'rejected'))),
            const SizedBox(height: 16),
          ],

          // ── Amigos aceptados ────────────────────────────────────
          _SectionLabel(
              label: 'Amigos',
              count: accepted.length,
              accent: widget.accent),
          if (accepted.isEmpty)
            _EmptyState(
              icon: Icons.people_outline_rounded,
              message: 'Aún no tienes amigos.\nBusca por username arriba.',
              accent: widget.accent,
              compact: true,
            )
          else
            ...accepted.map((f) {
              final other = f.requesterId == myId ? f.receiver : f.requester;
              return _FriendCard(
                user: other,
                accent: widget.accent,
                onRemove: () =>
                    ref.read(socialProvider.notifier).removeFriend(f.id),
              );
            }),

          // ── Sent pending ─────────────────────────────────────────
          if (sent.isNotEmpty) ...[
            const SizedBox(height: 16),
            _SectionLabel(
                label: 'Solicitudes enviadas',
                count: sent.length,
                accent: widget.accent),
            ...sent.map((f) => _SentRequestCard(
                friendship: f,
                myId: myId,
                accent: widget.accent,
                onCancel: () =>
                    ref.read(socialProvider.notifier).removeFriend(f.id))),
          ],
        ],
      ),
    );
  }
}

class _AddFriendBar extends ConsumerStatefulWidget {
  final Color accent;
  const _AddFriendBar({required this.accent});

  @override
  ConsumerState<_AddFriendBar> createState() => _AddFriendBarState();
}

class _AddFriendBarState extends ConsumerState<_AddFriendBar> {
  final _ctrl = TextEditingController();
  bool _loading = false;

  @override
  void dispose() { _ctrl.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: TextField(
            controller: _ctrl,
            style: const TextStyle(fontSize: 14),
            decoration: InputDecoration(
              hintText: 'Buscar por @username',
              prefixIcon:
                  const Icon(Icons.search_rounded, size: 20),
              border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14)),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide:
                    BorderSide(color: widget.accent, width: 1.5),
              ),
              contentPadding: const EdgeInsets.symmetric(
                  horizontal: 14, vertical: 12),
            ),
          ),
        ),
        const SizedBox(width: 10),
        SizedBox(
          height: 48,
          child: ElevatedButton(
            onPressed: _loading ? null : _send,
            style: ElevatedButton.styleFrom(
              backgroundColor: widget.accent,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14)),
              elevation: 0,
              padding: const EdgeInsets.symmetric(horizontal: 16),
            ),
            child: _loading
                ? const SizedBox(
                    width: 18, height: 18,
                    child: CircularProgressIndicator(
                        strokeWidth: 2, color: Colors.white))
                : const Icon(Icons.person_add_rounded, size: 20),
          ),
        ),
      ],
    );
  }

  Future<void> _send() async {
    final username = _ctrl.text.trim();
    if (username.isEmpty) return;
    setState(() => _loading = true);
    await ref.read(socialProvider.notifier).sendFriendRequest(username);
    if (mounted) {
      _ctrl.clear();
      setState(() => _loading = false);
    }
  }
}

class _SectionLabel extends StatelessWidget {
  final String label;
  final int count;
  final Color accent;

  const _SectionLabel(
      {required this.label, required this.count, required this.accent});

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(bottom: 10),
        child: Row(
          children: [
            Text(label,
                style: const TextStyle(
                    fontWeight: FontWeight.w700, fontSize: 13)),
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.symmetric(
                  horizontal: 8, vertical: 2),
              decoration: BoxDecoration(
                  color: accent.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(8)),
              child: Text('$count',
                  style: TextStyle(
                      color: accent,
                      fontSize: 11,
                      fontWeight: FontWeight.w700)),
            ),
          ],
        ),
      );
}

class _FriendCard extends StatelessWidget {
  final UserProfile? user;
  final Color accent;
  final VoidCallback onRemove;

  const _FriendCard(
      {required this.user,
      required this.accent,
      required this.onRemove});

  @override
  Widget build(BuildContext context) {
    if (user == null) return const SizedBox.shrink();
    return _SocialCard(
      leading: _AvatarBubble(user: user!, size: 44),
      title: user!.displayName,
      subtitle: '@${user!.username}',
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _StatChip('🔥', '${user!.completedBlocks}'),
          const SizedBox(width: 6),
          IconButton(
            icon: const Icon(Icons.person_remove_outlined,
                size: 18, color: Colors.redAccent),
            onPressed: onRemove,
            tooltip: 'Eliminar amigo',
          ),
        ],
      ),
    );
  }
}

class _FriendRequestCard extends StatelessWidget {
  final Friendship friendship;
  final int myId;
  final Color accent;
  final VoidCallback onAccept;
  final VoidCallback onReject;

  const _FriendRequestCard({
    required this.friendship,
    required this.myId,
    required this.accent,
    required this.onAccept,
    required this.onReject,
  });

  @override
  Widget build(BuildContext context) {
    final sender = friendship.requester;
    return _SocialCard(
      leading: _AvatarBubble(user: sender, size: 44),
      title: sender?.displayName ?? '?',
      subtitle: '@${sender?.username ?? ''}',
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          IconButton(
            icon: Icon(Icons.check_circle_rounded,
                color: accent, size: 24),
            onPressed: onAccept,
            tooltip: 'Aceptar',
          ),
          IconButton(
            icon: const Icon(Icons.cancel_rounded,
                color: Colors.redAccent, size: 24),
            onPressed: onReject,
            tooltip: 'Rechazar',
          ),
        ],
      ),
    );
  }
}

class _SentRequestCard extends StatelessWidget {
  final Friendship friendship;
  final int myId;
  final Color accent;
  final VoidCallback onCancel;

  const _SentRequestCard({
    required this.friendship,
    required this.myId,
    required this.accent,
    required this.onCancel,
  });

  @override
  Widget build(BuildContext context) {
    final receiver = friendship.receiver;
    return _SocialCard(
      leading: _AvatarBubble(user: receiver, size: 44),
      title: receiver?.displayName ?? '?',
      subtitle: '@${receiver?.username ?? ''}',
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(
                horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: Colors.orange.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                  color: Colors.orange.withValues(alpha: 0.3)),
            ),
            child: const Text('Pendiente',
                style: TextStyle(
                    color: Colors.orange,
                    fontSize: 11,
                    fontWeight: FontWeight.w600)),
          ),
          IconButton(
            icon: const Icon(Icons.close_rounded,
                size: 18, color: Colors.grey),
            onPressed: onCancel,
            tooltip: 'Cancelar',
          ),
        ],
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════════════════════════
//  TAB: RETOS
// ══════════════════════════════════════════════════════════════════════════════

class _ChallengesTab extends ConsumerStatefulWidget {
  final SocialState social;
  final Color accent;

  const _ChallengesTab({required this.social, required this.accent});

  @override
  ConsumerState<_ChallengesTab> createState() =>
      _ChallengesTabState();
}

class _ChallengesTabState extends ConsumerState<_ChallengesTab> {
  @override
  Widget build(BuildContext context) {
    final myId = widget.social.currentUser!.id;
    final challenges = widget.social.challenges;
    final active   = challenges.where((c) => c.status == 'active').toList();
    final pending  = challenges
        .where((c) => c.status == 'pending')
        .toList();
    final finished = challenges
        .where((c) =>
            c.status == 'completed' || c.status == 'rejected')
        .toList();

    return RefreshIndicator(
      color: widget.accent,
      onRefresh: () =>
          ref.read(socialProvider.notifier).loadChallenges(),
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 100),
        children: [
          // New challenge button
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: () => _showCreateChallenge(context),
              icon: const Icon(Icons.emoji_events_rounded),
              label: const Text('Nuevo reto'),
              style: OutlinedButton.styleFrom(
                foregroundColor: widget.accent,
                side: BorderSide(
                    color: widget.accent.withValues(alpha: 0.5)),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14)),
                padding: const EdgeInsets.symmetric(vertical: 14),
              ),
            ),
          ),
          const SizedBox(height: 20),

          // Active
          if (active.isNotEmpty) ...[
            _SectionLabel(
                label: 'Activos',
                count: active.length,
                accent: widget.accent),
            ...active.map((c) => _ChallengeCard(
                challenge: c,
                myId: myId,
                accent: widget.accent)),
            const SizedBox(height: 16),
          ],

          // Pending
          if (pending.isNotEmpty) ...[
            _SectionLabel(
                label: 'Pendientes',
                count: pending.length,
                accent: widget.accent),
            ...pending.map((c) => _ChallengeCard(
                challenge: c,
                myId: myId,
                accent: widget.accent)),
            const SizedBox(height: 16),
          ],

          if (active.isEmpty && pending.isEmpty)
            _EmptyState(
              icon: Icons.emoji_events_outlined,
              message:
                  'Sin retos activos.\nDesafía a un amigo.',
              accent: widget.accent,
              compact: true,
            ),

          // Finished
          if (finished.isNotEmpty) ...[
            _SectionLabel(
                label: 'Historial',
                count: finished.length,
                accent: widget.accent),
            ...finished.map((c) => _ChallengeCard(
                challenge: c,
                myId: myId,
                accent: widget.accent)),
          ],
        ],
      ),
    );
  }

  void _showCreateChallenge(BuildContext context) {
    final friends = widget.social.friends
        .where((f) => f.status == 'accepted')
        .toList();
    if (friends.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Necesitas amigos para crear un reto'),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _CreateChallengeSheet(
        social: widget.social,
        accent: widget.accent,
      ),
    );
  }
}

class _ChallengeCard extends ConsumerWidget {
  final Challenge challenge;
  final int myId;
  final Color accent;

  const _ChallengeCard({
    required this.challenge,
    required this.myId,
    required this.accent,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final isActive = challenge.status == 'active';
    final isCompleted = challenge.status == 'completed';
    final myPct   = challenge.progressPct(myId);
    final theirPct = myId == challenge.challengerId
        ? (challenge.challengedProgress / challenge.target).clamp(0.0, 1.0)
        : (challenge.challengerProgress / challenge.target).clamp(0.0, 1.0);
    final opponent = myId == challenge.challengerId
        ? challenge.challenged
        : challenge.challenger;
    final imWinner = challenge.winnerId == myId;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark
            ? Colors.white.withValues(alpha: 0.04)
            : Colors.black.withValues(alpha: 0.03),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isCompleted
              ? (imWinner
                  ? Colors.amber.withValues(alpha: 0.4)
                  : Colors.grey.withValues(alpha: 0.2))
              : (isDark
                  ? Colors.white.withValues(alpha: 0.07)
                  : Colors.black.withValues(alpha: 0.06)),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Title + status badge
          Row(
            children: [
              Expanded(
                child: Text(challenge.title,
                    style: const TextStyle(
                        fontWeight: FontWeight.w700, fontSize: 14)),
              ),
              _StatusBadge(status: challenge.status, accent: accent),
              if (imWinner)
                const Padding(
                  padding: EdgeInsets.only(left: 6),
                  child: Text('🏆',
                      style: TextStyle(fontSize: 16)),
                ),
            ],
          ),
          const SizedBox(height: 12),

          // My progress
          _ProgressRow(
            label: 'Tú',
            progress: challenge.myProgress(myId),
            target: challenge.target,
            pct: myPct,
            accent: accent,
          ),
          const SizedBox(height: 6),

          // Opponent progress
          _ProgressRow(
            label: opponent?.displayName ?? 'Rival',
            progress: challenge.opponentProgress(myId),
            target: challenge.target,
            pct: theirPct,
            accent: Colors.grey,
          ),

          if (isActive) ...[
            const SizedBox(height: 14),
            Row(
              children: [
                Text(
                  '${challenge.type == 'blocks' ? '🔥' : '✅'} '
                  '${challenge.type == 'blocks' ? 'Focus blocks' : 'Tareas'}  •  '
                  'Meta: ${challenge.target}',
                  style: const TextStyle(
                      color: Colors.grey, fontSize: 11),
                ),
              ],
            ),
          ],

          if (isCompleted && challenge.winnerId == null) ...[
            const SizedBox(height: 8),
            const Text('🤝 ¡Empate!',
                style: TextStyle(color: Colors.grey, fontSize: 12)),
          ],
        ],
      ),
    );
  }
}

class _ProgressRow extends StatelessWidget {
  final String label;
  final int progress;
  final int target;
  final double pct;
  final Color accent;

  const _ProgressRow({
    required this.label,
    required this.progress,
    required this.target,
    required this.pct,
    required this.accent,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        SizedBox(
          width: 68,
          child: Text(
            label,
            style: const TextStyle(fontSize: 12),
            overflow: TextOverflow.ellipsis,
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: pct,
              backgroundColor: accent.withValues(alpha: 0.12),
              valueColor: AlwaysStoppedAnimation(accent),
              minHeight: 6,
            ),
          ),
        ),
        const SizedBox(width: 8),
        Text(
          '$progress/$target',
          style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: accent),
        ),
      ],
    );
  }
}

class _StatusBadge extends StatelessWidget {
  final String status;
  final Color accent;
  const _StatusBadge({required this.status, required this.accent});

  @override
  Widget build(BuildContext context) {
    Color color;
    String label;
    switch (status) {
      case 'active':
        color = Colors.green;
        label = 'Activo';
        break;
      case 'pending':
        color = Colors.orange;
        label = 'Pendiente';
        break;
      case 'completed':
        color = Colors.amber;
        label = 'Terminado';
        break;
      default:
        color = Colors.grey;
        label = status;
    }
    return Container(
      padding:
          const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(6),
        border:
            Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Text(label,
          style: TextStyle(
              color: color,
              fontSize: 10,
              fontWeight: FontWeight.w700)),
    );
  }
}

class _CreateChallengeSheet extends ConsumerStatefulWidget {
  final SocialState social;
  final Color accent;
  const _CreateChallengeSheet(
      {required this.social, required this.accent});

  @override
  ConsumerState<_CreateChallengeSheet> createState() =>
      _CreateChallengeSheetState();
}

class _CreateChallengeSheetState
    extends ConsumerState<_CreateChallengeSheet> {
  final _titleCtrl = TextEditingController();
  int? _selectedFriendId;
  String _type = 'blocks';
  int _target = 10;
  DateTime _startDate = DateTime.now();
  DateTime _endDate = DateTime.now().add(const Duration(days: 1));
  bool _loading = false;

  @override
  void dispose() { _titleCtrl.dispose(); super.dispose(); }

  List<UserProfile> get _friendList {
    final myId = widget.social.currentUser!.id;
    final List<UserProfile> out = [];
    for (final f in widget.social.friends) {
      if (f.status != 'accepted') continue;
      if (f.requesterId == myId && f.receiver != null) out.add(f.receiver!);
      if (f.receiverId == myId && f.requester != null) out.add(f.requester!);
    }
    return out;
  }

  @override
  Widget build(BuildContext context) {
    final friends = _friendList;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      padding: EdgeInsets.only(
          bottom: MediaQuery.of(context).viewInsets.bottom),
      decoration: BoxDecoration(
        color: isDark
            ? const Color(0xFF121212)
            : const Color(0xFFF8F8F8),
        borderRadius:
            const BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 36, height: 4,
                margin: const EdgeInsets.only(bottom: 20),
                decoration: BoxDecoration(
                    color: Colors.grey.withValues(alpha: 0.3),
                    borderRadius: BorderRadius.circular(2)),
              ),
            ),
            const Text('Nuevo reto',
                style: TextStyle(
                    fontWeight: FontWeight.w800, fontSize: 18)),
            const SizedBox(height: 20),

            _SheetField(
              controller: _titleCtrl,
              label: 'Título del reto',
              accent: widget.accent,
            ),
            const SizedBox(height: 14),

            // Friend selector
            DropdownButtonFormField<int>(
              value: _selectedFriendId,
              decoration: InputDecoration(
                labelText: 'Desafiar a',
                border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12)),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(
                      color: widget.accent, width: 1.5),
                ),
                contentPadding: const EdgeInsets.symmetric(
                    horizontal: 14, vertical: 14),
              ),
              items: friends
                  .map((u) => DropdownMenuItem(
                        value: u.id,
                        child: Text(
                            '${u.avatarEmoji} ${u.displayName}'),
                      ))
                  .toList(),
              onChanged: (v) =>
                  setState(() => _selectedFriendId = v),
            ),
            const SizedBox(height: 14),

            // Type + target row
            Row(
              children: [
                Expanded(
                  child: DropdownButtonFormField<String>(
                    value: _type,
                    decoration: InputDecoration(
                      labelText: 'Tipo',
                      border: OutlineInputBorder(
                          borderRadius:
                              BorderRadius.circular(12)),
                      focusedBorder: OutlineInputBorder(
                        borderRadius:
                            BorderRadius.circular(12),
                        borderSide: BorderSide(
                            color: widget.accent,
                            width: 1.5),
                      ),
                      contentPadding:
                          const EdgeInsets.symmetric(
                              horizontal: 14, vertical: 14),
                    ),
                    items: const [
                      DropdownMenuItem(
                          value: 'blocks',
                          child: Text('🔥 Blocks')),
                      DropdownMenuItem(
                          value: 'tasks',
                          child: Text('✅ Tareas')),
                    ],
                    onChanged: (v) =>
                        setState(() => _type = v!),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: TextFormField(
                    initialValue: '$_target',
                    keyboardType: TextInputType.number,
                    decoration: InputDecoration(
                      labelText: 'Meta',
                      border: OutlineInputBorder(
                          borderRadius:
                              BorderRadius.circular(12)),
                      focusedBorder: OutlineInputBorder(
                        borderRadius:
                            BorderRadius.circular(12),
                        borderSide: BorderSide(
                            color: widget.accent,
                            width: 1.5),
                      ),
                      contentPadding:
                          const EdgeInsets.symmetric(
                              horizontal: 14, vertical: 14),
                    ),
                    onChanged: (v) =>
                        setState(() => _target = int.tryParse(v) ?? 10),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),

            // Dates row
            Row(
              children: [
                Expanded(
                  child: _DatePicker(
                    label: 'Inicio',
                    value: _startDate,
                    accent: widget.accent,
                    onPicked: (d) =>
                        setState(() => _startDate = d),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _DatePicker(
                    label: 'Fin',
                    value: _endDate,
                    accent: widget.accent,
                    onPicked: (d) =>
                        setState(() => _endDate = d),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 28),

            SizedBox(
              width: double.infinity,
              height: 52,
              child: ElevatedButton(
                onPressed: _loading ? null : _create,
                style: ElevatedButton.styleFrom(
                  backgroundColor: widget.accent,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                      borderRadius:
                          BorderRadius.circular(14)),
                  elevation: 0,
                ),
                child: _loading
                    ? const SizedBox(
                        width: 22, height: 22,
                        child: CircularProgressIndicator(
                            strokeWidth: 2.5,
                            color: Colors.white))
                    : const Text('Crear reto',
                        style: TextStyle(
                            fontWeight: FontWeight.w700,
                            fontSize: 15)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _create() async {
    if (_titleCtrl.text.trim().isEmpty || _selectedFriendId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text('Completa título y elige un amigo'),
            behavior: SnackBarBehavior.floating),
      );
      return;
    }
    final friends = _friendList;
    final opponent =
        friends.firstWhere((u) => u.id == _selectedFriendId);
    setState(() => _loading = true);
    await ref.read(socialProvider.notifier).createChallenge(
          title: _titleCtrl.text.trim(),
          challengedUsername: opponent.username,
          type: _type,
          target: _target,
          startDate:
              _startDate.toIso8601String().split('T').first,
          endDate: _endDate.toIso8601String().split('T').first,
        );
    if (mounted) Navigator.pop(context);
  }
}

class _DatePicker extends StatelessWidget {
  final String label;
  final DateTime value;
  final Color accent;
  final ValueChanged<DateTime> onPicked;

  const _DatePicker({
    required this.label,
    required this.value,
    required this.accent,
    required this.onPicked,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () async {
        final picked = await showDatePicker(
          context: context,
          initialDate: value,
          firstDate: DateTime.now().subtract(const Duration(days: 1)),
          lastDate: DateTime.now().add(const Duration(days: 365)),
          builder: (ctx, child) => Theme(
            data: Theme.of(ctx).copyWith(
              colorScheme: ColorScheme.fromSeed(seedColor: accent),
            ),
            child: child!,
          ),
        );
        if (picked != null) onPicked(picked);
      },
      child: Container(
        padding:
            const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
        decoration: BoxDecoration(
          border: Border.all(color: Colors.grey.withValues(alpha: 0.4)),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          children: [
            Icon(Icons.calendar_today_rounded,
                size: 16, color: accent),
            const SizedBox(width: 8),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(label,
                      style: const TextStyle(
                          fontSize: 10, color: Colors.grey)),
                  Text(
                    '${value.day}/${value.month}/${value.year}',
                    style: const TextStyle(
                        fontSize: 13, fontWeight: FontWeight.w600),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════════════════════════
//  Shared widgets
// ══════════════════════════════════════════════════════════════════════════════

class _AvatarBubble extends StatelessWidget {
  final UserProfile? user;
  final double size;
  const _AvatarBubble({required this.user, required this.size});

  @override
  Widget build(BuildContext context) {
    if (user == null) {
      return CircleAvatar(radius: size / 2, child: const Icon(Icons.person));
    }
    Color color;
    try {
      final hex = user!.avatarColor.replaceFirst('#', '');
      color = Color(int.parse('FF$hex', radix: 16));
    } catch (_) {
      color = Colors.blue;
    }
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: color.withValues(alpha: 0.18),
        border: Border.all(
            color: color.withValues(alpha: 0.4), width: 1.5),
      ),
      child: Center(
          child: Text(user!.avatarEmoji,
              style: TextStyle(fontSize: size * 0.5))),
    );
  }
}

class _StatChip extends StatelessWidget {
  final String emoji;
  final String value;
  const _StatChip(this.emoji, this.value);

  @override
  Widget build(BuildContext context) => Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(emoji, style: const TextStyle(fontSize: 14)),
          const SizedBox(width: 3),
          Text(value,
              style: const TextStyle(
                  fontWeight: FontWeight.w700, fontSize: 12)),
        ],
      );
}

class _SocialCard extends StatelessWidget {
  final Widget leading;
  final String title;
  final String subtitle;
  final Widget? trailing;

  const _SocialCard({
    required this.leading,
    required this.title,
    required this.subtitle,
    this.trailing,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding:
          const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: isDark
            ? Colors.white.withValues(alpha: 0.04)
            : Colors.black.withValues(alpha: 0.03),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: isDark
              ? Colors.white.withValues(alpha: 0.07)
              : Colors.black.withValues(alpha: 0.06),
        ),
      ),
      child: Row(
        children: [
          leading,
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title,
                    style: const TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 14)),
                const SizedBox(height: 2),
                Text(subtitle,
                    style: const TextStyle(
                        color: Colors.grey, fontSize: 12)),
              ],
            ),
          ),
          if (trailing != null) trailing!,
        ],
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  final IconData icon;
  final String message;
  final Color accent;
  final bool compact;

  const _EmptyState({
    required this.icon,
    required this.message,
    required this.accent,
    this.compact = false,
  });

  @override
  Widget build(BuildContext context) => Padding(
        padding: EdgeInsets.symmetric(vertical: compact ? 24 : 48),
        child: Column(
          children: [
            Icon(icon,
                size: compact ? 36 : 52,
                color: accent.withValues(alpha: 0.4)),
            const SizedBox(height: 12),
            Text(
              message,
              textAlign: TextAlign.center,
              style: const TextStyle(
                  color: Colors.grey, fontSize: 13),
            ),
          ],
        ),
      );
}

class _SheetField extends StatelessWidget {
  final TextEditingController controller;
  final String label;
  final Color accent;

  const _SheetField({
    required this.controller,
    required this.label,
    required this.accent,
  });

  @override
  Widget build(BuildContext context) => TextField(
        controller: controller,
        style: const TextStyle(fontSize: 14),
        decoration: InputDecoration(
          labelText: label,
          border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12)),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(color: accent, width: 1.5),
          ),
          contentPadding: const EdgeInsets.symmetric(
              horizontal: 14, vertical: 14),
        ),
      );
}
