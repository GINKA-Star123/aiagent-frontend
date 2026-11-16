import 'dart:io';

import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

enum AvatarOwner { user, agent }

/// 头像按 userId 隔离保存在应用目录，避免相册原图被清理后失效。
class AvatarStore {
  static const String _prefix = 'avatar.path.';

  static String _key(String userId, AvatarOwner owner) {
    return '$_prefix$userId.${owner.name}';
  }

  static Future<String> load(String userId, AvatarOwner owner) async {
    if (userId.isEmpty) {
      return '';
    }
    final prefs = await SharedPreferences.getInstance();
    final path = prefs.getString(_key(userId, owner)) ?? '';
    if (path.isEmpty) {
      return '';
    }
    if (!File(path).existsSync()) {
      await prefs.remove(_key(userId, owner));
      return '';
    }
    return path;
  }

  static Future<String> save(
    String userId,
    AvatarOwner owner,
    String sourcePath,
  ) async {
    if (userId.isEmpty || sourcePath.isEmpty) {
      return '';
    }
    final support = await getApplicationSupportDirectory();
    final avatarDir = Directory('${support.path}/avatars');
    if (!avatarDir.existsSync()) {
      await avatarDir.create(recursive: true);
    }

    final safeUser = userId.replaceAll(RegExp(r'[^A-Za-z0-9_-]'), '_');
    final stamp = DateTime.now().millisecondsSinceEpoch;
    final destination = File(
      '${avatarDir.path}/avatar_${safeUser}_${owner.name}_$stamp${_extensionFor(sourcePath)}',
    );
    await File(sourcePath).copy(destination.path);

    final prefs = await SharedPreferences.getInstance();
    final previous = prefs.getString(_key(userId, owner)) ?? '';
    await prefs.setString(_key(userId, owner), destination.path);
    if (previous.isNotEmpty && previous != destination.path) {
      final old = File(previous);
      if (old.existsSync()) {
        try {
          await old.delete();
        } catch (_) {
          // 旧文件删不掉不影响新头像。
        }
      }
    }
    return destination.path;
  }

  static Future<void> reset(String userId, AvatarOwner owner) async {
    if (userId.isEmpty) {
      return;
    }
    final prefs = await SharedPreferences.getInstance();
    final previous = prefs.getString(_key(userId, owner)) ?? '';
    await prefs.remove(_key(userId, owner));
    if (previous.isNotEmpty) {
      final file = File(previous);
      if (file.existsSync()) {
        try {
          await file.delete();
        } catch (_) {
          // 文件被占用时忽略。
        }
      }
    }
  }

  static String _extensionFor(String path) {
    final lower = path.toLowerCase();
    for (final extension in const ['.jpg', '.jpeg', '.png', '.webp']) {
      if (lower.endsWith(extension)) {
        return extension;
      }
    }
    return '.img';
  }
}
