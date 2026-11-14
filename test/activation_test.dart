import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_client/core/activation.dart';

String _encode(Map<String, dynamic> payload) {
  final raw = utf8.encode(jsonEncode(payload));
  return base64Url.encode(raw).replaceAll('=', '');
}

void main() {
  const token = 'abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQ';

  test(
    'decodes generated activation code from --dart-define',
    () {
      final raw = ActivationConfig.rawFromEnvironment();
      final config = ActivationConfig.decode(raw);
      expect(config.token.length, greaterThanOrEqualTo(43));
      expect(config.userId, startsWith('tester-'));
      expect(config.baseUrls.length, greaterThanOrEqualTo(1));
      expect(config.primaryBaseUrl, startsWith('http'));
    },
    skip: ActivationConfig.rawFromEnvironment().isEmpty
        ? '未通过 --dart-define 注入激活码'
        : false,
  );

  test('decodes primary and backup base urls', () {
    final code = _encode({
      'v': 1,
      'b': 'http://192.168.1.20:8000',
      'ba': ['http://192.168.1.20:8000', 'https://api.example.com'],
      't': token,
      'u': 'tester-001',
      'n': '测试用户01',
    });

    final config = ActivationConfig.decode(code);

    expect(config.primaryBaseUrl, 'http://192.168.1.20:8000');
    expect(config.baseUrls, [
      'http://192.168.1.20:8000',
      'https://api.example.com',
    ]);
    expect(config.token, token);
    expect(config.userId, 'tester-001');
    expect(config.username, '测试用户01');
  });

  test('falls back to user id when username is missing', () {
    final code = _encode({
      'b': 'https://api.example.com',
      't': token,
      'u': 'tester-002',
    });
    final config = ActivationConfig.decode(code);
    expect(config.username, 'tester-002');
  });

  test('rejects malformed payloads', () {
    expect(
      () => ActivationConfig.decode('not-a-code'),
      throwsA(isA<ActivationException>()),
    );
    expect(
      () => ActivationConfig.decode(_encode({'b': 'http://x', 't': 'short', 'u': 'u'})),
      throwsA(isA<ActivationException>()),
    );
    expect(
      () => ActivationConfig.decode(_encode({'b': '', 't': token, 'u': 'u'})),
      throwsA(isA<ActivationException>()),
    );
    expect(
      () => ActivationConfig.decode(_encode({'b': 'ftp://x', 't': token, 'u': 'u'})),
      throwsA(isA<ActivationException>()),
    );
    expect(
      () => ActivationConfig.decode(_encode({'b': 'http://x', 't': token, 'u': ''})),
      throwsA(isA<ActivationException>()),
    );
  });
}
