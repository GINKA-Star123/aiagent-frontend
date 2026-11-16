import 'package:shared_preferences/shared_preferences.dart';

class AppPreferences {
  AppPreferences._(this._prefs);

  static const String _autoPlayVoiceKey = 'app.auto_play_voice';
  static const String _onboardingCompletedKey = 'app.onboarding_completed';
  static const String _chatFontSizeKey = 'app.chat_font_size';
  static const double defaultChatFontSize = 15;

  final SharedPreferences _prefs;

  static Future<AppPreferences> load() async {
    final prefs = await SharedPreferences.getInstance();
    return AppPreferences._(prefs);
  }

  bool get autoPlayVoice {
    return _prefs.getBool(_autoPlayVoiceKey) ?? true;
  }

  Future<void> setAutoPlayVoice(bool value) async {
    await _prefs.setBool(_autoPlayVoiceKey, value);
  }

  double get chatFontSize {
    final value = _prefs.getDouble(_chatFontSizeKey) ?? defaultChatFontSize;
    return value.clamp(13, 20).toDouble();
  }

  Future<void> setChatFontSize(double value) async {
    await _prefs.setDouble(_chatFontSizeKey, value.clamp(13, 20).toDouble());
  }

  bool get onboardingCompleted {
    return _prefs.getBool(_onboardingCompletedKey) ?? false;
  }

  Future<void> setOnboardingCompleted(bool value) async {
    await _prefs.setBool(_onboardingCompletedKey, value);
  }
}
