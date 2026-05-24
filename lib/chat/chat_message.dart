import '../live2d/live2d_payload.dart';
import 'memory_status.dart';

enum ChatRole { user, assistant, system }

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
    this.live2d,
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
  final Live2DPayload? live2d;
  final MemoryWriteStatus memoryStatus;

  factory ChatMessage.user({required String text, String imagePath = ''}) {
    return ChatMessage(
      role: ChatRole.user,
      text: text,
      imagePath: imagePath,
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
    Live2DPayload? live2d,
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
      live2d: live2d,
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
      live2d: json['live2d'] is Map
          ? Live2DPayload.fromJson(
              (json['live2d'] as Map).map(
                (key, dynamic value) => MapEntry(key.toString(), value),
              ),
              apiBaseUrl: '',
            )
          : null,
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
      'live2d': live2d?.toJson(),
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
}
