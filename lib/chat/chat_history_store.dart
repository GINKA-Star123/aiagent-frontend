import 'dart:convert';
import 'dart:io';

import 'package:path_provider/path_provider.dart';

import 'chat_message.dart';

class ChatHistoryStore {
  static const String _fileName = 'chat_history.json';

  Future<List<ChatMessage>> load() async {
    final file = await _getHistoryFile();

    if (!await file.exists()) {
      return [];
    }

    final raw = await file.readAsString();
    if (raw.trim().isEmpty) {
      return [];
    }

    final json = jsonDecode(raw);
    if (json is! List) {
      return [];
    }

    return json
        .whereType<Map>()
        .map(
          (item) => ChatMessage.fromJson(
            item.map((key, dynamic value) => MapEntry(key.toString(), value)),
          ),
        )
        .toList();
  }

  Future<void> save(List<ChatMessage> messages) async {
    final file = await _getHistoryFile();
    final json = messages.map((message) => message.toJson()).toList();
    await file.writeAsString(const JsonEncoder.withIndent('  ').convert(json));
  }

  Future<void> clear() async {
    final file = await _getHistoryFile();
    if (await file.exists()) {
      await file.delete();
    }
  }

  Future<File> _getHistoryFile() async {
    final directory = await getApplicationDocumentsDirectory();
    return File('${directory.path}/$_fileName');
  }
}
