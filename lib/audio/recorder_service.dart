import 'dart:io';

import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:record/record.dart';

class RecorderService {
  RecorderService();

  final AudioRecorder _recorder = AudioRecorder();

  bool _recording = false;
  String _currentPath = '';

  bool get isRecording => _recording;

  Future<String> start() async {
    if (_recording) {
      return _currentPath;
    }

    final permission = await Permission.microphone.request();
    if (!permission.isGranted) {
      throw RecorderException('没有麦克风权限。');
    }

    final directory = await getTemporaryDirectory();
    final path =
        '${directory.path}/voice_${DateTime.now().millisecondsSinceEpoch}.m4a';

    final config = RecordConfig(
      encoder: AudioEncoder.aacLc,
      bitRate: 128000,
      sampleRate: 16000,
      numChannels: 1,
    );

    await _recorder.start(config, path: path);

    _recording = true;
    _currentPath = path;
    return path;
  }

  Future<String> stop() async {
    if (!_recording) {
      return _currentPath;
    }

    final path = await _recorder.stop();

    _recording = false;
    _currentPath = path ?? _currentPath;

    if (_currentPath.isEmpty || !File(_currentPath).existsSync()) {
      throw RecorderException('录音文件不存在。');
    }

    return _currentPath;
  }

  Future<void> cancel() async {
    if (_recording) {
      await _recorder.stop();
    }

    _recording = false;

    if (_currentPath.isNotEmpty) {
      final file = File(_currentPath);
      if (file.existsSync()) {
        await file.delete();
      }
    }

    _currentPath = '';
  }

  Future<void> dispose() async {
    await _recorder.dispose();
  }
}

class RecorderException implements Exception {
  RecorderException(this.message);

  final String message;

  @override
  String toString() {
    return message;
  }
}
