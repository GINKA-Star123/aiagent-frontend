import 'package:shared_preferences/shared_preferences.dart';

/// 保存原始激活码；令牌随 UserIdentity.accessToken 一起持久化。
class SessionStore {
  static const String _activationKey = 'session.activation.v1';

  Future<String?> loadActivationCode() async {
    final prefs = await SharedPreferences.getInstance();
    final value = prefs.getString(_activationKey) ?? '';
    return value.isEmpty ? null : value;
  }

  Future<void> saveActivationCode(String code) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_activationKey, code.trim());
  }

  Future<void> clear() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_activationKey);
  }
}
