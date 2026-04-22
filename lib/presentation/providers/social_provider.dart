import 'dart:convert';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:hive_flutter/hive_flutter.dart';
import '../../core/constants/app_constants.dart';
import '../../data/models/social_models.dart';
import '../../services/social_api_service.dart';

// ─── State ────────────────────────────────────────────────────────────────────

class SocialState {
  final UserProfile? currentUser;
  final String? token;
  final List<Friendship> friends;
  final List<Challenge> challenges;
  final List<ActivityLog> activityFeed;
  final List<UserProfile> allUsers;
  final bool isLoading;
  final String? error;

  const SocialState({
    this.currentUser,
    this.token,
    this.friends = const [],
    this.challenges = const [],
    this.activityFeed = const [],
    this.allUsers = const [],
    this.isLoading = false,
    this.error,
  });

  bool get isLoggedIn => token != null && currentUser != null;

  SocialState copyWith({
    UserProfile? currentUser,
    String? token,
    List<Friendship>? friends,
    List<Challenge>? challenges,
    List<ActivityLog>? activityFeed,
    List<UserProfile>? allUsers,
    bool? isLoading,
    String? error,
    bool clearError = false,
    bool clearUser = false,
  }) =>
      SocialState(
        currentUser: clearUser ? null : (currentUser ?? this.currentUser),
        token: clearUser ? null : (token ?? this.token),
        friends: friends ?? this.friends,
        challenges: challenges ?? this.challenges,
        activityFeed: activityFeed ?? this.activityFeed,
        allUsers: allUsers ?? this.allUsers,
        isLoading: isLoading ?? this.isLoading,
        error: clearError ? null : (error ?? this.error),
      );
}

// ─── Notifier ─────────────────────────────────────────────────────────────────

class SocialNotifier extends StateNotifier<SocialState> {
  SocialNotifier() : super(const SocialState()) {
    _restoreSession();
  }

  // Token goes to encrypted OS keystore; non-sensitive user profile stays in Hive.
  static const _secureStorage = FlutterSecureStorage();
  Box<dynamic> get _box => Hive.box(AppConstants.settingsBox);

  SocialApiService get _api => SocialApiService(token: state.token);

  // ─── Session persistence ──────────────────────────────────────────────────

  Future<void> _restoreSession() async {
    final token = await _secureStorage.read(key: AppConstants.keySocialToken);
    final userJson = _box.get(AppConstants.keySocialUser) as String?;
    if (token != null && userJson != null) {
      try {
        final user = UserProfile.fromJson(
            jsonDecode(userJson) as Map<String, dynamic>);
        state = state.copyWith(token: token, currentUser: user);
      } catch (_) {
        await _clearSession();
      }
    }
  }

  Future<void> _saveSession(String token, UserProfile user) async {
    await _secureStorage.write(key: AppConstants.keySocialToken, value: token);
    await _box.put(AppConstants.keySocialUser, jsonEncode(user.toJson()));
  }

  Future<void> _clearSession() async {
    await _secureStorage.delete(key: AppConstants.keySocialToken);
    await _box.delete(AppConstants.keySocialUser);
  }

  // ─── Auth ─────────────────────────────────────────────────────────────────

  Future<void> login({
    required String username,
    required String password,
  }) async {
    state = state.copyWith(isLoading: true, clearError: true);
    try {
      final res = await SocialApiService().login(
        username: username,
        password: password,
      );
      await _saveSession(res.token, res.user);
      state = state.copyWith(
        token: res.token,
        currentUser: res.user,
        isLoading: false,
      );
      // Load social data after login
      await loadAll();
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
    }
  }

  Future<void> register({
    required String username,
    required String displayName,
    required String password,
    String? email,
    String avatarEmoji = '🧑',
    String avatarColor = '#4A90E2',
    String bio = '',
  }) async {
    state = state.copyWith(isLoading: true, clearError: true);
    try {
      final res = await SocialApiService().register(
        username: username,
        displayName: displayName,
        password: password,
        email: email,
        avatarEmoji: avatarEmoji,
        avatarColor: avatarColor,
        bio: bio,
      );
      await _saveSession(res.token, res.user);
      state = state.copyWith(
        token: res.token,
        currentUser: res.user,
        isLoading: false,
      );
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
    }
  }

  Future<void> logout() async {
    await _clearSession();
    state = const SocialState();
  }

  void clearError() => state = state.copyWith(clearError: true);

  // ─── Load all ─────────────────────────────────────────────────────────────

  Future<void> loadAll() async {
    if (!state.isLoggedIn) return;
    await Future.wait([
      loadFriends(),
      loadChallenges(),
      loadFeed(),
      loadAllUsers(),
    ]);
  }

