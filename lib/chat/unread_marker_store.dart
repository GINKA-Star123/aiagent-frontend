import 'package:shared_preferences/shared_preferences.dart';

class UnreadMarkerStore {
  static const String _prefix = 'chat.unread.marker.';

  static Future<String> load(String userId) async {
    if (userId.isEmpty) {
      return '';
    }
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_prefix + userId) ?? '';
  }

  static Future<void> save(String userId, String messageKey) async {
    if (userId.isEmpty || messageKey.isEmpty) {
      return;
    }
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_prefix + userId, messageKey);
  }

  static Future<void> clear(String userId) async {
    if (userId.isEmpty) {
      return;
    }
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_prefix + userId);
  }
}
