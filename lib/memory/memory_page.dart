import 'package:flutter/material.dart';

import '../api/api_client.dart';
import 'memory_models.dart';

class MemoryPage extends StatefulWidget {
  const MemoryPage({super.key, required this.apiClient, required this.userId});

  final ApiClient apiClient;
  final String userId;

  @override
  State<MemoryPage> createState() => _MemoryPageState();
}

class _MemoryPageState extends State<MemoryPage> {
  bool _loading = true;
  String _errorText = '';
  UserMemoryResponse? _memory;

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
      final memory = await widget.apiClient.getUserMemory(widget.userId);
      if (!mounted) {
        return;
      }

      setState(() {
        _memory = memory;
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

    await widget.apiClient.clearUserMemory(widget.userId);
    await _loadMemory();
  }

  @override
  Widget build(BuildContext context) {
    final memory = _memory;
    final items = memory == null
        ? <MemoryItem>[]
        : [...memory.profileMemories, ...memory.longTermMemories];

    return Scaffold(
      appBar: AppBar(
        title: const Text('记忆'),
        actions: [
          IconButton(
            tooltip: '刷新',
            onPressed: _loadMemory,
            icon: const Icon(Icons.refresh),
          ),
          IconButton(
            tooltip: '清空长期记忆',
            onPressed: items.isEmpty ? null : _confirmClearMemory,
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

          if (items.isEmpty) {
            return _MemoryEmptyState(
              icon: Icons.bookmark_border,
              title: '还没有长期记忆',
              subtitle: '当对话里出现值得保留的信息时，阿绫会把它记下来。',
              onRetry: _loadMemory,
            );
          }

          return ListView.separated(
            padding: const EdgeInsets.all(16),
            itemCount: items.length,
            separatorBuilder: (_, __) => const SizedBox(height: 10),
            itemBuilder: (context, index) {
              return _MemoryCard(item: items[index]);
            },
          );
        },
      ),
    );
  }
}

class _MemoryCard extends StatelessWidget {
  const _MemoryCard({required this.item});

  final MemoryItem item;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.black.withValues(alpha: 0.08)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              item.text.isEmpty ? '空记忆' : item.text,
              style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 8),
            Text(
              _subtitle,
              style: const TextStyle(fontSize: 12, color: Colors.black54),
            ),
          ],
        ),
      ),
    );
  }

  String get _subtitle {
    final parts = <String>[];
    if (item.score > 0) {
      parts.add('相关度 ${item.score.toStringAsFixed(2)}');
    }
    if (item.updatedAt.isNotEmpty) {
      parts.add('更新于 ${item.updatedAt}');
    } else if (item.createdAt.isNotEmpty) {
      parts.add('创建于 ${item.createdAt}');
    }
    return parts.isEmpty ? '长期记忆' : parts.join(' · ');
  }
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
