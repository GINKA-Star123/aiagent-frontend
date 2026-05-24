import 'package:flutter/material.dart';

import '../identity/user_identity.dart';

class ProfilePage extends StatefulWidget {
  const ProfilePage({super.key, required this.identity, required this.onSave});

  final UserIdentity identity;
  final Future<void> Function(UserIdentity identity) onSave;

  @override
  State<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage> {
  late final TextEditingController _usernameController;

  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _usernameController = TextEditingController(text: widget.identity.username);
  }

  @override
  void dispose() {
    _usernameController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final username = _usernameController.text.trim();
    if (username.isEmpty || _saving) {
      return;
    }

    setState(() {
      _saving = true;
    });

    try {
      await widget.onSave(widget.identity.copyWith(username: username));
      if (!mounted) {
        return;
      }

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('资料已保存')));
      Navigator.of(context).pop();
    } finally {
      if (mounted) {
        setState(() {
          _saving = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('个人资料')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          TextField(
            controller: _usernameController,
            textInputAction: TextInputAction.done,
            onSubmitted: (_) => _save(),
            decoration: const InputDecoration(
              labelText: '昵称',
              hintText: '给自己取个名字',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 16),
          _ProfileInfoTile(
            icon: Icons.badge_outlined,
            title: '本地用户 ID',
            value: widget.identity.userId,
          ),
          const SizedBox(height: 10),
          _ProfileInfoTile(
            icon: Icons.phone_android_outlined,
            title: '设备 ID',
            value: widget.identity.deviceId,
          ),
          const SizedBox(height: 10),
          _ProfileInfoTile(
            icon: Icons.event_outlined,
            title: '创建时间',
            value: widget.identity.createdAt.toIso8601String(),
          ),
          const SizedBox(height: 24),
          FilledButton.icon(
            onPressed: _saving ? null : _save,
            icon: _saving
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.save_outlined),
            label: const Text('保存资料'),
          ),
        ],
      ),
    );
  }
}

class _ProfileInfoTile extends StatelessWidget {
  const _ProfileInfoTile({
    required this.icon,
    required this.title,
    required this.value,
  });

  final IconData icon;
  final String title;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.black.withValues(alpha: 0.08)),
      ),
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
                const SizedBox(height: 3),
                SelectableText(
                  value,
                  style: const TextStyle(
                    fontSize: 13,
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
