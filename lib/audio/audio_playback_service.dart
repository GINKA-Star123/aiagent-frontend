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
      _completionController.add(null);
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
  final StreamController<void> _completionController =
      StreamController<void>.broadcast();
  final ValueNotifier<Duration> position = ValueNotifier(Duration.zero);
  final ValueNotifier<Duration> duration = ValueNotifier(Duration.zero);
  double _playbackRate = 1.0;

  double get playbackRate => _playbackRate;

  Stream<bool> get speakingStream => _speakingController.stream;
  Stream<void> get completionStream => _completionController.stream;

  Future<void> playUrl(String url) async {
    final normalizedUrl = url.trim();

    if (normalizedUrl.isEmpty) {
      return;
    }

    position.value = Duration.zero;
    duration.value = Duration.zero;
    await stop();
    await _player.play(UrlSource(normalizedUrl));
    try {
      await _player.setPlaybackRate(_playbackRate);
    } catch (_) {
      // 保持默认速率，避免影响播放。
    }
  }

  Future<void> stop() async {
    await _player.stop();
    position.value = Duration.zero;
    _speakingController.add(false);
  }

  Future<void> setPlaybackRate(double rate) async {
    _playbackRate = rate.clamp(1.0, 2.0).toDouble();
    try {
      await _player.setPlaybackRate(_playbackRate);
    } catch (_) {
      // 无音源时部分平台不允许设置速率，播放时会再次应用。
    }
  }

  Future<void> seek(Duration position) async {
    await _player.seek(position);
    this.position.value = position;
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
    await _completionController.close();
    position.dispose();
    duration.dispose();
  }
}
