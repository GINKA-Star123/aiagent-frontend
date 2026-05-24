import 'package:flutter/material.dart';

class AboutPage extends StatelessWidget {
  const AboutPage({
    super.key,
    required this.apiBaseUrl,
    required this.username,
    required this.userId,
  });

  final String apiBaseUrl;
  final String username;
  final String userId;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('关于')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          const Icon(Icons.auto_awesome, size: 52, color: Color(0xFFC74444)),
          const SizedBox(height: 12),
          Text(
            'AIAgent Mobile',
            textAlign: TextAlign.center,
            style: Theme.of(
              context,
            ).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 4),
          const Text(
            'V1.0 RC1 · 1.0.0-rc.1',
            textAlign: TextAlign.center,
            style: TextStyle(color: Colors.black54),
          ),
          const SizedBox(height: 24),
          _AboutSection(
            title: '当前连接',
            children: [
              _AboutTile(icon: Icons.link, title: '后端地址', value: apiBaseUrl),
              _AboutTile(
                icon: Icons.person_outline,
                title: '当前用户',
                value: username,
              ),
              _AboutTile(
                icon: Icons.badge_outlined,
                title: '用户 ID',
                value: userId,
              ),
            ],
          ),
          const SizedBox(height: 16),
          const _AboutSection(
            title: '功能',
            children: [
              _AboutTile(
                icon: Icons.chat_bubble_outline,
                title: '聊天',
                value: '文本、多模态图片、语音输入',
              ),
              _AboutTile(
                icon: Icons.volume_up_outlined,
                title: '语音',
                value: '手机端播放 TTS，可自动播放或手动重播',
              ),
              _AboutTile(
                icon: Icons.bookmark_border,
                title: '记忆',
                value: '查看和清空当前用户的长期记忆',
              ),
              _AboutTile(
                icon: Icons.view_in_ar_outlined,
                title: 'Live2D',
                value: '过渡模型已接入，支持待机动作和说话口型',
              ),
            ],
          ),
          const SizedBox(height: 16),
          const Text(
            '数据会发送到你配置的 AIAgent 后端处理。请只连接你信任的后端服务。',
            style: TextStyle(fontSize: 12, color: Colors.black54),
          ),
        ],
      ),
    );
  }
}

class _AboutSection extends StatelessWidget {
  const _AboutSection({required this.title, required this.children});

  final String title;
  final List<Widget> children;

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
              title,
              style: Theme.of(
                context,
              ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 10),
            ...children,
          ],
        ),
      ),
    );
  }
}

class _AboutTile extends StatelessWidget {
  const _AboutTile({
    required this.icon,
    required this.title,
    required this.value,
  });

  final IconData icon;
  final String title;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 7),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 20, color: Colors.black54),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(fontSize: 12, color: Colors.black54),
                ),
                const SizedBox(height: 2),
                SelectableText(
                  value.isEmpty ? '未设置' : value,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
