import 'dart:async';

import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/foundation.dart';

class AudioPlaybackService {
  AudioPlaybackService() {
    _player.onPlayerStateChanged.listen((state) {
      final speaking = state == PlayerState.playing;
      _speakingController.add(speaking);
    });

    _player.onPlayerComplete.listen((_) {
      _speakingController.add(false);
      position.value = Duration.zero;
    });

    _player.onPositionChanged.listen((value) {
      position.value = value;
    });

    _player.onDurationChanged.listen((value) {
      duration.value = value;
    });
  }

  final AudioPlayer _player = AudioPlayer();
  final StreamController<bool> _speakingController =
      StreamController<bool>.broadcast();
  final ValueNotifier<Duration> position = ValueNotifier(Duration.zero);
  final ValueNotifier<Duration> duration = ValueNotifier(Duration.zero);

  Stream<bool> get speakingStream => _speakingController.stream;

  Future<void> playUrl(String url) async {
    final normalizedUrl = url.trim();

    if (normalizedUrl.isEmpty) {
      return;
    }

    position.value = Duration.zero;
    duration.value = Duration.zero;
    await stop();
    await _player.play(UrlSource(normalizedUrl));
  }

  Future<void> stop() async {
    await _player.stop();
    position.value = Duration.zero;
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
    position.dispose();
    duration.dispose();
  }
}
