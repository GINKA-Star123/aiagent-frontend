import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:share_plus/share_plus.dart';

import 'chat_message.dart';

class MessageActions {
  static Future<void> show({
    required BuildContext context,
    required ChatMessage message,
    required ValueChanged<ChatMessage> onPlayAudio,
    bool playing = false,
    ValueChanged<ChatMessage>? onRetry,
    ValueChanged<ChatMessage>? onDelete,
    ValueChanged<ChatMessage>? onQuote,
    ValueChanged<ChatMessage>? onSelect,
    ValueChanged<ChatMessage>? onToggleUnread,
    ValueChanged<ChatMessage>? onToggleFavorite,
    bool markedUnread = false,
  }) async {
    final hasAudio = message.audioUrl.isNotEmpty;

    await showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (context) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (onSelect != null)
                ListTile(
                  leading: const Icon(Icons.checklist),
                  title: const Text('多选'),
                  onTap: () {
                    Navigator.of(context).pop();
                    onSelect(message);
                  },
                ),
              if (onToggleUnread != null)
                ListTile(
                  leading: Icon(
                    markedUnread
                        ? Icons.mark_chat_read_outlined
                        : Icons.mark_chat_unread_outlined,
                  ),
                  title: Text(markedUnread ? '清除未读标记' : '标记未读'),
                  onTap: () {
                    Navigator.of(context).pop();
                    onToggleUnread(message);
                  },
                ),
              if (onToggleFavorite != null)
                ListTile(
                  leading: const Icon(Icons.bookmark_border),
                  title: const Text('收藏消息'),
                  onTap: () {
                    Navigator.of(context).pop();
                    onToggleFavorite(message);
                  },
                ),
              if (message.status == ChatMessageStatus.failed ||
                  message.status == ChatMessageStatus.queued)
                ListTile(
                  leading: const Icon(Icons.refresh),
                  title: const Text('重试发送'),
                  onTap: () {
                    Navigator.of(context).pop();
                    onRetry?.call(message);
                  },
                ),
              if (onQuote != null)
                ListTile(
                  leading: const Icon(Icons.reply),
                  title: const Text('引用'),
                  onTap: () {
                    Navigator.of(context).pop();
                    onQuote(message);
                  },
                ),
              ListTile(
                leading: const Icon(Icons.copy_outlined),
                title: const Text('复制文本'),
                onTap: () async {
                  await Clipboard.setData(ClipboardData(text: message.text));
                  if (context.mounted) {
                    Navigator.of(context).pop();
                    ScaffoldMessenger.of(
                      context,
                    ).showSnackBar(const SnackBar(content: Text('已复制')));
                  }
                },
              ),
              if (message.text.trim().isNotEmpty)
                ListTile(
                  leading: const Icon(Icons.share_outlined),
                  title: const Text('分享文本'),
                  onTap: () async {
                    try {
                      await Share.share(message.text, subject: '聊天消息');
                    } catch (_) {
                      // 分享失败不阻塞菜单关闭。
                    }
                    if (context.mounted) {
                      Navigator.of(context).pop();
                    }
                  },
                ),
              if (message.text.trim().isNotEmpty)
                ListTile(
                  leading: const Icon(Icons.format_quote),
                  title: const Text('复制引用'),
                  onTap: () async {
                    final sender = message.role == ChatRole.user
                        ? '我'
                        : 'AIAgent';
                    final buffer = StringBuffer('> [')
                      ..write(sender)
                      ..write('] ')
                      ..write(message.text.replaceAll('\n', ' '));
                    await Clipboard.setData(
                      ClipboardData(text: buffer.toString()),
                    );
                    if (context.mounted) {
                      Navigator.of(context).pop();
                      ScaffoldMessenger.of(
                        context,
                      ).showSnackBar(const SnackBar(content: Text('已复制引用')));
                    }
                  },
                ),
              if (hasAudio)
                ListTile(
                  leading: Icon(
                    playing
                        ? Icons.stop_circle_outlined
                        : Icons.volume_up_outlined,
                  ),
                  title: Text(playing ? '停止播放' : '播放语音'),
                  onTap: () {
                    Navigator.of(context).pop();
                    onPlayAudio(message);
                  },
                ),
              if (onDelete != null)
                ListTile(
                  leading: const Icon(
                    Icons.delete_outline,
                    color: Color(0xFFB3261E),
                  ),
                  title: const Text(
                    '删除消息',
                    style: TextStyle(color: Color(0xFFB3261E)),
                  ),
                  onTap: () {
                    Navigator.of(context).pop();
                    onDelete(message);
                  },
                ),
              ListTile(
                leading: const Icon(Icons.close),
                title: const Text('取消'),
                onTap: () => Navigator.of(context).pop(),
              ),
            ],
          ),
        );
      },
    );
  }
}
