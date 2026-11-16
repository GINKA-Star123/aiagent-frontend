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
  String _senderFilter = 'all';
  String _typeFilter = 'all';
  bool _newestFirst = true;
  bool _loading = true;

  List<FavoriteMessage> get _filteredItems {
    final query = _query.trim().toLowerCase();
    final result = _items.where((item) {
      if (query.isNotEmpty && !item.text.toLowerCase().contains(query)) {
        return false;
      }
      if (_senderFilter == 'me' && item.sender != '我') {
        return false;
      }
      if (_senderFilter == 'agent' && item.sender != 'AIAgent') {
        return false;
      }
      if (_typeFilter != 'all' && _typeOf(item) != _typeFilter) {
        return false;
      }
      return true;
    }).toList();
    result.sort(
      (a, b) => _newestFirst
          ? b.createdAt.compareTo(a.createdAt)
          : a.createdAt.compareTo(b.createdAt),
    );
    return result;
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

  String _typeOf(FavoriteMessage item) {
    if (item.imagePath.isNotEmpty) {
      return 'image';
    }
    if (item.text.startsWith('[语音')) {
      return 'voice';
    }
    return 'text';
  }

  Future<void> _clearAll() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('清空收藏夹'),
          content: Text('将删除全部 ${_items.length} 条收藏，且不可恢复。'),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(false),
              child: const Text('取消'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(dialogContext).pop(true),
              child: const Text('清空'),
            ),
          ],
        );
      },
    );
    if (confirmed != true || !mounted) {
      return;
    }
    await FavoriteStore.clear(widget.userId);
    if (!mounted) {
      return;
    }
    setState(() {
      _items = [];
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

  Widget _filterChip(String label, String value) {
    return ChoiceChip(
      label: Text(label),
      selected: _senderFilter == value,
      onSelected: (_) {
        setState(() {
          _senderFilter = value;
        });
      },
      visualDensity: VisualDensity.compact,
      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF2F3F5),
      appBar: AppBar(
        backgroundColor: Colors.white,
        title: Text('收藏夹（${_items.length}）'),
        actions: [
          PopupMenuButton<String>(
            tooltip: '筛选类型',
            icon: Icon(
              Icons.filter_alt_outlined,
              color: _typeFilter == 'all' ? null : const Color(0xFFC74444),
            ),
            onSelected: (value) {
              setState(() {
                _typeFilter = value;
              });
            },
            itemBuilder: (context) => const [
              PopupMenuItem<String>(value: 'all', child: Text('全部类型')),
              PopupMenuItem<String>(value: 'text', child: Text('文字')),
              PopupMenuItem<String>(value: 'image', child: Text('图片')),
              PopupMenuItem<String>(value: 'voice', child: Text('语音')),
            ],
          ),
          IconButton(
            tooltip: _newestFirst ? '当前最新在前' : '当前最早在前',
            onPressed: () {
              setState(() {
                _newestFirst = !_newestFirst;
              });
            },
            icon: const Icon(Icons.swap_vert),
          ),
          IconButton(
            tooltip: '清空收藏',
            onPressed: _items.isEmpty ? null : _clearAll,
            icon: const Icon(Icons.delete_sweep_outlined),
          ),
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(104),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(12, 0, 12, 8),
            child: Column(
              children: [
                TextField(
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
                const SizedBox(height: 6),
                Row(
                  children: [
                    _filterChip('全部', 'all'),
                    const SizedBox(width: 6),
                    _filterChip('我', 'me'),
                    const SizedBox(width: 6),
                    _filterChip('AIAgent', 'agent'),
                    const Spacer(),
                    Text(
                      '${_filteredItems.length} 条',
                      style: const TextStyle(
                        fontSize: 11,
                        color: Color(0xFF999999),
                      ),
                    ),
                  ],
                ),
              ],
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
