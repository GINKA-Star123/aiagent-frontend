import 'package:flutter/material.dart';

import '../api/api_client.dart';
import 'memory_models.dart';

enum _MemoryCardAction { edit, pin, unpin }

class MemoryPage extends StatefulWidget {
  const MemoryPage({super.key, required this.apiClient, required this.userId});

  final ApiClient apiClient;
  final String userId;

  @override
  State<MemoryPage> createState() => _MemoryPageState();
}

class _MemoryPageState extends State<MemoryPage> {
  bool _busy = false;
  bool _loading = true;
  String _errorText = '';
  UserMemoryResponse? _memory;
  MemoryPreferenceState? _preference;
  final Set<String> _selectedMemoryIds = <String>{};

  @override
  void initState() {
    super.initState();
    _loadMemory();
  }

  Future<void> _loadMemory() async {
    setState(() {
      _loading = true;
      _errorText = '';
    });

    try {
      final memoryFuture = widget.apiClient.getUserMemory(widget.userId);
      final preferenceFuture = widget.apiClient.getMemoryPreferences(widget.userId);

      final memory = await memoryFuture;
      MemoryPreferenceState preference;
      try {
        preference = await preferenceFuture;
      } catch (_) {
        preference = MemoryPreferenceState(
          userId: widget.userId,
          longTermEnabled: true,
          source: 'fallback',
          updatedAt: '',
          reason: 'preference_endpoint_unavailable',
        );
      }

      if (!mounted) {
        return;
      }

      setState(() {
        _memory = memory;
        _preference = preference;
        _selectedMemoryIds.retainWhere((id) => _allMemories().any((item) => item.id == id));
        _loading = false;
      });
    } catch (error) {
      if (!mounted) {
        return;
      }

      setState(() {
        _errorText = error.toString();
        _loading = false;
      });
    }
  }

  Future<void> _setMemoryEnabled(bool enabled) async {
    await _runBusyAction(() async {
      await widget.apiClient.setMemoryEnabled(
        userId: widget.userId,
        enabled: enabled,
      );
    });
  }

