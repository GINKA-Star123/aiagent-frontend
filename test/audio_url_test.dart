import 'package:flutter_test/flutter_test.dart';

import 'package:flutter_client/api/api_client.dart';
import 'package:flutter_client/api/api_config.dart';

void main() {
  test('audio url carries access token', () {
    final client = ApiClient(
      config: const ApiConfig(
        environment: 'test',
        apiBaseUrl: 'https://api.example.com',
        timeoutSeconds: 5,
      ),
      token: 'abc123',
    );

    expect(
      client.authorizedAudioUrl('https://api.example.com/audio/a.wav'),
      'https://api.example.com/audio/a.wav?access_token=abc123',
    );
    expect(
      client.authorizedAudioUrl('https://api.example.com/audio/a.wav?x=1'),
      'https://api.example.com/audio/a.wav?x=1&access_token=abc123',
    );
    expect(client.authorizedAudioUrl(''), '');
  });
}
