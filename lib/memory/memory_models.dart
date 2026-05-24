class MemoryItem {
  const MemoryItem({
    required this.id,
    required this.text,
    required this.score,
    required this.createdAt,
    required this.updatedAt,
    required this.metadata,
  });

  final String id;
  final String text;
  final double score;
  final String createdAt;
  final String updatedAt;
  final Map<String, dynamic> metadata;

  factory MemoryItem.fromJson(Map<String, dynamic> json) {
    return MemoryItem(
      id: json['id']?.toString() ?? '',
      text: json['memory']?.toString() ?? json['text']?.toString() ?? '',
      score: _doubleValue(json['score']),
      createdAt: json['created_at']?.toString() ?? '',
      updatedAt: json['updated_at']?.toString() ?? '',
      metadata: json['metadata'] is Map
          ? (json['metadata'] as Map).map(
              (key, dynamic value) => MapEntry(key.toString(), value),
            )
          : <String, dynamic>{},
    );
  }

  static double _doubleValue(Object? value) {
    if (value is num) {
      return value.toDouble();
    }
    return double.tryParse(value?.toString() ?? '') ?? 0;
  }
}

class UserMemoryResponse {
  const UserMemoryResponse({
    required this.userId,
    required this.profileMemories,
    required this.longTermMemories,
  });

  final String userId;
  final List<MemoryItem> profileMemories;
  final List<MemoryItem> longTermMemories;

  factory UserMemoryResponse.fromJson(Map<String, dynamic> json) {
    return UserMemoryResponse(
      userId: json['user_id']?.toString() ?? '',
      profileMemories: _items(json['profile_memories']),
      longTermMemories: _items(json['long_term_memories']),
    );
  }

  static List<MemoryItem> _items(Object? value) {
    if (value is! List) {
      return [];
    }

    return value
        .whereType<Map>()
        .map(
          (item) => MemoryItem.fromJson(
            item.map((key, dynamic value) => MapEntry(key.toString(), value)),
          ),
        )
        .toList();
  }
}
