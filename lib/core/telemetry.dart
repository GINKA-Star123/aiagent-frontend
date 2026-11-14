import 'dart:convert';
import 'dart:math';

import 'package:shared_preferences/shared_preferences.dart';

typedef TelemetrySender =
    Future<void> Function(
      String batchId,
      Map<String, dynamic> app,
      List<Map<String, dynamic>> events,
    );

/// 本地遥测缓冲：只存结构化指标，不存对话正文。
class TelemetryBuffer {
  static const String _key = 'telemetry.buffer.v1';
  static const int maxEvents = 300;

  Future<List<Map<String, dynamic>>> load() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_key) ?? '';
    if (raw.isEmpty) {
      return [];
    }
    try {
      final decoded = jsonDecode(raw);
      if (decoded is! List) {
        return [];
      }
      return decoded
          .whereType<Map>()
          .map(
            (item) => item.map(
              (key, dynamic value) => MapEntry(key.toString(), value),
            ),
          )
          .toList();
    } on FormatException {
      return [];
    }
  }

  Future<void> save(List<Map<String, dynamic>> events) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_key, jsonEncode(events));
  }

  Future<void> add(Map<String, dynamic> event) async {
    final events = await load();
    events.add(event);
    if (events.length > maxEvents) {
      events.removeRange(0, events.length - maxEvents);
    }
    await save(events);
  }

  Future<void> clear() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_key);
  }
}

/// 批量上报：每批 50 条，成功才从本地删除；任何失败都不影响聊天。
class TelemetryService {
  TelemetryService({
    required TelemetrySender sender,
    required this.appVersion,
    required this.platform,
    TelemetryBuffer? buffer,
  }) : _sender = sender,
       _buffer = buffer ?? TelemetryBuffer();

  static const int batchSize = 50;

  final TelemetrySender _sender;
  final TelemetryBuffer _buffer;
  final String appVersion;
  final String platform;
  final Random _random = Random();

  Map<String, dynamic> get _app => {
    'version': appVersion,
    'platform': platform,
    'os': platform,
  };

  Future<void> recordTurn({
    required String clientMessageId,
    required int latencyMs,
    required int status,
    required bool degraded,
    required int textLen,
    required bool hasImage,
    required bool ttsPlayed,
    int attempts = 0,
    bool voice = false,
  }) async {
    try {
      await _buffer.add({
        'id': _newId(),
        'type': 'turn',
        'ts': DateTime.now().millisecondsSinceEpoch ~/ 1000,
        'client_message_id': clientMessageId,
        'latency_ms': latencyMs,
        'status': status,
        'degraded': degraded,
        'text_len': textLen,
        'has_image': hasImage,
        'attempts': attempts,
        'tts_played': ttsPlayed,
        'voice': voice,
      });
    } catch (_) {
      // 记录失败不影响聊天。
    }
  }

  Future<void> recordFeedback({
    required String messageId,
    required int rating,
    List<String> tags = const [],
  }) async {
    try {
      await _buffer.add({
        'id': _newId(),
        'type': 'feedback',
        'ts': DateTime.now().millisecondsSinceEpoch ~/ 1000,
        'client_message_id': messageId,
        'rating': rating,
        'tags': tags,
      });
    } catch (_) {
      // 记录失败不影响聊天。
    }
  }

  Future<void> flush() async {
    try {
      final events = await _buffer.load();
      if (events.isEmpty) {
        return;
      }
      final batch = events.take(batchSize).toList();
      await _sender(_newId(), _app, batch);
      final remaining = events.skip(batch.length).toList();
      await _buffer.save(remaining);
      if (remaining.isNotEmpty) {
        await flush();
      }
    } catch (_) {
      // 网络/鉴权失败：保留事件，下次再试。
    }
  }

  String _newId() {
    final ts = DateTime.now().microsecondsSinceEpoch.toRadixString(36);
    final rand = _random.nextInt(1 << 32).toRadixString(36);
    return [ts, '_', rand].join().padRight(8, '0');
  }
}
