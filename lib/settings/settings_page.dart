import 'dart:io';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../profile/avatar_store.dart';

class SettingsPage extends StatefulWidget {
  const SettingsPage({
    super.key,
    required this.userId,
    required this.myAvatarPath,
    required this.agentAvatarPath,
    required this.onAvatarsChanged,
    required this.apiBaseUrl,
    required this.username,
    required this.statusText,
    required this.autoPlayVoice,
    required this.onSaveApiBaseUrl,
    required this.onAutoPlayVoiceChanged,
    required this.onOpenProfile,
    required this.onOpenMemory,
    required this.onOpenAbout,
    required this.onCheckHealth,
    required this.onClearHistory,
    required this.onLogout,
  });

  final String userId;
  final String myAvatarPath;
  final String agentAvatarPath;
  final Future<void> Function() onAvatarsChanged;
  final String apiBaseUrl;
  final String username;
  final String statusText;
  final bool autoPlayVoice;
  final Future<void> Function(String apiBaseUrl) onSaveApiBaseUrl;
  final Future<void> Function(bool value) onAutoPlayVoiceChanged;
  final VoidCallback onOpenProfile;
  final VoidCallback onOpenMemory;
  final VoidCallback onOpenAbout;
  final Future<void> Function() onCheckHealth;
  final Future<void> Function() onClearHistory;
  final Future<void> Function() onLogout;

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  late final TextEditingController _apiBaseUrlController;

  bool _saving = false;
  bool _checking = false;
  bool _clearing = false;
  bool _loggingOut = false;
  late bool _autoPlayVoice;
  late String _myAvatarPath;
  late String _agentAvatarPath;
  final ImagePicker _imagePicker = ImagePicker();
  bool _pickingAvatar = false;

  @override
  void initState() {
    super.initState();
    _apiBaseUrlController = TextEditingController(text: widget.apiBaseUrl);
    _autoPlayVoice = widget.autoPlayVoice;
    _myAvatarPath = widget.myAvatarPath;
    _agentAvatarPath = widget.agentAvatarPath;
  }

  @override
  void dispose() {
    _apiBaseUrlController.dispose();
    super.dispose();
  }