  Future<void> _confirmClearMemory() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('清空长期记忆'),
          content: const Text('这会清空当前用户的长期记忆。聊天记录不会被删除。'),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('取消'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(context).pop(true),
              child: const Text('清空'),
            ),
          ],
        );
      },
    );

    if (confirmed != true) {
      return;
    }

    await _runBusyAction(() async {
      await widget.apiClient.clearUserMemory(widget.userId);
      _selectedMemoryIds.clear();
    });
  }

  Future<void> _editMemory(MemoryItem item) async {
    if (item.id.isEmpty) {
      return;
    }

    final memoryController = TextEditingController(text: item.text);
    String selectedCategory = item.category.isNotEmpty ? item.category : 'other';
    String selectedImportance = item.importance.isNotEmpty ? item.importance : 'medium';
    bool pinned = item.pinned;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              title: const Text('编辑记忆'),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextField(
                      controller: memoryController,
                      maxLines: 4,
                      minLines: 3,
                      decoration: const InputDecoration(
                        labelText: '记忆内容',
                        alignLabelWithHint: true,
                      ),
                    ),
                    const SizedBox(height: 12),
                    DropdownButtonFormField<String>(
                      initialValue: _normalizeOption(selectedCategory, _memoryCategoryOptions),
                      items: _memoryCategoryOptions
                          .map(
                            (value) => DropdownMenuItem<String>(
                              value: value,
                              child: Text(value),
                            ),
                          )
                          .toList(),
                      onChanged: (value) {
                        if (value == null) {
                          return;
                        }
                        setDialogState(() {
                          selectedCategory = value;
                        });
                      },
                      decoration: const InputDecoration(
                        labelText: '分类',
                      ),
                    ),
                    const SizedBox(height: 12),
                    DropdownButtonFormField<String>(
                      initialValue: _normalizeOption(selectedImportance, _memoryImportanceOptions),
                      items: _memoryImportanceOptions
                          .map(
                            (value) => DropdownMenuItem<String>(
                              value: value,
                              child: Text(value),
                            ),
                          )
                          .toList(),
                      onChanged: (value) {
                        if (value == null) {
                          return;
                        }
                        setDialogState(() {
                          selectedImportance = value;
                        });
                      },
                      decoration: const InputDecoration(
                        labelText: '重要度',
                      ),
                    ),
                    const SizedBox(height: 12),
                    SwitchListTile.adaptive(
                      contentPadding: EdgeInsets.zero,
                      title: const Text('置顶'),
                      value: pinned,
                      onChanged: (value) {
                        setDialogState(() {
                          pinned = value;
                        });
                      },
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(context).pop(false),
                  child: const Text('取消'),
                ),
                FilledButton(
                  onPressed: () => Navigator.of(context).pop(true),
                  child: const Text('保存'),
                ),
              ],
            );
          },
        );
      },
    );

    if (confirmed != true) {
      memoryController.dispose();
      return;
    }

    final nextText = memoryController.text.trim();
    memoryController.dispose();

    if (nextText.isEmpty) {
      _showSnackBar('记忆内容不能为空。');
      return;
    }

    await _runBusyAction(() async {
      await widget.apiClient.editMemory(
        userId: widget.userId,
        memoryId: item.id,
        memory: nextText,
        category: selectedCategory,
        importance: selectedImportance,
        pinned: pinned,
      );
    });
  }

  Future<void> _togglePinned(MemoryItem item, bool pinned) async {
    if (item.id.isEmpty) {
      return;
    }

    await _runBusyAction(() async {
      await widget.apiClient.setMemoryPinned(
        userId: widget.userId,
        memoryId: item.id,
        pinned: pinned,
      );
    });
  }

  Future<void> _mergeSelectedMemories() async {
    final selectedItems = _selectedItems();
    if (selectedItems.length < 2) {
      _showSnackBar('至少选择两条记忆再合并。');
      return;
    }

    final mergedController = TextEditingController(
      text: selectedItems.map((item) => item.text).join('；'),
    );

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('合并冲突记忆'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('将以下记忆合并为一条最终版本：'),
                const SizedBox(height: 8),
                ...selectedItems.map(
                  (item) => Padding(
                    padding: const EdgeInsets.only(bottom: 6),
                    child: Text(
                      '• ${item.text}',
                      style: const TextStyle(fontSize: 13),
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: mergedController,
                  maxLines: 4,
                  minLines: 3,
                  decoration: const InputDecoration(
                    labelText: '最终合并文本',
                    alignLabelWithHint: true,
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('取消'),
            ),
            FilledButton.icon(
              onPressed: () => Navigator.of(context).pop(true),
              icon: const Icon(Icons.call_merge),
              label: const Text('合并'),
            ),
          ],
        );
      },
    );

    if (confirmed != true) {
      mergedController.dispose();
      return;
    }

    final mergedMemory = mergedController.text.trim();
    mergedController.dispose();

    if (mergedMemory.isEmpty) {
      _showSnackBar('合并后的记忆不能为空。');
      return;
    }

    await _runBusyAction(() async {
      await widget.apiClient.mergeMemories(
        userId: widget.userId,
        memoryIds: selectedItems.map((item) => item.id).toList(),
        mergedMemory: mergedMemory,
      );
      _selectedMemoryIds.clear();
    });
  }

  Future<void> _runBusyAction(Future<void> Function() action) async {
    if (_busy) {
      return;
    }

    setState(() {
      _busy = true;
    });

    try {
      await action();
      if (!mounted) {
        return;
      }
      await _loadMemory();
    } catch (error) {
      if (!mounted) {
        return;
      }
      _showSnackBar(error.toString());
    } finally {
      if (mounted) {
        setState(() {
          _busy = false;
        });
      }
    }
  }

  List<MemoryItem> _allMemories() {
    final memory = _memory;
    if (memory == null) {
      return <MemoryItem>[];
    }

    final items = <MemoryItem>[
      ...memory.profileMemories,
      ...memory.longTermMemories,
    ];

    items.sort(_compareMemoryItem);
    return items;
  }

  List<MemoryItem> _selectedItems() {
    return _allMemories().where((item) => _selectedMemoryIds.contains(item.id)).toList();
  }

  int _compareMemoryItem(MemoryItem left, MemoryItem right) {
    if (left.pinned != right.pinned) {
      return left.pinned ? -1 : 1;
    }

    final scoreCompare = right.score.compareTo(left.score);
    if (scoreCompare != 0) {
      return scoreCompare;
    }

    return _parseDate(right.updatedAt).compareTo(_parseDate(left.updatedAt));
  }

  DateTime _parseDate(String value) {
    return DateTime.tryParse(value) ?? DateTime.fromMillisecondsSinceEpoch(0);
  }

  void _toggleSelection(MemoryItem item, bool selected) {
    if (item.id.isEmpty) {
      return;
    }

    setState(() {
      if (selected) {
        _selectedMemoryIds.add(item.id);
      } else {
        _selectedMemoryIds.remove(item.id);
      }
    });
  }

  void _clearSelection() {
    setState(() {
      _selectedMemoryIds.clear();
    });
  }

  void _showSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  @override
  Widget build(BuildContext context) {
    final items = _allMemories();
    final preference = _preference;

    return Scaffold(
      appBar: AppBar(
        title: const Text('记忆'),
        actions: [
          IconButton(
            tooltip: '刷新',
            onPressed: _busy ? null : _loadMemory,
            icon: const Icon(Icons.refresh),
          ),
          IconButton(
            tooltip: '清空长期记忆',
            onPressed: _busy || items.isEmpty ? null : _confirmClearMemory,
            icon: const Icon(Icons.delete_outline),
          ),
        ],
      ),
      body: Builder(
        builder: (context) {
          if (_loading) {
            return const Center(child: CircularProgressIndicator());
          }

          if (_errorText.isNotEmpty) {
            return _MemoryEmptyState(
              icon: Icons.cloud_off_outlined,
              title: '记忆读取失败',
              subtitle: _errorText,
              onRetry: _loadMemory,
            );
          }

          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              _MemoryPreferencePanel(
                preference: preference,
                busy: _busy,
                onChanged: _setMemoryEnabled,
              ),
              const SizedBox(height: 12),
              if (_selectedMemoryIds.length >= 2) ...[
                _MemoryMergeBar(
                  selectedCount: _selectedMemoryIds.length,
                  busy: _busy,
                  onClear: _clearSelection,
                  onMerge: _mergeSelectedMemories,
                ),
                const SizedBox(height: 12),
              ],
              if (items.isEmpty)
                _MemoryEmptyState(
                  icon: Icons.bookmark_border,
                  title: '还没有长期记忆',
                  subtitle: '当对话里出现值得保留的信息时，阿绫会把它记下来。',
                  onRetry: _loadMemory,
                )
              else
                ...items.expand(
                  (item) => [
                    _MemoryCard(
                      item: item,
                      selected: _selectedMemoryIds.contains(item.id),
                      onSelectedChanged: item.id.isEmpty
                          ? null
                          : (selected) => _toggleSelection(item, selected),
                      onEdit: () => _editMemory(item),
                      onTogglePin: () => _togglePinned(item, !item.pinned),
                    ),
                    const SizedBox(height: 10),
                  ],
                ),
            ],
          );
        },
      ),
    );
  }
}

