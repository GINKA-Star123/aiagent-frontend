import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

/// 离线/失败待重发的消息。只存"投递所需"的最小字段，正文已在聊天历史里。
class OutboxEntry {
  const OutboxEntry({
    required this.clientMessageId,
    required this.text,
    required this.imagePath,
    required this.createdAt,
    this.attempts = 0,
    this.nextAttemptAt,
  });

  final String clientMessageId;
  final String text;
  final String imagePath;
  final DateTime createdAt;
  final int attempts;
  final DateTime? nextAttemptAt;

  bool get isDue {
    final next = nextAttemptAt;
    return next == null || !DateTime.now().isBefore(next);
  }

  OutboxEntry copyWith({int? attempts, DateTime? nextAttemptAt}) {
    return OutboxEntry(
      clientMessageId: clientMessageId,
      text: text,
      imagePath: imagePath,
      createdAt: createdAt,
      attempts: attempts ?? this.attempts,
      nextAttemptAt: nextAttemptAt ?? this.nextAttemptAt,
    );
  }

  factory OutboxEntry.fromJson(Map<String, dynamic> json) {
    return OutboxEntry(
      clientMessageId: json['clientMessageId']?.toString() ?? '',
      text: json['text']?.toString() ?? '',
      imagePath: json['imagePath']?.toString() ?? '',
      createdAt:
          DateTime.tryParse(json['createdAt']?.toString() ?? '') ??
          DateTime.now(),
      attempts: int.tryParse(json['attempts']?.toString() ?? '') ?? 0,
      nextAttemptAt: DateTime.tryParse(json['nextAttemptAt']?.toString() ?? ''),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'clientMessageId': clientMessageId,
      'text': text,
      'imagePath': imagePath,
      'createdAt': createdAt.toIso8601String(),
      'attempts': attempts,
      'nextAttemptAt': nextAttemptAt?.toIso8601String(),
    };
  }
}

/// 退避：5s -> 15s -> 45s -> 2min -> 5min（之后保持 5min）。
Duration outboxBackoff(int attempts) {
  const seconds = [5, 15, 45, 120, 300];
  final index = attempts.clamp(0, seconds.length - 1);
  return Duration(seconds: seconds[index]);
}

class OutboxStore {
  OutboxStore({this.userId = ''});

  final String userId;

  String get _key =>
      userId.isEmpty ? 'chat.outbox.v1' : 'chat.outbox.v1.$userId';

  Future<List<OutboxEntry>> load() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_key) ?? '';
    if (raw.isEmpty) {
      return [];
    }
    try {
      final decoded = jsonDecode(raw);
      if (decoded is! List) {
        return [];
      }
      return decoded
          .whereType<Map>()
          .map(
            (item) => OutboxEntry.fromJson(
              item.map((key, dynamic value) => MapEntry(key.toString(), value)),
            ),
          )
          .where((entry) => entry.clientMessageId.isNotEmpty)
          .toList();
    } on FormatException {
      return [];
    }
  }

  Future<void> save(List<OutboxEntry> entries) async {
    final prefs = await SharedPreferences.getInstance();
    final payload = entries
        .map((entry) => entry.toJson())
        .toList(growable: false);
    await prefs.setString(_key, jsonEncode(payload));
  }
}