  Future<void> _saveApiBaseUrl() async {
    final nextBaseUrl = _apiBaseUrlController.text.trim();
    if (nextBaseUrl.isEmpty || _saving) {
      return;
    }

    setState(() {
      _saving = true;
    });

    try {
      await widget.onSaveApiBaseUrl(nextBaseUrl);
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('服务器地址已保存')));
    } finally {
      if (mounted) {
        setState(() {
          _saving = false;
        });
      }
    }
  }

  Future<void> _checkHealth() async {
    if (_checking) {
      return;
    }

    setState(() {
      _checking = true;
    });

    try {
      await widget.onCheckHealth();
    } finally {
      if (mounted) {
        setState(() {
          _checking = false;
        });
      }
    }
  }

  Future<void> _confirmClearHistory() async {
    if (_clearing) {
      return;
    }

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('清空聊天记录'),
          content: const Text('清空后，本机保存的聊天记录会被删除。'),
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

    setState(() {
      _clearing = true;
    });

    try {
      await widget.onClearHistory();
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('聊天记录已清空')));
    } finally {
      if (mounted) {
        setState(() {
          _clearing = false;
        });
      }
    }
  }

  Future<void> _confirmLogout() async {
    if (_loggingOut) {
      return;
    }

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('退出登录'),
          content: const Text('退出后会回到登录页，本机聊天记录不会自动删除。'),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('取消'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(context).pop(true),
              child: const Text('退出'),
            ),
          ],
        );
      },
    );

    if (confirmed != true) {
      return;
    }

    setState(() {
      _loggingOut = true;
    });

    try {
      await widget.onLogout();
      if (mounted) {
        Navigator.of(context).pop();
      }
    } finally {
      if (mounted) {
        setState(() {
          _loggingOut = false;
        });
      }
    }
  }

  Future<void> _setAutoPlayVoice(bool value) async {
    setState(() {
      _autoPlayVoice = value;
    });
    await widget.onAutoPlayVoiceChanged(value);
  }

  Future<void> _pickAvatar(AvatarOwner owner) async {
    if (_pickingAvatar || widget.userId.isEmpty) {
      return;
    }
    final source = await showModalBottomSheet<ImageSource>(
      context: context,
      showDragHandle: true,
      builder: (sheetContext) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: const Icon(Icons.photo_library_outlined),
                title: const Text('从相册选择'),
                onTap: () =>
                    Navigator.of(sheetContext).pop(ImageSource.gallery),
              ),
              ListTile(
                leading: const Icon(Icons.photo_camera_outlined),
                title: const Text('拍照'),
                onTap: () => Navigator.of(sheetContext).pop(ImageSource.camera),
              ),
            ],
          ),
        );
      },
    );
    if (source == null || !mounted) {
      return;
    }

    setState(() {
      _pickingAvatar = true;
    });
    try {
      final picked = await _imagePicker.pickImage(
        source: source,
        maxWidth: 640,
        maxHeight: 640,
        imageQuality: 88,
      );
      if (picked == null) {
        return;
      }
      final path = await AvatarStore.save(widget.userId, owner, picked.path);
      if (!mounted) {
        return;
      }
      setState(() {
        if (owner == AvatarOwner.user) {
          _myAvatarPath = path;
        } else {
          _agentAvatarPath = path;
        }
      });
      await widget.onAvatarsChanged();
    } catch (error) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('头像更新失败：$error')));
    } finally {
      if (mounted) {
        setState(() {
          _pickingAvatar = false;
        });
      }
    }
  }

  Future<void> _resetAvatar(AvatarOwner owner) async {
    await AvatarStore.reset(widget.userId, owner);
    if (!mounted) {
      return;
    }
    setState(() {
      if (owner == AvatarOwner.user) {
        _myAvatarPath = '';
      } else {
        _agentAvatarPath = '';
      }
    });
    await widget.onAvatarsChanged();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('设置')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _SettingsSection(
            title: '头像',
            children: [
              _AvatarSettingTile(
                title: '我的头像',
                subtitle: '显示在你的消息右侧',
                imagePath: _myAvatarPath,
                fallbackLabel: '我',
                isUser: true,
                onPick: () => _pickAvatar(AvatarOwner.user),
                onReset: _myAvatarPath.isEmpty
                    ? null
                    : () => _resetAvatar(AvatarOwner.user),
              ),
              const Divider(height: 20),
              _AvatarSettingTile(
                title: 'AIAgent 头像',
                subtitle: '显示在回复左侧和顶部会话栏',
                imagePath: _agentAvatarPath,
                fallbackLabel: '绫',
                isUser: false,
                onPick: () => _pickAvatar(AvatarOwner.agent),
                onReset: _agentAvatarPath.isEmpty
                    ? null
                    : () => _resetAvatar(AvatarOwner.agent),
              ),
            ],
          ),
          const SizedBox(height: 16),
          _SettingsSection(
            title: '账号',
            children: [
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.person_outline),
                title: const Text('个人资料'),
                subtitle: Text(widget.username),
                trailing: const Icon(Icons.chevron_right),
                onTap: widget.onOpenProfile,
              ),
              const Divider(height: 20),
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.logout),
                title: const Text('退出登录'),
                trailing: _loggingOut
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.chevron_right),
                onTap: _loggingOut ? null : _confirmLogout,
              ),
            ],
          ),
          const SizedBox(height: 16),
          _SettingsSection(
            title: '服务器',
            children: [
              TextField(
                controller: _apiBaseUrlController,
                keyboardType: TextInputType.url,
                decoration: const InputDecoration(
                  labelText: 'API 地址',
                  hintText: 'https://api.example.com',
                  prefixIcon: Icon(Icons.dns_outlined),
                ),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: FilledButton.icon(
                      onPressed: _saving ? null : _saveApiBaseUrl,
                      icon: _saving
                          ? const SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(Icons.save_outlined),
                      label: const Text('保存'),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: _checking ? null : _checkHealth,
                      icon: _checking
                          ? const SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(Icons.cloud_done_outlined),
                      label: const Text('检查'),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              _InfoTile(
                icon: Icons.info_outline,
                title: '连接状态',
                value: widget.statusText,
              ),
            ],
          ),
          const SizedBox(height: 16),
          _SettingsSection(
            title: '聊天',
            children: [
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                secondary: const Icon(Icons.volume_up_outlined),
                title: const Text('自动播放语音'),
                subtitle: const Text('回复后自动播放语音'),
                value: _autoPlayVoice,
                onChanged: _setAutoPlayVoice,
              ),
              const Divider(height: 20),
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.bookmark_border),
                title: const Text('查看记忆'),
                subtitle: const Text('查看已写入的长期记忆'),
                trailing: const Icon(Icons.chevron_right),
                onTap: widget.onOpenMemory,
              ),
              const Divider(height: 20),
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.delete_outline),
                title: const Text('清空聊天记录'),
                subtitle: const Text('只清空本机保存的历史消息'),
                trailing: _clearing
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.chevron_right),
                onTap: _clearing ? null : _confirmClearHistory,
              ),
            ],
          ),
          const SizedBox(height: 16),
          _SettingsSection(
            title: '应用',
            children: [
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.info_outline),
                title: const Text('关于'),
                subtitle: const Text('版本、连接信息和隐私提示'),
                trailing: const Icon(Icons.chevron_right),
                onTap: widget.onOpenAbout,
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _AvatarSettingTile extends StatelessWidget {
  const _AvatarSettingTile({
    required this.title,
    required this.subtitle,
    required this.imagePath,
    required this.fallbackLabel,
    required this.isUser,
    required this.onPick,
    this.onReset,
  });

  final String title;
  final String subtitle;
  final String imagePath;
  final String fallbackLabel;
  final bool isUser;
  final VoidCallback onPick;
  final VoidCallback? onReset;

  @override
  Widget build(BuildContext context) {
    final hasImage = imagePath.isNotEmpty && File(imagePath).existsSync();
    return Row(
      children: [
        Container(
          width: 52,
          height: 52,
          alignment: Alignment.center,
          clipBehavior: Clip.antiAlias,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: isUser ? const Color(0xFF5B8CFF) : null,
            gradient: isUser
                ? null
                : const LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [Color(0xFFFF9A8F), Color(0xFFC74444)],
                  ),
          ),
          child: hasImage
              ? Image.file(
                  File(imagePath),
                  width: 52,
                  height: 52,
                  fit: BoxFit.cover,
                  errorBuilder: (context, error, stackTrace) {
                    return Text(
                      fallbackLabel,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 20,
                        fontWeight: FontWeight.w600,
                      ),
                    );
                  },
                )
              : Text(
                  fallbackLabel,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 20,
                    fontWeight: FontWeight.w600,
                  ),
                ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: const TextStyle(fontWeight: FontWeight.w600)),
              const SizedBox(height: 2),
              Text(
                subtitle,
                style: const TextStyle(fontSize: 12, color: Colors.black54),
              ),
            ],
          ),
        ),
        TextButton(onPressed: onPick, child: const Text('更换')),
        if (onReset != null)
          IconButton(
            tooltip: '恢复默认',
            onPressed: onReset,
            icon: const Icon(Icons.restart_alt),
          ),
      ],
    );
  }
}

class _SettingsSection extends StatelessWidget {
  const _SettingsSection({required this.title, required this.children});

  final String title;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
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
            const SizedBox(height: 12),
            ...children,
          ],
        ),
      ),
    );
  }
}

class _InfoTile extends StatelessWidget {
  const _InfoTile({
    required this.icon,
    required this.title,
    required this.value,
  });

  final IconData icon;
  final String title;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Row(
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
              Text(
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
    );
  }
}
