import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'chat_message.dart';

class MessageActions {
  static Future<void> show({
    required BuildContext context,
    required ChatMessage message,
    required ValueChanged<ChatMessage> onPlayAudio,
  }) async {
    final hasAudio =
        message.audioUrl.isNotEmpty ||
        (message.live2d?.character.mouth.audioUrl ?? '').isNotEmpty;

    await showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (context) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
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
              if (hasAudio)
                ListTile(
                  leading: const Icon(Icons.volume_up_outlined),
                  title: const Text('播放语音'),
                  onTap: () {
                    Navigator.of(context).pop();
                    onPlayAudio(message);
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
