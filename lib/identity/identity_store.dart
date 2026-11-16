import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import 'user_identity.dart';

class IdentityStore {
  static const String _identityKey = 'identity.current';
  static const String _emailAliasesKey = 'identity.emailAliases';

  Future<UserIdentity?> load() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_identityKey);
    if (raw == null || raw.isEmpty) {
      return null;
    }
    try {
      final json = jsonDecode(raw);
      if (json is Map<String, dynamic>) {
        return UserIdentity.fromJson(json);
      }
      if (json is Map) {
        return UserIdentity.fromJson(
          json.map((key, value) => MapEntry(key.toString(), value)),
        );
      }
    } catch (_) {
      return null;
    }
    return null;
  }

  Future<void> save(UserIdentity identity) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_identityKey, jsonEncode(identity.toJson()));
  }

  Future<void> clear() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_identityKey);
  }

  Future<Map<String, String>> _loadEmailAliases() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_emailAliasesKey);
    if (raw == null || raw.isEmpty) {
      return <String, String>{};
    }
    try {
      final decoded = jsonDecode(raw);
      if (decoded is! Map) {
        return <String, String>{};
      }
      return decoded.map(
        (key, value) => MapEntry(key.toString(), value.toString()),
      );
    } catch (_) {
      return <String, String>{};
    }
  }

  Future<String?> usernameForEmail(String email) async {
    final aliases = await _loadEmailAliases();
    return aliases[email.trim().toLowerCase()];
  }

  Future<bool> emailAliasExists(String email) async {
    return (await usernameForEmail(email)) != null;
  }

  Future<void> saveEmailAlias(String email, String username) async {
    final normalized = email.trim().toLowerCase();
    if (normalized.isEmpty || username.trim().isEmpty) {
      return;
    }
    final prefs = await SharedPreferences.getInstance();
    final aliases = await _loadEmailAliases();
    aliases[normalized] = username.trim();
    await prefs.setString(_emailAliasesKey, jsonEncode(aliases));
  }
}
