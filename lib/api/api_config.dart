import 'package:shared_preferences/shared_preferences.dart';

import 'cloud_config.dart';

class ApiConfig {
  const ApiConfig({
    required this.environment,
    required this.apiBaseUrl,
    required this.timeoutSeconds,
  });

  final String environment;
  final String apiBaseUrl;
  final int timeoutSeconds;

  static const String _environmentKey = 'api.environment';
  static const String _apiBaseUrlKey = 'api.baseUrl';
  static const String _timeoutSecondsKey = 'api.timeoutSeconds';

  factory ApiConfig.defaults() {
    const definedBaseUrl = CloudConfig.apiBaseUrl;
    return ApiConfig(
      environment: definedBaseUrl.startsWith('https://') ? 'cloud' : 'dev',
      apiBaseUrl: definedBaseUrl,
      timeoutSeconds: 120,
    );
  }

  ApiConfig copyWith({
    String? environment,
    String? apiBaseUrl,
    int? timeoutSeconds,
  }) {
    return ApiConfig(
      environment: environment ?? this.environment,
      apiBaseUrl: apiBaseUrl ?? this.apiBaseUrl,
      timeoutSeconds: timeoutSeconds ?? this.timeoutSeconds,
    );
  }

  static Future<ApiConfig> load() async {
    final prefs = await SharedPreferences.getInstance();
    final defaults = ApiConfig.defaults();

    return ApiConfig(
      environment: prefs.getString(_environmentKey) ?? defaults.environment,
      apiBaseUrl: prefs.getString(_apiBaseUrlKey) ?? defaults.apiBaseUrl,
      timeoutSeconds:
          prefs.getInt(_timeoutSecondsKey) ?? defaults.timeoutSeconds,
    );
  }

  Future<void> save() async {
    final prefs = await SharedPreferences.getInstance();

    await prefs.setString(_environmentKey, environment);
    await prefs.setString(_apiBaseUrlKey, apiBaseUrl);
    await prefs.setInt(_timeoutSecondsKey, timeoutSeconds);
  }

  Uri resolveUri(String path) {
    final normalizedBase = apiBaseUrl.endsWith('/')
        ? apiBaseUrl.substring(0, apiBaseUrl.length - 1)
        : apiBaseUrl;

    final normalizedPath = path.startsWith('/') ? path : '/$path';
    return Uri.parse('$normalizedBase$normalizedPath');
  }
}
