class CloudConfig {
  const CloudConfig._();

  static const String apiBaseUrl = String.fromEnvironment(
    'AIAGENT_API_BASE_URL',
    defaultValue: 'http://127.0.0.1:8000',
  );

  static const Duration connectTimeout = Duration(seconds: 10);
  static const Duration receiveTimeout = Duration(seconds: 90);

  static Uri apiUri(String path) {
    final normalizedPath = path.startsWith('/') ? path : '/$path';
    return Uri.parse('$apiBaseUrl$normalizedPath');
  }
}
