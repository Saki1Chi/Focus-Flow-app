import 'dart:convert';
import 'package:http/http.dart' as http;
import '../core/constants/app_constants.dart';
import '../data/models/social_models.dart';

/// HTTP client for all FocusFlow social endpoints.
/// Authenticated calls require [token] (X-Token header).
class SocialApiService {
  SocialApiService({String? baseUrl, this.token})
      : _base = baseUrl ?? AppConstants.apiBaseUrl;

  final String _base;
  final String? token;

  static const _timeout = Duration(seconds: 15);

  Map<String, String> get _headers => {
        'Content-Type': 'application/json',
        if (token != null) 'X-Token': token!,
      };

  void _assertOk(http.Response res) {
    if (res.statusCode < 200 || res.statusCode >= 300) {
      String detail = 'HTTP ${res.statusCode}';
      try {
        final body = jsonDecode(res.body);
        if (body is Map && body.containsKey('detail')) {
          detail = body['detail'].toString();
        }
      } catch (_) {}
      throw Exception(detail);
    }
  }

  // ─── Auth ─────────────────────────────────────────────────────────────────

  Future<AuthResponse> register({
    required String username,
    required String displayName,
    required String password,
    String? email,
    String avatarEmoji = '🧑',
    String avatarColor = '#4A90E2',
    String bio = '',
  }) async {
    final uri = Uri.parse('$_base/api/users/register');
    final res = await http
        .post(
          uri,
          headers: _headers,
          body: jsonEncode({
            'username': username,
            'display_name': displayName,
            'password': password,
            if (email != null && email.isNotEmpty) 'email': email,
            'avatar_emoji': avatarEmoji,
            'avatar_color': avatarColor,
            'bio': bio,
          }),
        )
        .timeout(_timeout);
    _assertOk(res);
    return AuthResponse.fromJson(jsonDecode(res.body));
  }

  Future<AuthResponse> login({
    required String username,
    required String password,
  }) async {
    final uri = Uri.parse('$_base/api/users/login');
    final res = await http
        .post(
          uri,
          headers: _headers,
          body: jsonEncode({'username': username, 'password': password}),
        )
        .timeout(_timeout);
    _assertOk(res);
    return AuthResponse.fromJson(jsonDecode(res.body));
  }

  Future<UserProfile> getMe() async {
    final uri = Uri.parse('$_base/api/users/me');
    final res = await http.get(uri, headers: _headers).timeout(_timeout);
    _assertOk(res);
    return UserProfile.fromJson(jsonDecode(res.body));
  }

  Future<List<UserProfile>> getAllUsers() async {
    final uri = Uri.parse('$_base/api/users');
    final res = await http.get(uri, headers: _headers).timeout(_timeout);
    _assertOk(res);
    final List data = jsonDecode(res.body);
    return data.map((j) => UserProfile.fromJson(j)).toList();
  }

  Future<void> updateMe({
    int? completedBlocks,
    int? currentStreak,
    String? displayName,
    String? bio,
    String? avatarEmoji,
    String? avatarColor,
  }) async {
    final me = await getMe();
    final uri = Uri.parse('$_base/api/users/${me.id}');
    final body = <String, dynamic>{};
    if (completedBlocks != null) body['completed_blocks'] = completedBlocks;
    if (currentStreak   != null) body['current_streak']   = currentStreak;
    if (displayName     != null) body['display_name']      = displayName;
    if (bio             != null) body['bio']               = bio;
    if (avatarEmoji     != null) body['avatar_emoji']      = avatarEmoji;
    if (avatarColor     != null) body['avatar_color']      = avatarColor;
    final res = await http
        .put(uri, headers: _headers, body: jsonEncode(body))
        .timeout(_timeout);
    _assertOk(res);
  }

  // ─── Friends ──────────────────────────────────────────────────────────────

  Future<List<Friendship>> getFriends() async {
    final uri = Uri.parse('$_base/api/social/friends');
    final res = await http.get(uri, headers: _headers).timeout(_timeout);
    _assertOk(res);
    final List data = jsonDecode(res.body);
    return data.map((j) => Friendship.fromJson(j)).toList();
  }

  Future<Friendship> sendFriendRequest(String receiverUsername) async {
    final uri = Uri.parse('$_base/api/social/friends/request');
    final res = await http
        .post(
          uri,
          headers: _headers,
          body: jsonEncode({'receiver_username': receiverUsername}),
        )
        .timeout(_timeout);
    _assertOk(res);
    return Friendship.fromJson(jsonDecode(res.body));
  }

  Future<Friendship> respondToFriendRequest(int friendshipId, String status) async {
    final uri = Uri.parse(
        '$_base/api/social/friends/$friendshipId?status=$status');
    final res = await http.put(uri, headers: _headers).timeout(_timeout);
    _assertOk(res);
    return Friendship.fromJson(jsonDecode(res.body));
  }

  Future<void> removeFriend(int friendshipId) async {
    final uri = Uri.parse('$_base/api/social/friends/$friendshipId');
    final res = await http.delete(uri, headers: _headers).timeout(_timeout);
    _assertOk(res);
  }

  // ─── Challenges ───────────────────────────────────────────────────────────

  Future<List<Challenge>> getChallenges() async {
    final uri = Uri.parse('$_base/api/social/challenges');
    final res = await http.get(uri, headers: _headers).timeout(_timeout);
    _assertOk(res);
    final List data = jsonDecode(res.body);
    return data.map((j) => Challenge.fromJson(j)).toList();
  }

  Future<Challenge> createChallenge({
    required String title,
    required String challengedUsername,
    String type = 'blocks',
    int target = 10,
    required String startDate,
    required String endDate,
  }) async {
    final uri = Uri.parse('$_base/api/social/challenges');
    final res = await http
        .post(
          uri,
          headers: _headers,
          body: jsonEncode({
            'title': title,
            'challenged_username': challengedUsername,
            'type': type,
            'target': target,
            'start_date': startDate,
            'end_date': endDate,
          }),
        )
        .timeout(_timeout);
    _assertOk(res);
    return Challenge.fromJson(jsonDecode(res.body));
  }

  Future<Challenge> updateChallengeProgress({
    required int challengeId,
    int? challengerProgress,
    int? challengedProgress,
    String? status,
  }) async {
    final uri = Uri.parse('$_base/api/social/challenges/$challengeId');
    final body = <String, dynamic>{};
    if (challengerProgress != null) body['challenger_progress'] = challengerProgress;
    if (challengedProgress != null) body['challenged_progress'] = challengedProgress;
    if (status != null) body['status'] = status;
    final res = await http
        .put(uri, headers: _headers, body: jsonEncode(body))
        .timeout(_timeout);
    _assertOk(res);
    return Challenge.fromJson(jsonDecode(res.body));
  }

  // ─── Activity ─────────────────────────────────────────────────────────────

  Future<List<ActivityLog>> getActivityFeed({int limit = 50}) async {
    final uri = Uri.parse('$_base/api/social/activity?limit=$limit');
    final res = await http.get(uri, headers: _headers).timeout(_timeout);
    _assertOk(res);
    final List data = jsonDecode(res.body);
    return data.map((j) => ActivityLog.fromJson(j)).toList();
  }

  Future<void> logActivity({
    required String type,
    required String description,
    String? data,
    bool isPublic = true,
  }) async {
    final uri = Uri.parse('$_base/api/social/activity');
    final res = await http
        .post(
          uri,
          headers: _headers,
          body: jsonEncode({
            'type': type,
            'description': description,
            if (data != null) 'data': data,
            'is_public': isPublic,
          }),
        )
        .timeout(_timeout);
    _assertOk(res);
  }
}
