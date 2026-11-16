import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

class FavoriteMessage {
  const FavoriteMessage({
    required this.key,
    required this.text,
    required this.sender,
    required this.createdAt,
    this.imagePath = '',
  });

  final String key;
  final String text;
  final String sender;
  final DateTime createdAt;
  final String imagePath;

  Map<String, dynamic> toJson() {
    return {
      'key': key,
      'text': text,
      'sender': sender,
      'createdAt': createdAt.toIso8601String(),
      'imagePath': imagePath,
    };
  }

  static FavoriteMessage? fromJson(dynamic value) {
    if (value is! Map) {
      return null;
    }
    final key = value['key'];
    final text = value['text'];
    final sender = value['sender'];
    final createdAt = value['createdAt'];
    if (key is! String ||
        text is! String ||
        sender is! String ||
        createdAt is! String) {
      return null;
    }
    final parsed = DateTime.tryParse(createdAt);
    if (parsed == null) {
      return null;
    }
    return FavoriteMessage(
      key: key,
      text: text,
      sender: sender,
      createdAt: parsed,
      imagePath: value['imagePath'] is String
          ? value['imagePath'] as String
          : '',
    );
  }
}

class FavoriteStore {
  static const String _prefix = 'chat.favorites.';
  static const int _maxItems = 200;

  static Future<List<FavoriteMessage>> load(String userId) async {
    if (userId.isEmpty) {
      return const [];
    }
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_prefix + userId);
    if (raw == null || raw.isEmpty) {
      return const [];
    }
    try {
      final decoded = jsonDecode(raw);
      if (decoded is! List) {
        return const [];
      }
      return decoded
          .map(FavoriteMessage.fromJson)
          .whereType<FavoriteMessage>()
          .take(_maxItems)
          .toList();
    } catch (_) {
      return const [];
    }
  }

  static Future<bool> toggle(String userId, FavoriteMessage message) async {
    if (userId.isEmpty) {
      return false;
    }
    final items = await load(userId);
    final index = items.indexWhere((item) => item.key == message.key);
    final added = index < 0;
    if (added) {
      items.insert(0, message);
    } else {
      items.removeAt(index);
    }
    await _save(userId, items.take(_maxItems).toList());
    return added;
  }

  static Future<int> addAll(
    String userId,
    List<FavoriteMessage> messages,
  ) async {
    if (userId.isEmpty || messages.isEmpty) {
      return 0;
    }
    final items = await load(userId);
    final existing = items.map((item) => item.key).toSet();
    final sorted = [...messages]
      ..sort((a, b) => a.createdAt.compareTo(b.createdAt));
    var added = 0;
    for (final message in sorted) {
      if (existing.add(message.key)) {
        items.insert(0, message);
        added += 1;
      }
    }
    if (added > 0) {
      await _save(userId, items.take(_maxItems).toList());
    }
    return added;
  }

  static Future<void> clear(String userId) async {
    if (userId.isEmpty) {
      return;
    }
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_prefix + userId);
  }

  static Future<void> remove(String userId, String key) async {
    if (userId.isEmpty) {
      return;
    }
    final items = await load(userId)
      ..removeWhere((item) => item.key == key);
    await _save(userId, items);
  }

  static Future<void> _save(String userId, List<FavoriteMessage> items) async {
    final prefs = await SharedPreferences.getInstance();
    if (items.isEmpty) {
      await prefs.remove(_prefix + userId);
      return;
    }
    await prefs.setString(
      _prefix + userId,
      jsonEncode(items.map((item) => item.toJson()).toList()),
    );
  }
}
