// ─── UserProfile ──────────────────────────────────────────────────────────────

class UserProfile {
  final int id;
  final String username;
  final String displayName;
  final String? email;
  final String avatarEmoji;
  final String avatarColor;
  final String bio;
  final int completedBlocks;
  final int currentStreak;
  final bool isActive;

  const UserProfile({
    required this.id,
    required this.username,
    required this.displayName,
    this.email,
    this.avatarEmoji = '🧑',
    this.avatarColor = '#4A90E2',
    this.bio = '',
    this.completedBlocks = 0,
    this.currentStreak = 0,
    this.isActive = true,
  });

  factory UserProfile.fromJson(Map<String, dynamic> j) => UserProfile(
        id: j['id'] as int,
        username: j['username'] as String,
        displayName: j['display_name'] as String,
        email: j['email'] as String?,
        avatarEmoji: j['avatar_emoji'] as String? ?? '🧑',
        avatarColor: j['avatar_color'] as String? ?? '#4A90E2',
        bio: j['bio'] as String? ?? '',
        completedBlocks: j['completed_blocks'] as int? ?? 0,
        currentStreak: j['current_streak'] as int? ?? 0,
        isActive: j['is_active'] as bool? ?? true,
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'username': username,
        'display_name': displayName,
        'email': email,
        'avatar_emoji': avatarEmoji,
        'avatar_color': avatarColor,
        'bio': bio,
        'completed_blocks': completedBlocks,
        'current_streak': currentStreak,
        'is_active': isActive,
      };

  UserProfile copyWith({
    int? completedBlocks,
    int? currentStreak,
    String? displayName,
    String? bio,
    String? avatarEmoji,
    String? avatarColor,
  }) =>
      UserProfile(
        id: id,
        username: username,
        displayName: displayName ?? this.displayName,
        email: email,
        avatarEmoji: avatarEmoji ?? this.avatarEmoji,
        avatarColor: avatarColor ?? this.avatarColor,
        bio: bio ?? this.bio,
        completedBlocks: completedBlocks ?? this.completedBlocks,
        currentStreak: currentStreak ?? this.currentStreak,
        isActive: isActive,
      );
}

// ─── Friendship ───────────────────────────────────────────────────────────────

class Friendship {
  final int id;
  final int requesterId;
  final int receiverId;
  final String status; // pending | accepted | rejected
  final DateTime? createdAt;
  final UserProfile? requester;
  final UserProfile? receiver;

  const Friendship({
    required this.id,
    required this.requesterId,
    required this.receiverId,
    required this.status,
    this.createdAt,
    this.requester,
    this.receiver,
  });

  factory Friendship.fromJson(Map<String, dynamic> j) => Friendship(
        id: j['id'] as int,
        requesterId: j['requester_id'] as int,
        receiverId: j['receiver_id'] as int,
        status: j['status'] as String,
        createdAt: j['created_at'] != null
            ? DateTime.tryParse(j['created_at'] as String)
            : null,
        requester: j['requester'] != null
            ? UserProfile.fromJson(j['requester'] as Map<String, dynamic>)
            : null,
        receiver: j['receiver'] != null
            ? UserProfile.fromJson(j['receiver'] as Map<String, dynamic>)
            : null,
      );
}

// ─── Challenge ────────────────────────────────────────────────────────────────

class Challenge {
  final int id;
  final String title;
  final int challengerId;
  final int challengedId;
  final String type; // blocks | tasks
  final int target;
  final String startDate;
  final String endDate;
  final String status; // pending | active | completed | rejected
  final int challengerProgress;
  final int challengedProgress;
  final int? winnerId;
  final DateTime? createdAt;
  final UserProfile? challenger;
  final UserProfile? challenged;
  final UserProfile? winner;

  const Challenge({
    required this.id,
    required this.title,
    required this.challengerId,
    required this.challengedId,
    required this.type,
    required this.target,
    required this.startDate,
    required this.endDate,
    required this.status,
    required this.challengerProgress,
    required this.challengedProgress,
    this.winnerId,
    this.createdAt,
    this.challenger,
    this.challenged,
    this.winner,
  });

  factory Challenge.fromJson(Map<String, dynamic> j) => Challenge(
        id: j['id'] as int,
        title: j['title'] as String,
        challengerId: j['challenger_id'] as int,
        challengedId: j['challenged_id'] as int,
        type: j['type'] as String,
        target: j['target'] as int,
        startDate: j['start_date'] as String,
        endDate: j['end_date'] as String,
        status: j['status'] as String,
        challengerProgress: j['challenger_progress'] as int? ?? 0,
        challengedProgress: j['challenged_progress'] as int? ?? 0,
        winnerId: j['winner_id'] as int?,
        createdAt: j['created_at'] != null
            ? DateTime.tryParse(j['created_at'] as String)
            : null,
        challenger: j['challenger'] != null
            ? UserProfile.fromJson(j['challenger'] as Map<String, dynamic>)
            : null,
        challenged: j['challenged'] != null
            ? UserProfile.fromJson(j['challenged'] as Map<String, dynamic>)
            : null,
        winner: j['winner'] != null
            ? UserProfile.fromJson(j['winner'] as Map<String, dynamic>)
            : null,
      );

  double progressPct(int userId) {
    if (userId == challengerId) {
      return target > 0 ? (challengerProgress / target).clamp(0.0, 1.0) : 0;
    }
    return target > 0 ? (challengedProgress / target).clamp(0.0, 1.0) : 0;
  }

  int myProgress(int userId) =>
      userId == challengerId ? challengerProgress : challengedProgress;

  int opponentProgress(int userId) =>
      userId == challengerId ? challengedProgress : challengerProgress;
}

// ─── ActivityLog ──────────────────────────────────────────────────────────────

class ActivityLog {
  final int id;
  final int userId;
  final String type; // task_completed | blocks_completed | challenge_won | streak_achieved | friend_added
  final String description;
  final String? data;
  final bool isPublic;
  final DateTime? createdAt;
  final UserProfile? user;

  const ActivityLog({
    required this.id,
    required this.userId,
    required this.type,
    required this.description,
    this.data,
    this.isPublic = true,
    this.createdAt,
    this.user,
  });

  factory ActivityLog.fromJson(Map<String, dynamic> j) => ActivityLog(
        id: j['id'] as int,
        userId: j['user_id'] as int,
        type: j['type'] as String,
        description: j['description'] as String,
        data: j['data'] as String?,
        isPublic: j['is_public'] as bool? ?? true,
        createdAt: j['created_at'] != null
            ? DateTime.tryParse(j['created_at'] as String)
            : null,
        user: j['user'] != null
            ? UserProfile.fromJson(j['user'] as Map<String, dynamic>)
            : null,
      );

  String get emoji {
    switch (type) {
      case 'task_completed':    return '✅';
      case 'blocks_completed':  return '🔥';
      case 'challenge_won':     return '🏆';
      case 'streak_achieved':   return '⚡';
      case 'friend_added':      return '🤝';
      default:                  return '📌';
    }
  }
}

// ─── Auth response ────────────────────────────────────────────────────────────

class AuthResponse {
  final String token;
  final UserProfile user;

  const AuthResponse({required this.token, required this.user});

  factory AuthResponse.fromJson(Map<String, dynamic> j) => AuthResponse(
        token: j['token'] as String,
        user: UserProfile.fromJson(j['user'] as Map<String, dynamic>),
      );
}