  // ─── Users ────────────────────────────────────────────────────────────────

  Future<void> loadAllUsers() async {
    if (!state.isLoggedIn) return;
    try {
      final users = await _api.getAllUsers();
      state = state.copyWith(allUsers: users);
    } catch (_) {}
  }

  // ─── Friends ──────────────────────────────────────────────────────────────

  Future<void> loadFriends() async {
    if (!state.isLoggedIn) return;
    try {
      final friends = await _api.getFriends();
      state = state.copyWith(friends: friends);
    } catch (e) {
      state = state.copyWith(error: e.toString());
    }
  }

  Future<void> sendFriendRequest(String username) async {
    if (!state.isLoggedIn) return;
    try {
      final f = await _api.sendFriendRequest(username);
      state = state.copyWith(friends: [...state.friends, f]);
    } catch (e) {
      state = state.copyWith(error: e.toString());
    }
  }

  Future<void> respondToFriendRequest(int friendshipId, String status) async {
    if (!state.isLoggedIn) return;
    try {
      final updated = await _api.respondToFriendRequest(friendshipId, status);
      state = state.copyWith(
        friends: state.friends
            .map((f) => f.id == friendshipId ? updated : f)
            .toList(),
      );
    } catch (e) {
      state = state.copyWith(error: e.toString());
    }
  }

  Future<void> removeFriend(int friendshipId) async {
    if (!state.isLoggedIn) return;
    try {
      await _api.removeFriend(friendshipId);
      state = state.copyWith(
        friends: state.friends.where((f) => f.id != friendshipId).toList(),
      );
    } catch (e) {
      state = state.copyWith(error: e.toString());
    }
  }

  // ─── Challenges ───────────────────────────────────────────────────────────

  Future<void> loadChallenges() async {
    if (!state.isLoggedIn) return;
    try {
      final challenges = await _api.getChallenges();
      state = state.copyWith(challenges: challenges);
    } catch (e) {
      state = state.copyWith(error: e.toString());
    }
  }

  Future<void> createChallenge({
    required String title,
    required String challengedUsername,
    String type = 'blocks',
    int target = 10,
    required String startDate,
    required String endDate,
  }) async {
    if (!state.isLoggedIn) return;
    try {
      final c = await _api.createChallenge(
        title: title,
        challengedUsername: challengedUsername,
        type: type,
        target: target,
        startDate: startDate,
        endDate: endDate,
      );
      state = state.copyWith(challenges: [c, ...state.challenges]);
    } catch (e) {
      state = state.copyWith(error: e.toString());
    }
  }

  Future<void> updateChallengeProgress({
    required int challengeId,
    required int myUserId,
    required int progress,
  }) async {
    if (!state.isLoggedIn) return;
    try {
      final challenge =
          state.challenges.firstWhere((c) => c.id == challengeId);
      final isChallenger = challenge.challengerId == myUserId;
      final updated = await _api.updateChallengeProgress(
        challengeId: challengeId,
        challengerProgress: isChallenger ? progress : null,
        challengedProgress: !isChallenger ? progress : null,
      );
      state = state.copyWith(
        challenges: state.challenges
            .map((c) => c.id == challengeId ? updated : c)
            .toList(),
      );
    } catch (e) {
      state = state.copyWith(error: e.toString());
    }
  }

  // ─── Activity ─────────────────────────────────────────────────────────────

  Future<void> loadFeed() async {
    if (!state.isLoggedIn) return;
    try {
      final feed = await _api.getActivityFeed();
      state = state.copyWith(activityFeed: feed);
    } catch (e) {
      state = state.copyWith(error: e.toString());
    }
  }

  Future<void> logActivity({
    required String type,
    required String description,
    bool isPublic = true,
  }) async {
    if (!state.isLoggedIn) return;
    try {
      await _api.logActivity(
          type: type, description: description, isPublic: isPublic);
      await loadFeed();
    } catch (_) {}
  }

  // ─── Sync user stats with backend ─────────────────────────────────────────

  Future<void> syncUserStats({
    required int completedBlocks,
    required int currentStreak,
  }) async {
    if (!state.isLoggedIn) return;
    try {
      await _api.updateMe(
        completedBlocks: completedBlocks,
        currentStreak: currentStreak,
      );
      state = state.copyWith(
        currentUser: state.currentUser?.copyWith(
          completedBlocks: completedBlocks,
          currentStreak: currentStreak,
        ),
      );
    } catch (_) {}
  }
}

// ─── Provider ─────────────────────────────────────────────────────────────────

final socialProvider =
    StateNotifierProvider<SocialNotifier, SocialState>((ref) => SocialNotifier());
