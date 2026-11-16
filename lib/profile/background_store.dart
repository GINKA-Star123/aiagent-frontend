import 'dart:io';

import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// 聊天背景按 userId 隔离保存在应用目录。
class BackgroundStore {
  static const String _prefix = 'chat.background.path.';

  static const String _dimPrefix = 'chat.background.dim.';
  static const String _blurPrefix = 'chat.background.blur.';
  static const double defaultDim = 0.62;
  static const double defaultBlur = 0;

  static Future<double> loadDim(String userId) async {
    if (userId.isEmpty) {
      return defaultDim;
    }
    final prefs = await SharedPreferences.getInstance();
    return (prefs.getDouble(_dimPrefix + userId) ?? defaultDim).clamp(0.2, 0.9);
  }

  static Future<void> saveDim(String userId, double value) async {
    if (userId.isEmpty) {
      return;
    }
    final prefs = await SharedPreferences.getInstance();
    await prefs.setDouble(_dimPrefix + userId, value.clamp(0.2, 0.9));
  }

  static Future<double> loadBlur(String userId) async {
    if (userId.isEmpty) {
      return defaultBlur;
    }
    final prefs = await SharedPreferences.getInstance();
    return (prefs.getDouble(_blurPrefix + userId) ?? defaultBlur).clamp(0, 20);
  }

  static Future<void> saveBlur(String userId, double value) async {
    if (userId.isEmpty) {
      return;
    }
    final prefs = await SharedPreferences.getInstance();
    await prefs.setDouble(_blurPrefix + userId, value.clamp(0, 20));
  }

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
