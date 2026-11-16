import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'chat_message.dart';

class ChatSearchPage extends StatefulWidget {
  const ChatSearchPage({super.key, required this.messages});

  final List<ChatMessage> messages;

  @override
  State<ChatSearchPage> createState() => _ChatSearchPageState();
}

class _ChatSearchPageState extends State<ChatSearchPage> {
  final TextEditingController _controller = TextEditingController();
  String _query = '';
  String _senderFilter = 'all';
  String _typeFilter = 'all';

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  List<ChatMessage> get _results {
    final query = _query.trim().toLowerCase();
    if (query.isEmpty) {
      return const [];
    }
    return widget.messages
        .where((message) {
          if (!message.text.toLowerCase().contains(query)) {
            return false;
          }
          if (_senderFilter == 'me' && message.role != ChatRole.user) {
            return false;
          }
          if (_senderFilter == 'agent' && message.role != ChatRole.assistant) {
            return false;
          }
          if (_typeFilter != 'all' && _messageType(message) != _typeFilter) {
            return false;
          }
          return true;
        })
        .toList()
        .reversed
        .toList();
  }

  String _messageType(ChatMessage message) {
    if (message.imagePath.isNotEmpty) {
      return 'image';
    }
    if (message.text.startsWith('[语音')) {
      return 'voice';
    }
    return 'text';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF2F3F5),
      appBar: AppBar(
        backgroundColor: Colors.white,
        titleSpacing: 0,
        title: TextField(
          controller: _controller,
          autofocus: true,
          textInputAction: TextInputAction.search,
          decoration: const InputDecoration(
            hintText: '搜索聊天记录',
            border: InputBorder.none,
            isDense: true,
          ),
          onChanged: (value) {
            setState(() {
              _query = value;
            });
          },
        ),
        actions: [
          if (_query.isNotEmpty)
            IconButton(
              tooltip: '清空',
              onPressed: () {
                _controller.clear();
                setState(() {
                  _query = '';
                });
              },
              icon: const Icon(Icons.close),
            ),
        ],
      ),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    if (_query.trim().isEmpty) {
      return const Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.search, size: 48, color: Color(0xFFBBBBBB)),
            SizedBox(height: 12),
            Text('输入关键字搜索聊天记录', style: TextStyle(color: Color(0xFF999999))),
            SizedBox(height: 6),
            Text(
              '点击结果跳转到原消息，长按查看全文',
              style: TextStyle(fontSize: 12, color: Color(0xFFAAAAAA)),
            ),
          ],
        ),
      );
    }

    final results = _results;
    return Column(
      children: [
        _buildFilterBar(),
        Expanded(
          child: results.isEmpty
              ? const Center(
                  child: Text(
                    '没有找到相关消息',
                    style: TextStyle(color: Color(0xFF999999)),
                  ),
                )
              : ListView.separated(
                  padding: const EdgeInsets.fromLTRB(12, 8, 12, 16),
                  itemCount: results.length,
                  separatorBuilder: (context, index) =>
                      const SizedBox(height: 8),
                  itemBuilder: (context, index) {
                    final message = results[index];
                    return Material(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(10),
                      child: ListTile(
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                        leading: CircleAvatar(
                          backgroundColor: message.role == ChatRole.user
                              ? const Color(0xFF5B8CFF)
                              : const Color(0xFFC74444),
                          child: Text(
                            message.role == ChatRole.user ? '我' : '绫',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                        title: Row(
                          children: [
                            Text(
                              _senderName(message),
                              style: const TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            const SizedBox(width: 6),
                            _TypeBadge(type: _messageType(message)),
                            const Spacer(),
                            Text(
                              _formatTime(message.createdAt),
                              style: const TextStyle(
                                fontSize: 11,
                                color: Color(0xFF999999),
                              ),
                            ),
                          ],
                        ),
                        subtitle: Padding(
                          padding: const EdgeInsets.only(top: 4),
                          child: _HighlightedText(
                            text: _snippet(message.text, _query.trim()),
                            query: _query.trim(),
                          ),
                        ),
                        onTap: () => Navigator.of(context).pop(message),
                        onLongPress: () => _showDetail(message),
                      ),
                    );
                  },
                ),
        ),
      ],
    );
  }

  Widget _buildFilterBar() {
    final count = _results.length;
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            height: 36,
            child: ListView(
              scrollDirection: Axis.horizontal,
              children: [
                _filterChip(
                  label: '全部',
                  selected: _senderFilter == 'all',
                  onTap: () => setState(() => _senderFilter = 'all'),
                ),
                _filterChip(
                  label: '我',
                  selected: _senderFilter == 'me',
                  onTap: () => setState(() => _senderFilter = 'me'),
                ),
                _filterChip(
                  label: 'AIAgent',
                  selected: _senderFilter == 'agent',
                  onTap: () => setState(() => _senderFilter = 'agent'),
                ),
                const VerticalDivider(width: 12, indent: 8, endIndent: 8),
                _filterChip(
                  label: '文字',
                  selected: _typeFilter == 'text',
                  onTap: () => setState(() => _typeFilter = 'text'),
                ),
                _filterChip(
                  label: '图片',
                  selected: _typeFilter == 'image',
                  onTap: () => setState(() => _typeFilter = 'image'),
                ),
                _filterChip(
                  label: '语音',
                  selected: _typeFilter == 'voice',
                  onTap: () => setState(() => _typeFilter = 'voice'),
                ),
                _filterChip(
                  label: '全部类型',
                  selected: _typeFilter == 'all',
                  onTap: () => setState(() => _typeFilter = 'all'),
                ),
              ],
            ),
          ),
          const SizedBox(height: 4),
          Text(
            '共 $count 条结果',
            style: const TextStyle(fontSize: 11, color: Color(0xFF999999)),
          ),
        ],
      ),
    );
  }

  Widget _filterChip({
    required String label,
    required bool selected,
    required VoidCallback onTap,
  }) {
    return Padding(
      padding: const EdgeInsets.only(right: 6),
      child: ChoiceChip(
        label: Text(label),
        selected: selected,
        onSelected: (_) => onTap(),
        visualDensity: VisualDensity.compact,
        materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
      ),
    );
  }

  String _senderName(ChatMessage message) {
    switch (message.role) {
      case ChatRole.user:
        return '我';
      case ChatRole.system:
        return '系统';
      case ChatRole.assistant:
        return 'AIAgent';
    }
  }

  String _snippet(String text, String query) {
    final index = text.toLowerCase().indexOf(query.toLowerCase());
    if (index < 0) {
      return text;
    }
    final start = (index - 30).clamp(0, text.length);
    final end = (index + query.length + 60).clamp(0, text.length);
    final prefix = start > 0 ? '…' : '';
    final suffix = end < text.length ? '…' : '';
    return prefix + text.substring(start, end) + suffix;
  }

  String _formatTime(DateTime value) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final day = DateTime(value.year, value.month, value.day);
    final hm =
        '${value.hour.toString().padLeft(2, '0')}:${value.minute.toString().padLeft(2, '0')}';
    final diff = today.difference(day).inDays;
    if (diff == 0) {
      return '今天 $hm';
    }
    if (diff == 1) {
      return '昨天 $hm';
    }
    return '${value.month}月${value.day}日 $hm';
  }

  Future<void> _showDetail(ChatMessage message) async {
    final messenger = ScaffoldMessenger.of(context);
    await showDialog<void>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: Text(_senderName(message)),
          content: SingleChildScrollView(
            child: SelectableText(
              message.text,
              style: const TextStyle(fontSize: 14, height: 1.5),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () async {
                await Clipboard.setData(ClipboardData(text: message.text));
                if (dialogContext.mounted) {
                  Navigator.of(dialogContext).pop();
                  messenger.showSnackBar(const SnackBar(content: Text('已复制')));
                }
              },
              child: const Text('复制'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(dialogContext).pop(),
              child: const Text('关闭'),
            ),
          ],
        );
      },
    );
  }
}

