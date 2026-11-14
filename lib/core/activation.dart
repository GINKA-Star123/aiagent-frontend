import 'dart:convert';

class ActivationException implements Exception {
  const ActivationException(this.message);

  final String message;

  @override
  String toString() => message;
}

/// 激活码 = base64url(JSON{v, b, ba, t, u, n})。
///
/// 一次粘贴同时完成三件事：服务地址（含备用入口）、访问令牌、用户身份。
/// 服务端按 token -> user_id 映射鉴权，客户端不保存任何 LLM/模型配置。
class ActivationConfig {
  const ActivationConfig({
    required this.baseUrls,
    required this.token,
    required this.userId,
    required this.username,
  });

  static const String envKey = 'ACTIVATION_CODE';
  static final RegExp _tokenRegExp = RegExp(r'^[A-Za-z0-9_-]{43,256}$');

  final List<String> baseUrls;
  final String token;
  final String userId;
  final String username;

  String get primaryBaseUrl => baseUrls.first;

  static String rawFromEnvironment() =>
      const String.fromEnvironment(envKey, defaultValue: '').trim();

  factory ActivationConfig.decode(String code) {
    final trimmed = code.trim();
    if (trimmed.isEmpty) {
      throw const ActivationException('激活码为空');
    }

    Object? decoded;
    try {
      final normalized = base64Url.normalize(trimmed);
      decoded = jsonDecode(utf8.decode(base64Url.decode(normalized)));
    } on FormatException {
      throw const ActivationException('激活码格式不对，请核对后重试');
    }

    if (decoded is! Map) {
      throw const ActivationException('激活码内容不完整');
    }
    final map = decoded.map((key, value) => MapEntry(key.toString(), value));

    final token = map['t']?.toString() ?? '';
    final userId = map['u']?.toString().trim() ?? '';
    final username = map['n']?.toString().trim() ?? '';

    final urls = <String>[];
    final primary = map['b']?.toString().trim() ?? '';
    if (primary.isNotEmpty) {
      urls.add(primary);
    }
    final backups = map['ba'];
    if (backups is List) {
      for (final item in backups) {
        final url = item?.toString().trim() ?? '';
        if (url.isNotEmpty && !urls.contains(url)) {
          urls.add(url);
        }
      }
    }

    if (token.isEmpty || !_tokenRegExp.hasMatch(token)) {
      throw const ActivationException('激活码里的访问令牌无效');
    }
    if (userId.isEmpty) {
      throw const ActivationException('激活码缺少用户身份');
    }
    if (urls.isEmpty) {
      throw const ActivationException('激活码缺少服务地址');
    }
    for (final url in urls) {
      if (!url.startsWith('http://') && !url.startsWith('https://')) {
        throw const ActivationException('服务地址必须是 http(s) 链接');
      }
    }

    return ActivationConfig(
      baseUrls: urls,
      token: token,
      userId: userId,
      username: username.isEmpty ? userId : username,
    );
  }
}
