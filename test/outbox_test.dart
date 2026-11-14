import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:flutter_client/api/api_client.dart';
import 'package:flutter_client/chat/chat_message.dart';
import 'package:flutter_client/core/outbox.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  test('outbox entries round-trip through storage', () async {
    final store = OutboxStore();
    final entry = OutboxEntry(
      clientMessageId: 'msg-1',
      text: '离线消息',
      imagePath: '',
      createdAt: DateTime.parse('2026-01-01T10:00:00'),
      attempts: 2,
      nextAttemptAt: DateTime.parse('2026-01-01T10:00:30'),
    );

    await store.save([entry]);
    final loaded = await store.load();

    expect(loaded, hasLength(1));
    expect(loaded.first.clientMessageId, 'msg-1');
    expect(loaded.first.text, '离线消息');
    expect(loaded.first.attempts, 2);
    expect(loaded.first.nextAttemptAt, DateTime.parse('2026-01-01T10:00:30'));
  });

  test('backoff grows and caps at five minutes', () {
    expect(outboxBackoff(0), const Duration(seconds: 5));
    expect(outboxBackoff(1), const Duration(seconds: 15));
    expect(outboxBackoff(2), const Duration(seconds: 45));
    expect(outboxBackoff(3), const Duration(seconds: 120));
    expect(outboxBackoff(4), const Duration(seconds: 300));
    expect(outboxBackoff(50), const Duration(seconds: 300));
  });

  test('entry due check respects next attempt time', () {
    final due = OutboxEntry(
      clientMessageId: 'a',
      text: 't',
      imagePath: '',
      createdAt: DateTime.now(),
      nextAttemptAt: DateTime.now().subtract(const Duration(seconds: 1)),
    );
    final waiting = OutboxEntry(
      clientMessageId: 'b',
      text: 't',
      imagePath: '',
      createdAt: DateTime.now(),
      nextAttemptAt: DateTime.now().add(const Duration(minutes: 5)),
    );
    expect(due.isDue, isTrue);
    expect(waiting.isDue, isFalse);
  });

  test('base urls are deduped and ordered', () {
    final urls = ApiClient.buildBaseUrls(
      ['https://b.example.com/', 'https://a.example.com', 'https://b.example.com'],
      'https://a.example.com',
    );
    expect(urls, [
      'https://b.example.com',
      'https://a.example.com',
    ]);
  });

  test('network failures are classified for retry', () {
    final connection = DioException(
      requestOptions: RequestOptions(path: '/chat'),
      type: DioExceptionType.connectionError,
      error: 'SocketException',
    );
    final timeout = DioException(
      requestOptions: RequestOptions(path: '/chat'),
      type: DioExceptionType.receiveTimeout,
    );
    final unauthorized = DioException(
      requestOptions: RequestOptions(path: '/chat'),
      type: DioExceptionType.badResponse,
      response: Response<dynamic>(
        requestOptions: RequestOptions(path: '/chat'),
        statusCode: 401,
      ),
    );
    final degraded = DioException(
      requestOptions: RequestOptions(path: '/chat'),
      type: DioExceptionType.badResponse,
      response: Response<dynamic>(
        requestOptions: RequestOptions(path: '/chat'),
        statusCode: 503,
        data: {'ok': false, 'degraded': true, 'reply': '稍后再试'},
      ),
    );

    expect(ApiClient.isNetworkFailure(connection), isTrue);
    expect(ApiClient.isNetworkFailure(timeout), isTrue);
    expect(ApiClient.isNetworkFailure(unauthorized), isFalse);
    expect(ApiClient.isNetworkFailure(degraded), isFalse);
    expect(ApiClient.isAuthFailure(unauthorized), isTrue);
  });

  test('message status survives json round-trip and legacy defaults to sent', () {
    final message = ChatMessage.user(
      text: 'hi',
      clientMessageId: 'c-1',
      status: ChatMessageStatus.queued,
      attempts: 3,
    );
    final restored = ChatMessage.fromJson(message.toJson());
    expect(restored.clientMessageId, 'c-1');
    expect(restored.status, ChatMessageStatus.queued);
    expect(restored.attempts, 3);

    final legacy = ChatMessage.fromJson({'role': 'user', 'text': 'old'});
    expect(legacy.status, ChatMessageStatus.sent);
  });

  test('degraded assistant message is flagged', () {
    final message = ChatMessage.assistant(
      text: '稍后再试',
      status: ChatMessageStatus.degraded,
      retryAfterSeconds: 5,
    );
    expect(message.isDegraded, isTrue);
    expect(message.retryAfterSeconds, 5);
  });
}
