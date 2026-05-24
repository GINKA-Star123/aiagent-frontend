import 'dart:convert';

import 'package:webview_flutter/webview_flutter.dart';

import 'live2d_payload.dart';

class Live2DBridge {
  Live2DBridge({required WebViewController controller})
    : _controller = controller;

  final WebViewController _controller;

  Future<void> applyPayload(Live2DPayload payload) async {
    final jsonText = jsonEncode(payload.toJson());
    final script = 'window.AIAgentLive2D.applyPayload($jsonText);';
    await _controller.runJavaScript(script);
  }

  Future<void> setStatus(String text) async {
    final jsonText = jsonEncode(text);
    final script = 'window.AIAgentLive2D.setStatus($jsonText);';
    await _controller.runJavaScript(script);
  }

  Future<void> setSpeaking(bool speaking) async {
    final script =
        'window.AIAgentLive2D.setSpeaking(${speaking ? "true" : "false"});';
    await _controller.runJavaScript(script);
  }
}
