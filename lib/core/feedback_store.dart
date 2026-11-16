import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

/// 本地点踩/点赞记录，key 为消息的 requestId（没有则用 clientMessageId）。
class FeedbackStore {
  FeedbackStore({this.userId = ''});

  final String userId;

  String get _key =>
      userId.isEmpty ? 'chat.feedback.v1' : 'chat.feedback.v1.$userId';

  Future<Map<String, Map<String, dynamic>>> load() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_key) ?? '';
    if (raw.isEmpty) {
      return {};
    }
    try {
      final decoded = jsonDecode(raw);
      if (decoded is! Map) {
        return {};
      }
      return decoded.map(
        (key, value) => MapEntry(
          key.toString(),
          value is Map
              ? value.map((k, v) => MapEntry(k.toString(), v))
              : <String, dynamic>{},
        ),
      );
    } on FormatException {
      return {};
    }
  }

  Future<void> set(String messageKey, int rating, List<String> tags) async {
    final all = await load();
    all[messageKey] = {
      'rating': rating,
      'tags': tags,
      'ts': DateTime.now().toIso8601String(),
    };
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_key, jsonEncode(all));
  }
}
