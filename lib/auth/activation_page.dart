import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class ActivationPage extends StatefulWidget {
  const ActivationPage({
    super.key,
    required this.onActivated,
    this.initialCode = '',
    this.errorText = '',
  });

  final Future<void> Function(String code) onActivated;
  final String initialCode;
  final String errorText;

  @override
  State<ActivationPage> createState() => _ActivationPageState();
}

class _ActivationPageState extends State<ActivationPage> {
  late final TextEditingController _controller;
  bool _submitting = false;
  String _errorText = '';

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.initialCode);
    _errorText = widget.errorText;
  }

  @override
  void didUpdateWidget(covariant ActivationPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.errorText.isNotEmpty &&
        widget.errorText != oldWidget.errorText) {
      _errorText = widget.errorText;
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _paste() async {
    final data = await Clipboard.getData(Clipboard.kTextPlain);
    final text = data?.text?.trim() ?? '';
    if (text.isEmpty) {
      setState(() {
        _errorText = '剪贴板里没有激活码';
      });
      return;
    }
    setState(() {
      _controller.text = text;
      _errorText = '';
    });
  }

  Future<void> _submit() async {
    final code = _controller.text.trim();
    if (code.isEmpty) {
      setState(() {
        _errorText = '请先粘贴激活码';
      });
      return;
    }
    setState(() {
      _submitting = true;
      _errorText = '';
    });
    try {
      await widget.onActivated(code);
    } catch (error) {
      if (!mounted) {
        return;
      }
      setState(() {
        _errorText = error.toString();
      });
    } finally {
      if (mounted) {
        setState(() {
          _submitting = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF3F7F4),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 480),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Icon(Icons.lock_outline, size: 40, color: Color(0xFF2F6F5E)),
                  const SizedBox(height: 16),
                  const Text(
                    '激活设备',
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 24, fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    '粘贴负责人发给你的激活码即可开始使用。\n无需配置模型或服务地址。',
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 13, color: Colors.black54, height: 1.5),
                  ),
                  const SizedBox(height: 24),
                  TextField(
                    controller: _controller,
                    minLines: 3,
                    maxLines: 5,
                    decoration: const InputDecoration(
                      labelText: '激活码',
                      hintText: 'eyJ2IjoxLCJiIjoiaHR0cHM6...',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  if (_errorText.isNotEmpty) ...[
                    const SizedBox(height: 12),
                    Text(
                      _errorText,
                      style: const TextStyle(color: Color(0xFFB3261E), fontSize: 13),
                    ),
                  ],
                  const SizedBox(height: 20),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: _submitting ? null : _paste,
                          icon: const Icon(Icons.content_paste),
                          label: const Text('粘贴'),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: FilledButton(
                          onPressed: _submitting ? null : _submit,
                          child: _submitting
                              ? const SizedBox(
                                  width: 18,
                                  height: 18,
                                  child: CircularProgressIndicator(strokeWidth: 2),
                                )
                              : const Text('激活并进入'),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
