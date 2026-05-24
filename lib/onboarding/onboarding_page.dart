import 'package:flutter/material.dart';

class OnboardingPage extends StatefulWidget {
  const OnboardingPage({
    super.key,
    required this.initialApiBaseUrl,
    required this.onComplete,
  });

  final String initialApiBaseUrl;
  final Future<void> Function(String apiBaseUrl) onComplete;

  @override
  State<OnboardingPage> createState() => _OnboardingPageState();
}

class _OnboardingPageState extends State<OnboardingPage> {
  late final TextEditingController _apiBaseUrlController;

  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _apiBaseUrlController = TextEditingController(
      text: widget.initialApiBaseUrl,
    );
  }

  @override
  void dispose() {
    _apiBaseUrlController.dispose();
    super.dispose();
  }

  Future<void> _complete() async {
    final apiBaseUrl = _apiBaseUrlController.text.trim();
    if (apiBaseUrl.isEmpty || _saving) {
      return;
    }

    setState(() {
      _saving = true;
    });

    try {
      await widget.onComplete(apiBaseUrl);
    } finally {
      if (mounted) {
        setState(() {
          _saving = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(24),
          children: [
            const SizedBox(height: 24),
            const Icon(Icons.auto_awesome, size: 56, color: Color(0xFFC74444)),
            const SizedBox(height: 18),
            Text(
              '欢迎回来',
              textAlign: TextAlign.center,
              style: Theme.of(
                context,
              ).textTheme.headlineMedium?.copyWith(fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 8),
            const Text(
              '先连接你的 AIAgent 后端，然后就可以和阿绫聊天了。',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.black54),
            ),
            const SizedBox(height: 32),
            TextField(
              controller: _apiBaseUrlController,
              keyboardType: TextInputType.url,
              decoration: const InputDecoration(
                labelText: '后端 API 地址',
                hintText: 'http://192.168.0.177:8000',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            const Text(
              '手机真机调试时，请填写电脑在同一 Wi-Fi 下的局域网 IP，不要填 127.0.0.1。',
              style: TextStyle(fontSize: 12, color: Colors.black54),
            ),
            const SizedBox(height: 28),
            FilledButton.icon(
              onPressed: _saving ? null : _complete,
              icon: _saving
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.arrow_forward),
              label: const Text('开始使用'),
            ),
          ],
        ),
      ),
    );
  }
}
