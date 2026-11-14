import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import 'package:flutter_client/api/api_client.dart';
import 'package:flutter_client/api/api_config.dart';

Future<HttpServer> _serve(
  Future<void> Function(HttpRequest request) handler,
) async {
  final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
  server.listen(handler);
  return server;
}

String _url(int port) {
  return Uri(scheme: 'http', host: '127.0.0.1', port: port).toString();
}

ApiConfig _config(int port) {
  return ApiConfig(
    environment: 'test',
    apiBaseUrl: _url(port),
    timeoutSeconds: 5,
  );
}

void main() {
  test('degraded 503 is returned as a reply instead of an error', () async {
    final server = await _serve((request) async {
      request.response.statusCode = 503;
      request.response.headers.contentType = ContentType.json;
      request.response.write(
        jsonEncode({
          'ok': false,
          'degraded': true,
          'reply': '稍后再试',
          'retry_after_seconds': 5,
        }),
      );
      await request.response.close();
    });

    final client = ApiClient(config: _config(server.port));
    final response = await client.sendChat(
      userId: 'u',
      username: 'u',
      text: 'hi',
    );

    expect(response.degraded, isTrue);
    expect(response.reply, '稍后再试');
    expect(response.retryAfterSeconds, 5);

    client.close();
    await server.close(force: true);
  });

  test(
    'falls over to the backup base url when primary is unreachable',
    () async {
      final backup = await _serve((request) async {
        request.response.headers.contentType = ContentType.json;
        request.response.write(
          jsonEncode({
            'ok': true,
            'reply': 'from-backup',
            'emotion': 'neutral',
            'expression': 'neutral',
          }),
        );
        await request.response.close();
      });

      final probe = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
      final deadPort = probe.port;
      await probe.close(force: true);

      final client = ApiClient(
        config: _config(deadPort),
        baseUrls: [
          _url(deadPort),
          _url(backup.port),
        ],
      );

      final response = await client.sendChat(
        userId: 'u',
        username: 'u',
        text: 'hi',
      );

      expect(response.reply, 'from-backup');
      expect(
        client.activeBaseUrl,
        _url(backup.port),
      );

      client.close();
      await backup.close(force: true);
    },
  );
}
