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

class AuthResponse {
  const AuthResponse({
    required this.userId,
    required this.username,
    required this.token,
    required this.expiresAt,
    required this.isGuest,
  });

  final String userId;
  final String username;
  final String token;
  final int expiresAt;
  final bool isGuest;

  factory AuthResponse.fromJson(Map<String, dynamic> json) {
    return AuthResponse(
      userId: json['user_id']?.toString() ?? '',
      username: json['username']?.toString() ?? '',
      token: json['token']?.toString() ?? '',
      expiresAt: int.tryParse(json['expires_at']?.toString() ?? '') ?? 0,
      isGuest: json['is_guest'] == true,
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
    required this.metadata,
    required this.requestId,
    this.degraded = false,
    this.retryAfterSeconds = 0,
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
  final Map<String, dynamic> metadata;
  final String requestId;

  /// 后端降级回复：ok=false 但带一句可用的话术，客户端照常展示。
  final bool degraded;
  final int retryAfterSeconds;

  factory ChatResponse.fromJson(
    Map<String, dynamic> json, {
    required String apiBaseUrl,
  }) {
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
      metadata: metadataRaw is Map
          ? metadataRaw.map(
              (key, dynamic value) => MapEntry(key.toString(), value),
            )
          : <String, dynamic>{},
      requestId: json['request_id']?.toString() ?? '',
      degraded: json['degraded'] == true,
      retryAfterSeconds:
          int.tryParse(json['retry_after_seconds']?.toString() ?? '') ?? 0,
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

class SessionOpeningResponse {
  const SessionOpeningResponse({
    required this.ok,
    required this.kind,
    required this.text,
    required this.shouldSpeak,
    required this.presenceState,
    required this.mood,
    required this.suggestedDelayMs,
    required this.raw,
  });

  final bool ok;
  final String kind;
  final String text;
  final bool shouldSpeak;
  final String presenceState;
  final String mood;
  final int suggestedDelayMs;
  final Map<String, dynamic> raw;

  factory SessionOpeningResponse.fromJson(
    Map<String, dynamic> json, {
    required String apiBaseUrl,
  }) {
    final opening = _mapValue(json['opening']);
    final presence = _mapValue(json['presence']);

    return SessionOpeningResponse(
      ok: json['ok'] != false,
      kind: opening['kind']?.toString() ?? 'first_meet',
      text: opening['text']?.toString() ?? '',
      shouldSpeak: opening['should_speak'] != false,
      presenceState: presence['state']?.toString() ?? 'listening',
      mood: presence['mood']?.toString() ?? 'neutral',
      suggestedDelayMs: 600,
      raw: json,
    );
  }

  String get statusText {
    if (presenceState == 'sleepy') {
      return '低能量陪伴中';
    }
    if (presenceState == 'working' || presenceState == 'focused') {
      return '刚从专注状态切回来';
    }
    if (presenceState == 'reading') {
      return '刚刚在整理资料';
    }
    return '已进入交流状态';
  }
}

Map<String, dynamic> _mapValue(Object? value) {
  if (value is Map<String, dynamic>) {
    return value;
  }

  if (value is Map) {
    return value.map((key, dynamic item) => MapEntry(key.toString(), item));
  }

  return <String, dynamic>{};
}
