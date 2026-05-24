import 'package:flutter/material.dart';

enum MemoryWriteKind { remembered, skipped, unknown }

class MemoryWriteStatus {
  const MemoryWriteStatus({required this.kind, required this.label});

  final MemoryWriteKind kind;
  final String label;

  bool get visible => kind != MemoryWriteKind.unknown && label.isNotEmpty;

  factory MemoryWriteStatus.empty() {
    return const MemoryWriteStatus(kind: MemoryWriteKind.unknown, label: '');
  }

  factory MemoryWriteStatus.fromMetadata(Map<String, dynamic> metadata) {
    final shouldStore = metadata['memory_write_should_store'];
    final storeStatus = metadata['memory_store_status']?.toString() ?? '';
    final category = metadata['memory_write_category']?.toString() ?? '';

    if (shouldStore == true && storeStatus != 'skipped') {
      final suffix = category.isEmpty ? '' : '：$category';
      return MemoryWriteStatus(
        kind: MemoryWriteKind.remembered,
        label: '阿绫记住了这件事$suffix',
      );
    }

    if (shouldStore == false || storeStatus == 'skipped') {
      return const MemoryWriteStatus(
        kind: MemoryWriteKind.skipped,
        label: '这次只是临时聊天',
      );
    }

    return MemoryWriteStatus.empty();
  }

  factory MemoryWriteStatus.fromJson(Map<String, dynamic> json) {
    return MemoryWriteStatus(
      kind: _kindFromString(json['kind']?.toString() ?? ''),
      label: json['label']?.toString() ?? '',
    );
  }

  Map<String, dynamic> toJson() {
    return {'kind': kind.name, 'label': label};
  }

  static MemoryWriteKind _kindFromString(String value) {
    for (final kind in MemoryWriteKind.values) {
      if (kind.name == value) {
        return kind;
      }
    }

    return MemoryWriteKind.unknown;
  }
}

class MemoryStatusChip extends StatelessWidget {
  const MemoryStatusChip({super.key, required this.status});

  final MemoryWriteStatus status;

  @override
  Widget build(BuildContext context) {
    if (!status.visible) {
      return const SizedBox.shrink();
    }

    final remembered = status.kind == MemoryWriteKind.remembered;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: remembered ? const Color(0xFFEAF7EA) : const Color(0xFFF2F2F2),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(
          color: remembered
              ? const Color(0xFF8AC58A)
              : Colors.black.withValues(alpha: 0.10),
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            remembered
                ? Icons.bookmark_added_outlined
                : Icons.history_toggle_off,
            size: 14,
            color: remembered ? const Color(0xFF347A34) : Colors.black54,
          ),
          const SizedBox(width: 4),
          Flexible(
            child: Text(
              status.label,
              style: TextStyle(
                fontSize: 11,
                color: remembered ? const Color(0xFF347A34) : Colors.black54,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
