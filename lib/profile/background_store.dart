import 'dart:io';

import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// 聊天背景按 userId 隔离保存在应用目录。
class BackgroundStore {
  static const String _prefix = 'chat.background.path.';

  static String _key(String userId) {
    return _prefix + userId;
  }

  static Future<String> load(String userId) async {
    if (userId.isEmpty) {
      return '';
    }
    final prefs = await SharedPreferences.getInstance();
    final path = prefs.getString(_key(userId)) ?? '';
    if (path.isEmpty) {
      return '';
    }
    if (!File(path).existsSync()) {
      await prefs.remove(_key(userId));
      return '';
    }
    return path;
  }

  static Future<String> save(String userId, String sourcePath) async {
    if (userId.isEmpty || sourcePath.isEmpty) {
      return '';
    }
    final support = await getApplicationSupportDirectory();
    final directory = Directory('${support.path}/backgrounds');
    if (!directory.existsSync()) {
      await directory.create(recursive: true);
    }

    final safeUser = userId.replaceAll(RegExp(r'[^A-Za-z0-9_-]'), '_');
    final stamp = DateTime.now().millisecondsSinceEpoch;
    final destination = File(
      '${directory.path}/background_${safeUser}_$stamp${_extensionFor(sourcePath)}',
    );
    await File(sourcePath).copy(destination.path);

    final prefs = await SharedPreferences.getInstance();
    final previous = prefs.getString(_key(userId)) ?? '';
    await prefs.setString(_key(userId), destination.path);
    if (previous.isNotEmpty && previous != destination.path) {
      final old = File(previous);
      if (old.existsSync()) {
        try {
          await old.delete();
        } catch (_) {
          // 旧文件删不掉不影响新背景。
        }
      }
    }
    return destination.path;
  }

  static Future<void> reset(String userId) async {
    if (userId.isEmpty) {
      return;
    }
    final prefs = await SharedPreferences.getInstance();
    final previous = prefs.getString(_key(userId)) ?? '';
    await prefs.remove(_key(userId));
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
