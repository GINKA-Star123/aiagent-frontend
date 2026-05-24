import 'dart:async';

import 'package:flutter/material.dart';

import '../api/api_client.dart';
import '../api/api_models.dart';
import '../audio/audio_playback_service.dart';
import '../audio/recorder_service.dart';
import '../identity/user_identity.dart';
import '../live2d/live2d_payload.dart';

class VoiceCallPage extends StatefulWidget {
  const VoiceCallPage({
    super.key,
    required this.apiClient,
    required this.identity,
    required this.audioPlaybackService,
    required this.recorderService,
    required this.onAssistantResponse,
    required this.onLive2DChanged,
    required this.onSpeakingChanged,
  });

  final ApiClient apiClient;
  final UserIdentity identity;
  final AudioPlaybackService audioPlaybackService;
  final RecorderService recorderService;
  final Future<void> Function(VoiceCallTurnResponse response)
  onAssistantResponse;
  final ValueChanged<Live2DPayload?> onLive2DChanged;
  final Future<void> Function(bool speaking) onSpeakingChanged;

  @override
  State<VoiceCallPage> createState() => _VoiceCallPageState();
}

class _VoiceCallPageState extends State<VoiceCallPage> {
  static const Duration _turnRecordDuration = Duration(milliseconds: 2800);
  static const Duration _turnGap = Duration(milliseconds: 450);

  String _callId = '';
  String _statusText = '准备通话';
  String _lastTranscript = '';
  String _lastReply = '';
  bool _active = false;
  bool _processing = false;
  bool _muted = false;
  int _turnCount = 0;

  @override
  void dispose() {
    _stopCall(sendEnd: true);
    super.dispose();
  }

  Future<void> _startCall() async {
    if (_active || _processing) {
      return;
    }

    setState(() {
      _processing = true;
      _statusText = '正在建立通话...';
    });

    try {
      final response = await widget.apiClient.startVoiceCall(
        userId: widget.identity.userId,
        username: widget.identity.username,
      );
      if (!mounted) {
        return;
      }
      setState(() {
        _callId = response['call_id']?.toString() ?? '';
        _active = true;
        _processing = false;
        _statusText = '通话中';
      });
      unawaited(_callLoop());
    } catch (error) {
      if (!mounted) {
        return;
      }
      setState(() {
        _processing = false;
        _statusText = '通话建立失败：$error';
      });
    }
  }

  Future<void> _stopCall({bool sendEnd = false}) async {
    final callId = _callId;
    _active = false;

    try {
      await widget.recorderService.cancel();
    } catch (_) {}

    await widget.audioPlaybackService.stop();
    await widget.onSpeakingChanged(false);

    if (sendEnd && callId.isNotEmpty) {
      try {
        await widget.apiClient.endVoiceCall(callId: callId);
      } catch (_) {}
    }

    if (mounted) {
      setState(() {
        _processing = false;
        _statusText = '通话已结束';
      });
    }
  }

  Future<void> _callLoop() async {
    while (mounted && _active) {
      if (_muted) {
        setState(() {
          _statusText = '麦克风已静音';
        });
        await Future<void>.delayed(_turnGap);
        continue;
      }

      await _runOneTurn();
      await Future<void>.delayed(_turnGap);
    }
  }

  Future<void> _runOneTurn() async {
    if (_callId.isEmpty || _processing || !_active) {
      return;
    }

    setState(() {
      _processing = true;
      _statusText = '正在听你说话...';
    });

    try {
      await widget.audioPlaybackService.stop();
      await widget.onSpeakingChanged(false);

      await widget.recorderService.start();
      await Future<void>.delayed(_turnRecordDuration);
      final audioPath = await widget.recorderService.stop();

      if (!mounted || !_active) {
        return;
      }

      setState(() {
        _statusText = '正在理解...';
      });

      final response = await widget.apiClient.sendVoiceCallTurn(
        callId: _callId,
        userId: widget.identity.userId,
        username: widget.identity.username,
        audioPath: audioPath,
      );

      await widget.onAssistantResponse(response);
      widget.onLive2DChanged(response.chat.live2d);

      final audioUrl = response.chat.audioUrl.isNotEmpty
          ? response.chat.audioUrl
          : response.chat.live2d?.character.mouth.audioUrl ?? '';
      if (audioUrl.isNotEmpty) {
        await widget.onSpeakingChanged(true);
        await widget.audioPlaybackService.playUrl(audioUrl);
      }

      if (!mounted) {
        return;
      }

      setState(() {
        _turnCount += 1;
        _lastTranscript = response.transcript;
        _lastReply = response.chat.reply;
        _statusText = '通话中';
      });
    } catch (error) {
      if (!mounted) {
        return;
      }
      setState(() {
        _statusText = '本轮失败：$error';
      });
      await Future<void>.delayed(const Duration(seconds: 1));
    } finally {
      if (mounted) {
        setState(() {
          _processing = false;
        });
      }
    }
  }

