class MemoryItem {
  const MemoryItem({
    required this.id,
    required this.text,
    required this.layer,
    required this.category,
    required this.importance,
    required this.score,
    required this.pinned,
    required this.pinnedAt,
    required this.createdAt,
    required this.updatedAt,
    required this.metadata,
  });

  final String id;
  final String text;
  final String layer;
  final String category;
  final String importance;
  final double score;
  final bool pinned;
  final String pinnedAt;
  final String createdAt;
  final String updatedAt;
  final Map<String, dynamic> metadata;

  factory MemoryItem.fromJson(Map<String, dynamic> json) {
    final metadata = _mapValue(json['metadata']);

    return MemoryItem(
      id: json['id']?.toString() ?? '',
      text: json['memory']?.toString() ?? json['text']?.toString() ?? '',
      layer:
          json['layer']?.toString() ??
          metadata['memory_layer']?.toString() ??
          metadata['layer']?.toString() ??
          '',
      category:
          json['category']?.toString() ??
          metadata['category']?.toString() ??
          metadata['memory_category']?.toString() ??
          '',
      importance:
          json['importance']?.toString() ??
          metadata['importance']?.toString() ??
          metadata['memory_importance']?.toString() ??
          '',
      score: _doubleValue(json['score']),
      pinned:
          _boolValue(json['pinned']) ||
          _boolValue(json['memory_pinned']) ||
          _boolValue(metadata['pinned']) ||
          _boolValue(metadata['memory_pinned']),
      pinnedAt:
          json['pinned_at']?.toString() ??
          metadata['pinned_at']?.toString() ??
          metadata['memory_pinned_at']?.toString() ??
          '',
      createdAt: json['created_at']?.toString() ?? '',
      updatedAt: json['updated_at']?.toString() ?? '',
      metadata: metadata,
    );
  }

  static double _doubleValue(Object? value) {
    if (value is num) {
      return value.toDouble();
    }
    return double.tryParse(value?.toString() ?? '') ?? 0;
  }

  static bool _boolValue(Object? value) {
    if (value is bool) {
      return value;
    }
    final text = value?.toString().trim().toLowerCase() ?? '';
    return text == 'true' || text == '1' || text == 'yes' || text == 'on';
  }

  static Map<String, dynamic> _mapValue(Object? value) {
    if (value is Map<String, dynamic>) {
      return value;
    }
    if (value is Map) {
      return value.map((key, dynamic item) => MapEntry(key.toString(), item));
    }
    return <String, dynamic>{};
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

class MemoryPreferenceState {
  const MemoryPreferenceState({
    required this.userId,
    required this.longTermEnabled,
    required this.source,
    required this.updatedAt,
    required this.reason,
  });

  final String userId;
  final bool longTermEnabled;
  final String source;
  final String updatedAt;
  final String reason;

  factory MemoryPreferenceState.fromJson(Map<String, dynamic> json) {
    return MemoryPreferenceState(
      userId: json['user_id']?.toString() ?? '',
      longTermEnabled: json['long_term_enabled'] != false,
      source: json['source']?.toString() ?? '',
      updatedAt: json['updated_at']?.toString() ?? '',
      reason: json['reason']?.toString() ?? '',
    );
  }
}