class _TypeBadge extends StatelessWidget {
  const _TypeBadge({required this.type});

  final String type;

  @override
  Widget build(BuildContext context) {
    if (type == 'text') {
      return const SizedBox.shrink();
    }
    final label = type == 'image' ? '图片' : '语音';
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
      decoration: BoxDecoration(
        color: const Color(0xFFF0F1F3),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        label,
        style: const TextStyle(fontSize: 10, color: Color(0xFF777777)),
      ),
    );
  }
}

class _HighlightedText extends StatelessWidget {
  const _HighlightedText({required this.text, required this.query});

  final String text;
  final String query;

  @override
  Widget build(BuildContext context) {
    final lowerText = text.toLowerCase();
    final lowerQuery = query.toLowerCase();
    if (lowerQuery.isEmpty || !lowerText.contains(lowerQuery)) {
      return Text(
        text,
        maxLines: 3,
        overflow: TextOverflow.ellipsis,
        style: const TextStyle(fontSize: 13, color: Color(0xFF555555)),
      );
    }

    final spans = <TextSpan>[];
    var cursor = 0;
    while (cursor < text.length) {
      final index = lowerText.indexOf(lowerQuery, cursor);
      if (index < 0) {
        spans.add(TextSpan(text: text.substring(cursor)));
        break;
      }
      if (index > cursor) {
        spans.add(TextSpan(text: text.substring(cursor, index)));
      }
      spans.add(
        TextSpan(
          text: text.substring(index, index + lowerQuery.length),
          style: const TextStyle(
            color: Color(0xFFC74444),
            fontWeight: FontWeight.w600,
          ),
        ),
      );
      cursor = index + lowerQuery.length;
    }

    return Text.rich(
      TextSpan(
        children: spans,
        style: const TextStyle(fontSize: 13, color: Color(0xFF555555)),
      ),
      maxLines: 3,
      overflow: TextOverflow.ellipsis,
    );
  }
}
