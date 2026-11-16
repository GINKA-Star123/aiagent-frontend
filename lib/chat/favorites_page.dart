import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'favorite_store.dart';

class FavoritesPage extends StatefulWidget {
  const FavoritesPage({super.key, required this.userId});

  final String userId;

  @override
  State<FavoritesPage> createState() => _FavoritesPageState();
}

class _FavoritesPageState extends State<FavoritesPage> {
  final TextEditingController _searchController = TextEditingController();
  List<FavoriteMessage> _items = [];
  String _query = '';
  bool _loading = true;

  List<FavoriteMessage> get _filteredItems {
    final query = _query.trim().toLowerCase();
    if (query.isEmpty) {
      return _items;
    }
    return _items
        .where((item) => item.text.toLowerCase().contains(query))
        .toList();
  }

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    final items = await FavoriteStore.load(widget.userId);
    if (!mounted) {
      return;
    }
    setState(() {
      _items = items;
      _loading = false;
    });
  }

  Future<void> _copy(FavoriteMessage item) async {
    await Clipboard.setData(ClipboardData(text: item.text));
    if (!mounted) {
      return;
    }
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('已复制')));
  }

  Future<void> _remove(FavoriteMessage item) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('取消收藏'),
          content: const Text('从收藏夹移除这条消息？'),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(false),
              child: const Text('取消'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(dialogContext).pop(true),
              child: const Text('移除'),
            ),
          ],
        );
      },
    );
    if (confirmed != true || !mounted) {
      return;
    }
    await FavoriteStore.remove(widget.userId, item.key);
    if (!mounted) {
      return;
    }
    setState(() {
      _items = _items.where((value) => value.key != item.key).toList();
    });
  }

  Future<void> _showDetail(FavoriteMessage item) async {
    final messenger = ScaffoldMessenger.of(context);
    await showDialog<void>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: Text(item.sender),
          content: SingleChildScrollView(
            child: SelectableText(
              item.text,
              style: const TextStyle(fontSize: 14, height: 1.5),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () async {
                await Clipboard.setData(ClipboardData(text: item.text));
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

  String _formatTime(DateTime value) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final day = DateTime(value.year, value.month, value.day);
    final minute = value.minute.toString().padLeft(2, '0');
    final hm = '${value.hour.toString().padLeft(2, '0')}:$minute';
    final diff = today.difference(day).inDays;
    if (diff == 0) {
      return '今天 $hm';
    }
    if (diff == 1) {
      return '昨天 $hm';
    }
    if (value.year == now.year) {
      return '${value.month}月${value.day}日';
    }
    return '${value.year}年${value.month}月${value.day}日';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF2F3F5),
      appBar: AppBar(
        backgroundColor: Colors.white,
        title: Text('收藏夹（${_items.length}）'),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(52),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(12, 0, 12, 8),
            child: TextField(
              controller: _searchController,
              onChanged: (value) {
                setState(() {
                  _query = value;
                });
              },
              decoration: InputDecoration(
                hintText: '搜索收藏内容',
                isDense: true,
                prefixIcon: const Icon(Icons.search, size: 18),
                suffixIcon: _query.isEmpty
                    ? null
                    : IconButton(
                        tooltip: '清空',
                        onPressed: () {
                          _searchController.clear();
                          setState(() {
                            _query = '';
                          });
                        },
                        icon: const Icon(Icons.close, size: 18),
                      ),
                filled: true,
                fillColor: const Color(0xFFF2F3F5),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: BorderSide.none,
                ),
              ),
            ),
          ),
        ),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _items.isEmpty
          ? const Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.bookmark_border,
                    size: 48,
                    color: Color(0xFFBBBBBB),
                  ),
                  SizedBox(height: 12),
                  Text('还没有收藏消息', style: TextStyle(color: Color(0xFF999999))),
                  SizedBox(height: 4),
                  Text(
                    '长按聊天消息即可收藏',
                    style: TextStyle(fontSize: 12, color: Color(0xFFAAAAAA)),
                  ),
                ],
              ),
            )
          : _filteredItems.isEmpty
          ? const Center(
              child: Text(
                '没有找到相关收藏',
                style: TextStyle(color: Color(0xFF999999)),
              ),
            )
          : ListView.separated(
              padding: const EdgeInsets.fromLTRB(12, 12, 12, 24),
              itemCount: _filteredItems.length,
              separatorBuilder: (context, index) => const SizedBox(height: 8),
              itemBuilder: (context, index) {
                final item = _filteredItems[index];
                return Material(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(10),
                  child: ListTile(
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                    onTap: () => _showDetail(item),
                    title: Row(
                      children: [
                        Text(
                          item.sender,
                          style: const TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        if (item.imagePath.isNotEmpty) ...[
                          const SizedBox(width: 6),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 5,
                              vertical: 1,
                            ),
                            decoration: BoxDecoration(
                              color: const Color(0xFFF0F1F3),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: const Text(
                              '图片',
                              style: TextStyle(
                                fontSize: 10,
                                color: Color(0xFF777777),
                              ),
                            ),
                          ),
                        ],
                        const Spacer(),
                        Text(
                          _formatTime(item.createdAt),
                          style: const TextStyle(
                            fontSize: 11,
                            color: Color(0xFF999999),
                          ),
                        ),
                      ],
                    ),
                    subtitle: Padding(
                      padding: const EdgeInsets.only(top: 4),
                      child: Text(
                        item.text,
                        maxLines: 4,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 13,
                          color: Color(0xFF555555),
                        ),
                      ),
                    ),
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        IconButton(
                          tooltip: '复制',
                          onPressed: () => _copy(item),
                          icon: const Icon(Icons.copy_outlined, size: 18),
                        ),
                        IconButton(
                          tooltip: '取消收藏',
                          onPressed: () => _remove(item),
                          icon: const Icon(
                            Icons.bookmark_remove_outlined,
                            size: 18,
                            color: Color(0xFFB3261E),
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
    );
  }
}
