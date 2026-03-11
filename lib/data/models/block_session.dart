import 'dart:convert';

class BlockSession {
  final String id;
  final DateTime unlockedAt;
  final DateTime expiresAt;
  bool isActive;

  BlockSession({
    required this.id,
    required this.unlockedAt,
    required this.expiresAt,
    this.isActive = true,
  });

  bool get isExpired => DateTime.now().isAfter(expiresAt);

  int get remainingMinutes {
    final diff = expiresAt.difference(DateTime.now()).inMinutes;
    return diff < 0 ? 0 : diff;
  }

  int get remainingSeconds {
    final diff = expiresAt.difference(DateTime.now()).inSeconds;
    return diff < 0 ? 0 : diff;
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'unlockedAt': unlockedAt.toIso8601String(),
        'expiresAt': expiresAt.toIso8601String(),
        'isActive': isActive,
      };

  factory BlockSession.fromJson(Map<String, dynamic> json) => BlockSession(
        id: json['id'] as String,
        unlockedAt: DateTime.parse(json['unlockedAt']),
        expiresAt: DateTime.parse(json['expiresAt']),
        isActive: json['isActive'] as bool? ?? true,
      );

  String toJsonString() => jsonEncode(toJson());
  factory BlockSession.fromJsonString(String s) => BlockSession.fromJson(jsonDecode(s));
}
