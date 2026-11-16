import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

class SearchHistoryStore {
  static const String _historyKey = 'chat.search.history';
  static const String _senderKey = 'chat.search.sender';
  static const String _typeKey = 'chat.search.type';
  static const int _maxHistory = 6;

  static Future<List<String>> loadHistory() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_historyKey);
    if (raw == null || raw.isEmpty) {
      return const [];
    }
    try {
      final decoded = jsonDecode(raw);
      if (decoded is! List) {
        return const [];
      }
      return decoded
          .whereType<String>()
          .map((item) => item.trim())
          .where((item) => item.isNotEmpty)
          .take(_maxHistory)
          .toList();
    } catch (_) {
      return const [];
    }
  }

  static Future<List<String>> addQuery(String query) async {
    final value = query.trim();
    if (value.isEmpty) {
      return loadHistory();
    }
    final history = await loadHistory();
    history.removeWhere((item) => item.toLowerCase() == value.toLowerCase());
    history.insert(0, value);
    final next = history.take(_maxHistory).toList();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_historyKey, jsonEncode(next));
    return next;
  }

  static Future<void> clearHistory() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_historyKey);
  }

  static Future<String> loadSenderFilter() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_senderKey) ?? 'all';
  }

  static Future<void> saveSenderFilter(String value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_senderKey, value);
  }

  static Future<String> loadTypeFilter() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_typeKey) ?? 'all';
  }

  static Future<void> saveTypeFilter(String value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_typeKey, value);
  }
}