  void _toggleMute() {
    setState(() {
      _muted = !_muted;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFEAF2EE),
      body: SafeArea(
        child: Stack(
          fit: StackFit.expand,
          children: [
            const _VoiceCallBackdrop(),
            Padding(
              padding: const EdgeInsets.all(22),
              child: Column(
                children: [
                  Row(
                    children: [
                      IconButton(
                        tooltip: '返回',
                        onPressed: () => Navigator.of(context).pop(),
                        icon: const Icon(Icons.keyboard_arrow_down),
                        color: Colors.white,
                      ),
                      const SizedBox(width: 8),
                      const Expanded(
                        child: Text(
                          '实时语音通话',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 20,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const Spacer(),
                  DecoratedBox(
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: Colors.white.withValues(alpha: 0.12),
                      border: Border.all(
                        color: Colors.white.withValues(alpha: 0.22),
                      ),
                    ),
                    child: const Padding(
                      padding: EdgeInsets.all(42),
                      child: Icon(
                        Icons.graphic_eq,
                        size: 72,
                        color: Colors.white,
                      ),
                    ),
                  ),
                  const SizedBox(height: 28),
                  Text(
                    _statusText,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 22,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    _callId.isEmpty ? '未连接' : '已进行 $_turnCount 轮对话',
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.62),
                    ),
                  ),
                  const SizedBox(height: 24),
                  _CallTextPanel(
                    lastTranscript: _lastTranscript,
                    lastReply: _lastReply,
                  ),
                  const Spacer(),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      _CallButton(
                        tooltip: _muted ? '取消静音' : '静音',
                        color: Colors.white.withValues(alpha: 0.14),
                        icon: _muted ? Icons.mic_off : Icons.mic,
                        onPressed: _toggleMute,
                      ),
                      const SizedBox(width: 24),
                      _CallButton(
                        tooltip: _active ? '挂断' : '开始通话',
                        color: _active
                            ? const Color(0xFFD94C4C)
                            : const Color(0xFF3BA36A),
                        icon: _active ? Icons.call_end : Icons.call,
                        large: true,
                        onPressed: _active
                            ? () => _stopCall(sendEnd: true)
                            : _startCall,
                      ),
                      const SizedBox(width: 24),
                      _CallButton(
                        tooltip: '立刻进入下一轮',
                        color: Colors.white.withValues(alpha: 0.14),
                        icon: Icons.skip_next,
                        onPressed: _active && !_processing ? _runOneTurn : null,
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _VoiceCallBackdrop extends StatelessWidget {
  const _VoiceCallBackdrop();

  @override
  Widget build(BuildContext context) {
    return const DecoratedBox(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFFDDEDEA), Color(0xFFFFF8F2), Color(0xFFF3C8BD)],
        ),
      ),
    );
  }
}

class _CallTextPanel extends StatelessWidget {
  const _CallTextPanel({required this.lastTranscript, required this.lastReply});

  final String lastTranscript;
  final String lastReply;

  @override
  Widget build(BuildContext context) {
    if (lastTranscript.isEmpty && lastReply.isEmpty) {
      return Text(
        '点击绿色按钮开始。系统会像通话一样连续听取短句并回复。',
        textAlign: TextAlign.center,
        style: TextStyle(color: Colors.white.withValues(alpha: 0.68)),
      );
    }

    return DecoratedBox(
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.white.withValues(alpha: 0.16)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          children: [
            if (lastTranscript.isNotEmpty)
              _CallLine(label: '你', text: lastTranscript),
            if (lastReply.isNotEmpty) ...[
              const SizedBox(height: 10),
              _CallLine(label: 'AIAgent', text: lastReply),
            ],
          ],
        ),
      ),
    );
  }
}

class _CallLine extends StatelessWidget {
  const _CallLine({required this.label, required this.text});

  final String label;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 72,
          child: Text(
            label,
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w800,
            ),
          ),
        ),
        Expanded(
          child: Text(
            text,
            style: TextStyle(color: Colors.white.withValues(alpha: 0.82)),
          ),
        ),
      ],
    );
  }
}

class _CallButton extends StatelessWidget {
  const _CallButton({
    required this.tooltip,
    required this.color,
    required this.icon,
    required this.onPressed,
    this.large = false,
  });

  final String tooltip;
  final Color color;
  final IconData icon;
  final VoidCallback? onPressed;
  final bool large;

  @override
  Widget build(BuildContext context) {
    final size = large ? 76.0 : 56.0;
    return SizedBox(
      width: size,
      height: size,
      child: IconButton(
        tooltip: tooltip,
        onPressed: onPressed,
        style: IconButton.styleFrom(
          backgroundColor: color,
          disabledBackgroundColor: color.withValues(alpha: 0.34),
        ),
        icon: Icon(icon, color: Colors.white, size: large ? 34 : 26),
      ),
    );
  }
}
