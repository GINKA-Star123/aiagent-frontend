import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';

import 'user_identity.dart';

class IdentityStore {
  static const String _identityKey = 'identity.current';
  static const String _accountsKey = 'identity.accounts';

  final Uuid _uuid = const Uuid();

  Future<UserIdentity?> load() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_identityKey);

    if (raw != null && raw.isNotEmpty) {
      final json = jsonDecode(raw);
      if (json is Map<String, dynamic>) {
        return UserIdentity.fromJson(json);
      }

      if (json is Map) {
        return UserIdentity.fromJson(
          json.map((key, dynamic value) => MapEntry(key.toString(), value)),
        );
      }
    }

    return null;
  }

  Future<UserIdentity> loadOrCreate() async {
    final current = await load();
    if (current != null) {
      return current;
    }

    final identity = UserIdentity(
      userId: 'mobile_${_uuid.v4()}',
      username: 'Guest',
      deviceId: 'device_${_uuid.v4()}',
      createdAt: DateTime.now(),
    );

    await save(identity);
    return identity;
  }

  Future<void> save(UserIdentity identity) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_identityKey, jsonEncode(identity.toJson()));
  }

  Future<UserIdentity> register({
    required String username,
    required String password,
    required String inviteCode,
  }) async {
    final normalizedName = username.trim();
    if (normalizedName.length < 2) {
      throw Exception('用户名至少需要 2 个字符。');
    }
    if (password.length < 6) {
      throw Exception('密码至少需要 6 个字符。');
    }
    if (!_InviteCode.allowed(inviteCode)) {
      throw Exception('邀请码无效。');
    }

    final prefs = await SharedPreferences.getInstance();
    final accounts = _loadAccounts(prefs);
    final accountKey = normalizedName.toLowerCase();

    if (accounts.containsKey(accountKey)) {
      throw Exception('这个用户名已经注册过了。');
    }

    final identity = UserIdentity(
      userId: 'mobile_${_uuid.v4()}',
      username: normalizedName,
      deviceId: 'device_${_uuid.v4()}',
      createdAt: DateTime.now(),
    );

    accounts[accountKey] = {
      'passwordHash': _hashPassword(password),
      'identity': identity.toJson(),
    };

    await prefs.setString(_accountsKey, jsonEncode(accounts));
    await save(identity);
    return identity;
  }

  Future<UserIdentity> login({
    required String username,
    required String password,
  }) async {
    final normalizedName = username.trim();
    final prefs = await SharedPreferences.getInstance();
    final accounts = _loadAccounts(prefs);
    final account = accounts[normalizedName.toLowerCase()];

    if (account == null) {
      throw Exception('账号不存在，请先注册。');
    }

    final savedHash = account['passwordHash']?.toString() ?? '';
    if (savedHash != _hashPassword(password)) {
      throw Exception('密码不正确。');
    }

    final rawIdentity = account['identity'];
    if (rawIdentity is! Map) {
      throw Exception('账号数据损坏，请重新注册。');
    }

    final identity = UserIdentity.fromJson(
      rawIdentity.map((key, dynamic value) => MapEntry(key.toString(), value)),
    );

    await save(identity);
    return identity;
  }

  Map<String, dynamic> _loadAccounts(SharedPreferences prefs) {
    final raw = prefs.getString(_accountsKey);
    if (raw == null || raw.isEmpty) {
      return {};
    }

    final json = jsonDecode(raw);
    if (json is Map<String, dynamic>) {
      return json;
    }

    if (json is Map) {
      return json.map((key, dynamic value) => MapEntry(key.toString(), value));
    }

    return {};
  }

  String _hashPassword(String password) {
    var hash = 2166136261;
    for (final unit in utf8.encode(password)) {
      hash ^= unit;
      hash = (hash * 16777619) & 0xffffffff;
    }
    return hash.toRadixString(16).padLeft(8, '0');
  }

  Future<void> clear() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_identityKey);
  }
}

class _InviteCode {
  static const String codes = String.fromEnvironment(
    'AIAGENT_INVITE_CODES',
    defaultValue: 'AIAGENT-V1',
  );

  static bool allowed(String value) {
    final input = value.trim();
    if (input.isEmpty) {
      return false;
    }

    return codes
        .split(',')
        .map((code) => code.trim())
        .where((code) => code.isNotEmpty)
        .contains(input);
  }
}
