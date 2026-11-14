import 'memory_status.dart';

enum ChatRole { user, assistant, system }

/// 消息投递状态：sending -> sent / degraded；网络失败 -> queued；重试失败 -> failed。
enum ChatMessageStatus { sending, queued, sent, failed, degraded }

class ChatMessage {
  const ChatMessage({
    required this.role,
    required this.text,
    required this.createdAt,
    this.emotion = '',
    this.motion = '',
    this.expression = '',
    this.audioUrl = '',
    this.requestId = '',
    this.imagePath = '',
    this.clientMessageId = '',
    this.status = ChatMessageStatus.sent,
    this.attempts = 0,
    this.errorText = '',
    this.retryAfterSeconds = 0,
    this.memoryStatus = const MemoryWriteStatus(
      kind: MemoryWriteKind.unknown,
      label: '',
    ),
  });

  final ChatRole role;
  final String text;
  final DateTime createdAt;
  final String emotion;
  final String motion;
  final String expression;
  final String audioUrl;
  final String requestId;
  final String imagePath;

  /// 客户端幂等键：重试沿用同一个 id，界面据此去重与更新状态。
  final String clientMessageId;
  final ChatMessageStatus status;
  final int attempts;
  final String errorText;
  final int retryAfterSeconds;
  final MemoryWriteStatus memoryStatus;

  bool get isUser => role == ChatRole.user;
  bool get isPending =>
      status == ChatMessageStatus.sending || status == ChatMessageStatus.queued;
  bool get isDegraded => status == ChatMessageStatus.degraded;

  factory ChatMessage.user({
    required String text,
    String imagePath = '',
    String clientMessageId = '',
    ChatMessageStatus status = ChatMessageStatus.sending,
    int attempts = 0,
    String errorText = '',
  }) {
    return ChatMessage(
      role: ChatRole.user,
      text: text,
      imagePath: imagePath,
      clientMessageId: clientMessageId,
      status: status,
      attempts: attempts,
      errorText: errorText,
      createdAt: DateTime.now(),
    );
  }

  factory ChatMessage.assistant({
    required String text,
    String emotion = '',
    String motion = '',
    String expression = '',
    String audioUrl = '',
    String requestId = '',
    ChatMessageStatus status = ChatMessageStatus.sent,
    int retryAfterSeconds = 0,
    MemoryWriteStatus memoryStatus = const MemoryWriteStatus(
      kind: MemoryWriteKind.unknown,
      label: '',
    ),
  }) {
    return ChatMessage(
      role: ChatRole.assistant,
      text: text,
      createdAt: DateTime.now(),
      emotion: emotion,
      motion: motion,
      expression: expression,
      audioUrl: audioUrl,
      requestId: requestId,
      status: status,
      retryAfterSeconds: retryAfterSeconds,
      memoryStatus: memoryStatus,
    );
  }

  factory ChatMessage.system({required String text}) {
    return ChatMessage(
      role: ChatRole.system,
      text: text,
      createdAt: DateTime.now(),
    );
  }

  ChatMessage copyWith({
    String? text,
    String? audioUrl,
    String? requestId,
    String? imagePath,
    ChatMessageStatus? status,
    int? attempts,
    String? errorText,
    int? retryAfterSeconds,
    MemoryWriteStatus? memoryStatus,
  }) {
    return ChatMessage(
      role: role,
      text: text ?? this.text,
      createdAt: createdAt,
      emotion: emotion,
      motion: motion,
      expression: expression,
      audioUrl: audioUrl ?? this.audioUrl,
      requestId: requestId ?? this.requestId,
      imagePath: imagePath ?? this.imagePath,
      clientMessageId: clientMessageId,
      status: status ?? this.status,
      attempts: attempts ?? this.attempts,
      errorText: errorText ?? this.errorText,
      retryAfterSeconds: retryAfterSeconds ?? this.retryAfterSeconds,
      memoryStatus: memoryStatus ?? this.memoryStatus,
    );
  }

  factory ChatMessage.fromJson(Map<String, dynamic> json) {
    return ChatMessage(
      role: _roleFromString(json['role']?.toString() ?? ''),
      text: json['text']?.toString() ?? '',
      createdAt:
          DateTime.tryParse(json['createdAt']?.toString() ?? '') ??
          DateTime.now(),
      emotion: json['emotion']?.toString() ?? '',
      motion: json['motion']?.toString() ?? '',
      expression: json['expression']?.toString() ?? '',
      audioUrl: json['audioUrl']?.toString() ?? '',
      requestId: json['requestId']?.toString() ?? '',
      imagePath: json['imagePath']?.toString() ?? '',
      clientMessageId: json['clientMessageId']?.toString() ?? '',
      status: _statusFromString(json['status']?.toString() ?? ''),
      attempts: int.tryParse(json['attempts']?.toString() ?? '') ?? 0,
      errorText: json['errorText']?.toString() ?? '',
      retryAfterSeconds:
          int.tryParse(json['retryAfterSeconds']?.toString() ?? '') ?? 0,
      memoryStatus: json['memoryStatus'] is Map
          ? MemoryWriteStatus.fromJson(
              (json['memoryStatus'] as Map).map(
                (key, dynamic value) => MapEntry(key.toString(), value),
              ),
            )
          : MemoryWriteStatus.empty(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'role': role.name,
      'text': text,
      'createdAt': createdAt.toIso8601String(),
      'emotion': emotion,
      'motion': motion,
      'expression': expression,
      'audioUrl': audioUrl,
      'requestId': requestId,
      'imagePath': imagePath,
      'clientMessageId': clientMessageId,
      'status': status.name,
      'attempts': attempts,
      'errorText': errorText,
      'retryAfterSeconds': retryAfterSeconds,
      'memoryStatus': memoryStatus.toJson(),
    };
  }

  static ChatRole _roleFromString(String value) {
    for (final role in ChatRole.values) {
      if (role.name == value) {
        return role;
      }
    }

    return ChatRole.system;
  }

  static ChatMessageStatus _statusFromString(String value) {
    for (final status in ChatMessageStatus.values) {
      if (status.name == value) {
        return status;
      }
    }

    // 旧版本历史没有状态字段：一律视为已送达，避免被当成待重发消息。
    return ChatMessageStatus.sent;
  }
}