class _MemoryCard extends StatelessWidget {
  const _MemoryCard({
    required this.item,
    required this.selected,
    required this.onSelectedChanged,
    required this.onEdit,
    required this.onTogglePin,
  });

  final MemoryItem item;
  final bool selected;
  final ValueChanged<bool>? onSelectedChanged;
  final VoidCallback onEdit;
  final VoidCallback onTogglePin;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: const Color(0xFFFFFFFF),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.black.withValues(alpha: 0.08)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (onSelectedChanged != null)
              Padding(
                padding: const EdgeInsets.only(top: 2),
                child: Checkbox(
                  value: selected,
                  onChanged: (value) => onSelectedChanged?.call(value ?? false),
                ),
              )
            else
              const SizedBox(width: 40),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: Text(
                          item.text.isEmpty ? '空记忆' : item.text,
                          style: const TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w700,
                            height: 1.25,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      PopupMenuButton<_MemoryCardAction>(
                        tooltip: '记忆操作',
                        icon: const Icon(Icons.more_vert),
                        onSelected: (action) {
                          switch (action) {
                            case _MemoryCardAction.edit:
                              onEdit();
                              break;
                            case _MemoryCardAction.pin:
                            case _MemoryCardAction.unpin:
                              onTogglePin();
                              break;
                          }
                        },
                        itemBuilder: (context) => [
                          PopupMenuItem<_MemoryCardAction>(
                            value: _MemoryCardAction.edit,
                            child: Row(
                              children: [
                                const Icon(Icons.edit_outlined, size: 18),
                                const SizedBox(width: 8),
                                Text(item.text.isEmpty ? '编辑' : '编辑记忆'),
                              ],
                            ),
                          ),
                          PopupMenuItem<_MemoryCardAction>(
                            value: item.pinned
                                ? _MemoryCardAction.unpin
                                : _MemoryCardAction.pin,
                            child: Row(
                              children: [
                                Icon(
                                  item.pinned
                                      ? Icons.push_pin_outlined
                                      : Icons.push_pin,
                                  size: 18,
                                ),
                                const SizedBox(width: 8),
                                Text(item.pinned ? '取消置顶' : '置顶'),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 12,
                    runSpacing: 8,
                    children: [
                      _InlineMeta(
                        icon: Icons.layers_outlined,
                        label: item.layer.isEmpty ? 'other' : item.layer,
                      ),
                      _InlineMeta(
                        icon: Icons.label_outline,
                        label: item.category.isEmpty ? 'other' : item.category,
                      ),
                      _InlineMeta(
                        icon: Icons.priority_high,
                        label: item.importance.isEmpty ? 'medium' : item.importance,
                      ),
                      if (item.pinned)
                        const _InlineMeta(
                          icon: Icons.push_pin,
                          label: '置顶',
                        ),
                      if (item.score > 0)
                        _InlineMeta(
                          icon: Icons.scatter_plot_outlined,
                          label: item.score.toStringAsFixed(2),
                        ),
                    ],
                  ),
                  if (item.updatedAt.isNotEmpty || item.createdAt.isNotEmpty) ...[
                    const SizedBox(height: 8),
                    Text(
                      _subtitle,
                      style: const TextStyle(
                        fontSize: 12,
                        color: Colors.black54,
                        height: 1.3,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  String get _subtitle {
    final parts = <String>[];
    if (item.updatedAt.isNotEmpty) {
      parts.add('更新于 ${item.updatedAt}');
    } else if (item.createdAt.isNotEmpty) {
      parts.add('创建于 ${item.createdAt}');
    }
    if (item.pinnedAt.isNotEmpty) {
      parts.add('置顶于 ${item.pinnedAt}');
    }
    return parts.isEmpty ? '长期记忆' : parts.join(' · ');
  }
}

class _MemoryPreferencePanel extends StatelessWidget {
  const _MemoryPreferencePanel({
    required this.preference,
    required this.busy,
    required this.onChanged,
  });

  final MemoryPreferenceState? preference;
  final bool busy;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    final enabled = preference?.longTermEnabled ?? true;

    return DecoratedBox(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.black.withValues(alpha: 0.08)),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
        child: SwitchListTile.adaptive(
          contentPadding: EdgeInsets.zero,
          title: const Text(
            '长期记忆',
            style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
          ),
          subtitle: Text(
            enabled ? '当前已启用自动检索与写入。' : '当前已关闭自动检索与写入。',
            style: const TextStyle(fontSize: 12, color: Colors.black54),
          ),
          value: enabled,
          onChanged: busy ? null : onChanged,
        ),
      ),
    );
  }
}

class _MemoryMergeBar extends StatelessWidget {
  const _MemoryMergeBar({
    required this.selectedCount,
    required this.busy,
    required this.onClear,
    required this.onMerge,
  });

  final int selectedCount;
  final bool busy;
  final VoidCallback onClear;
  final VoidCallback onMerge;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: const Color(0xFFF7F8FC),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.black.withValues(alpha: 0.08)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          children: [
            const Icon(Icons.call_merge, size: 20),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                '已选择 $selectedCount 条记忆，可进行冲突合并。',
                style: const TextStyle(fontSize: 13, height: 1.2),
              ),
            ),
            TextButton.icon(
              onPressed: busy ? null : onClear,
              icon: const Icon(Icons.clear),
              label: const Text('清除'),
            ),
            const SizedBox(width: 8),
            FilledButton.icon(
              onPressed: busy ? null : onMerge,
              icon: const Icon(Icons.call_merge),
              label: const Text('合并'),
            ),
          ],
        ),
      ),
    );
  }
}

class _InlineMeta extends StatelessWidget {
  const _InlineMeta({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 14, color: Colors.black54),
        const SizedBox(width: 4),
        Text(
          label,
          style: const TextStyle(fontSize: 12, color: Colors.black54),
        ),
      ],
    );
  }
}

const List<String> _memoryCategoryOptions = [
  'identity',
  'preference',
  'relationship',
  'goal',
  'habit',
  'boundary',
  'event',
  'other',
];

const List<String> _memoryImportanceOptions = [
  'low',
  'medium',
  'high',
];

String _normalizeOption(String value, List<String> options) {
  if (options.contains(value)) {
    return value;
  }
  return options.first;
}

class _MemoryEmptyState extends StatelessWidget {
  const _MemoryEmptyState({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onRetry,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 48, color: Colors.black45),
            const SizedBox(height: 12),
            Text(
              title,
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 8),
            Text(
              subtitle,
              textAlign: TextAlign.center,
              style: const TextStyle(color: Colors.black54),
            ),
            const SizedBox(height: 16),
            OutlinedButton.icon(
              onPressed: onRetry,
              icon: const Icon(Icons.refresh),
              label: const Text('刷新'),
            ),
          ],
        ),
      ),
    );
  }
}
