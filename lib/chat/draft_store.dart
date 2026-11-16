import 'package:shared_preferences/shared_preferences.dart';

/// 未发送草稿按 userId 保存，发送成功或清空输入后移除。
class DraftStore {
  static const String _prefix = 'chat.draft.';

  static Future<String> load(String userId) async {
    if (userId.isEmpty) {
      return '';
    }
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_prefix + userId) ?? '';
  }

  static Future<void> save(String userId, String text) async {
    if (userId.isEmpty) {
      return;
    }
    final prefs = await SharedPreferences.getInstance();
    if (text.trim().isEmpty) {
      await prefs.remove(_prefix + userId);
      return;
    }
    await prefs.setString(_prefix + userId, text);
  }

  static Future<void> clear(String userId) async {
    if (userId.isEmpty) {
      return;
    }
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_prefix + userId);
  }
}
