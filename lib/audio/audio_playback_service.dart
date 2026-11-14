import 'dart:async';

import 'package:audioplayers/audioplayers.dart';

class AudioPlaybackService {
  AudioPlaybackService() {
    _player.onPlayerStateChanged.listen((state) {
      final speaking = state == PlayerState.playing;
      _speakingController.add(speaking);
    });

    _player.onPlayerComplete.listen((_) {
      _speakingController.add(false);
    });
  }

  final AudioPlayer _player = AudioPlayer();
  final StreamController<bool> _speakingController =
      StreamController<bool>.broadcast();

  Stream<bool> get speakingStream => _speakingController.stream;

  Future<void> playUrl(String url) async {
    final normalizedUrl = url.trim();

    if (normalizedUrl.isEmpty) {
      return;
    }

    await stop();
    await _player.play(UrlSource(normalizedUrl));
  }

  Future<void> stop() async {
    await _player.stop();
    _speakingController.add(false);
  }

  Future<void> pause() async {
    await _player.pause();
    _speakingController.add(false);
  }

  Future<void> resume() async {
    await _player.resume();
  }

  Future<void> dispose() async {
    await _player.dispose();
    await _speakingController.close();
  }
}
