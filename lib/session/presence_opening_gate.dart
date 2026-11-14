import 'package:shared_preferences/shared_preferences.dart';

class PresenceOpeningGate {
  const PresenceOpeningGate();

  static const Duration cooldown = Duration(minutes: 10);
  static const String _keyPrefix = 'presence.opening.lastShownAt.';

  Future<bool> shouldShow({required String userId}) async {
    final prefs = await SharedPreferences.getInstance();
    final lastShownAtText = prefs.getString(_key(userId));
    if (lastShownAtText == null || lastShownAtText.isEmpty) {
      return true;
    }

    final lastShownAt = DateTime.tryParse(lastShownAtText);
    if (lastShownAt == null) {
      return true;
    }

    return DateTime.now().difference(lastShownAt) >= cooldown;
  }

  Future<void> markShown({required String userId}) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_key(userId), DateTime.now().toIso8601String());
  }

  String _key(String userId) {
    final safeUserId = userId.trim().isEmpty ? 'guest' : userId.trim();
    return '$_keyPrefix$safeUserId';
  }
}
