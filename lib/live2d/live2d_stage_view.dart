import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:webview_flutter/webview_flutter.dart';
import 'package:webview_flutter_android/webview_flutter_android.dart';

import 'live2d_bridge.dart';
import 'live2d_payload.dart';
import 'live2d_stage_empty.dart';

class Live2DStageView extends StatefulWidget {
  const Live2DStageView({
    super.key,
    required this.statusText,
    this.payload,
    this.onBridgeReady,
    this.expand = false,
  });

  final String statusText;
  final Live2DPayload? payload;
  final ValueChanged<Live2DBridge>? onBridgeReady;
  final bool expand;

  @override
  State<Live2DStageView> createState() => _Live2DStageViewState();
}

class _Live2DStageViewState extends State<Live2DStageView> {
  WebViewController? _controller;
  Live2DBridge? _bridge;

  bool _loaded = false;
  Live2DPayload? _lastPayload;

  bool get _supportsWebView {
    if (kIsWeb) {
      return false;
    }

    return defaultTargetPlatform == TargetPlatform.android ||
        defaultTargetPlatform == TargetPlatform.iOS;
  }

  @override
  void initState() {
    super.initState();

    if (!_supportsWebView) {
      return;
    }

    final controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setBackgroundColor(const Color(0x00000000))
      ..setNavigationDelegate(
        NavigationDelegate(
          onPageFinished: (_) async {
            _loaded = true;
            await _bridge?.setStatus(widget.statusText);
            await _applyPayloadIfNeeded(force: true);
          },
          onWebResourceError: (error) async {
            await _bridge?.setStatus(
              'Live2D resource failed: ${error.errorCode} ${error.description}',
            );
          },
        ),
      );

    unawaited(_configureAndLoad(controller));

    _controller = controller;
    _bridge = Live2DBridge(controller: controller);

    WidgetsBinding.instance.addPostFrameCallback((_) {
      final bridge = _bridge;
      if (bridge != null) {
        widget.onBridgeReady?.call(bridge);
      }
    });
  }

  Future<void> _configureAndLoad(WebViewController controller) async {
    final platformController = controller.platform;
    if (platformController is AndroidWebViewController) {
      await platformController.setAllowFileAccess(true);
      await platformController.setAllowContentAccess(true);
      await platformController.setMixedContentMode(
        MixedContentMode.alwaysAllow,
      );
      await platformController.setMediaPlaybackRequiresUserGesture(false);
      await platformController.setOnConsoleMessage((message) {
        debugPrint('Live2D WebView: ${message.message}');
      });
    }

    await controller.loadFlutterAsset('assets/live2d_web/index.html');
  }

  @override
  void didUpdateWidget(covariant Live2DStageView oldWidget) {
    super.didUpdateWidget(oldWidget);

    if (!_supportsWebView) {
      return;
    }

    if (oldWidget.statusText != widget.statusText && _loaded) {
      _bridge?.setStatus(widget.statusText);
    }

    if (oldWidget.payload != widget.payload) {
      _applyPayloadIfNeeded();
    }
  }

  Future<void> _applyPayloadIfNeeded({bool force = false}) async {
    final payload = widget.payload;
    final bridge = _bridge;

    if (!_loaded || payload == null || bridge == null) {
      return;
    }

    if (!force && identical(payload, _lastPayload)) {
      return;
    }

    _lastPayload = payload;
    await bridge.applyPayload(payload);
  }

  @override
  Widget build(BuildContext context) {
    final controller = _controller;

    return Container(
      height: widget.expand ? null : 420,
      width: double.infinity,
      margin: widget.expand
          ? EdgeInsets.zero
          : const EdgeInsets.fromLTRB(16, 12, 16, 8),
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(widget.expand ? 0 : 18),
        border: widget.expand
            ? null
            : Border.all(color: const Color(0xFFE2B7AA)),
        color: widget.expand ? Colors.transparent : const Color(0xFFFFF3EC),
      ),
      child: _supportsWebView && controller != null
          ? WebViewWidget(controller: controller)
          : Live2DStageEmpty(statusText: widget.statusText),
    );
  }
}
