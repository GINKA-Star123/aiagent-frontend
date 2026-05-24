import '../live2d/live2d_payload.dart';

class HealthResponse {
  const HealthResponse({
    required this.status,
    required this.ok,
    required this.requestId,
  });

  final String status;
  final bool ok;
  final String requestId;

  factory HealthResponse.fromJson(Map<String, dynamic> json) {
    return HealthResponse(
      status: json['status']?.toString() ?? 'unknown',
      ok: json['ok'] == true || json['status'] == 'ok',
      requestId: json['request_id']?.toString() ?? '',
    );
  }
}

class ChatResponse {
  const ChatResponse({
    required this.ok,
    required this.outputId,
    required this.reply,
    required this.baseReplyText,
    required this.emotion,
    required this.motion,
    required this.expression,
    required this.audioPath,
    required this.audioUrl,
    required this.live2d,
    required this.metadata,
    required this.requestId,
  });

  final bool ok;
  final String outputId;
  final String reply;
  final String baseReplyText;
  final String emotion;
  final String motion;
  final String expression;
  final String audioPath;
  final String audioUrl;
  final Live2DPayload? live2d;
  final Map<String, dynamic> metadata;
  final String requestId;

  factory ChatResponse.fromJson(
    Map<String, dynamic> json, {
    required String apiBaseUrl,
  }) {
    final live2dRaw = json['live2d'];
    final metadataRaw = json['metadata'];

    return ChatResponse(
      ok: json['ok'] == true,
      outputId: json['output_id']?.toString() ?? '',
      reply: json['reply']?.toString() ?? '',
      baseReplyText: json['base_reply_text']?.toString() ?? '',
      emotion: json['emotion']?.toString() ?? '',
      motion: json['motion']?.toString() ?? '',
      expression: json['expression']?.toString() ?? '',
      audioPath: json['audio_path']?.toString() ?? '',
      audioUrl: _resolveUrl(json['audio_url']?.toString() ?? '', apiBaseUrl),
      live2d: live2dRaw is Map
          ? Live2DPayload.fromJson(
              live2dRaw.map(
                (key, dynamic value) => MapEntry(key.toString(), value),
              ),
              apiBaseUrl: apiBaseUrl,
            )
          : null,
      metadata: metadataRaw is Map
          ? metadataRaw.map(
              (key, dynamic value) => MapEntry(key.toString(), value),
            )
          : <String, dynamic>{},
      requestId: json['request_id']?.toString() ?? '',
    );
  }

  static String _resolveUrl(String value, String apiBaseUrl) {
    if (value.isEmpty) {
      return '';
    }

    if (value.startsWith('http://') || value.startsWith('https://')) {
      return value;
    }

    final base = apiBaseUrl.endsWith('/')
        ? apiBaseUrl.substring(0, apiBaseUrl.length - 1)
        : apiBaseUrl;

    final path = value.startsWith('/') ? value : '/$value';
    return '$base$path';
  }
}

class TranscribeResponse {
  const TranscribeResponse({
    required this.ok,
    required this.transcript,
    required this.language,
    required this.durationSeconds,
    required this.requestId,
    required this.raw,
  });

  final bool ok;
  final String transcript;
  final String language;
  final double durationSeconds;
  final String requestId;
  final Map<String, dynamic> raw;

  factory TranscribeResponse.fromJson(Map<String, dynamic> json) {
    return TranscribeResponse(
      ok: json['ok'] == true,
      transcript: _firstString(json, ['transcript', 'text', 'result']),
      language: json['language']?.toString() ?? '',
      durationSeconds: _doubleValue(
        json['duration_seconds'] ?? json['duration'],
      ),
      requestId: json['request_id']?.toString() ?? '',
      raw: json,
    );
  }

  static String _firstString(Map<String, dynamic> json, List<String> keys) {
    for (final key in keys) {
      final value = json[key];
      if (value != null && value.toString().trim().isNotEmpty) {
        return value.toString().trim();
      }
    }

    final nestedResult = json['result'];
    if (nestedResult is Map) {
      for (final key in keys) {
        final value = nestedResult[key];
        if (value != null && value.toString().trim().isNotEmpty) {
          return value.toString().trim();
        }
      }
    }

    return '';
  }

  static double _doubleValue(Object? value) {
    if (value is double) {
      return value;
    }

    if (value is int) {
      return value.toDouble();
    }

    if (value is num) {
      return value.toDouble();
    }

    return double.tryParse(value?.toString() ?? '') ?? 0;
  }
}

class VoiceCallTurnResponse {
  const VoiceCallTurnResponse({
    required this.ok,
    required this.transcript,
    required this.chat,
    required this.requestId,
    required this.raw,
  });

  final bool ok;
  final String transcript;
  final ChatResponse chat;
  final String requestId;
  final Map<String, dynamic> raw;

  factory VoiceCallTurnResponse.fromJson(
    Map<String, dynamic> json, {
    required String apiBaseUrl,
  }) {
    return VoiceCallTurnResponse(
      ok: json['ok'] == true,
      transcript: json['transcript']?.toString() ?? '',
      chat: ChatResponse.fromJson(json, apiBaseUrl: apiBaseUrl),
      requestId: json['request_id']?.toString() ?? '',
      raw: json,
    );
  }
}
