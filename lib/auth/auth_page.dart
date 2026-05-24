import 'package:flutter/material.dart';

import '../identity/user_identity.dart';

class AuthPage extends StatefulWidget {
  const AuthPage({super.key, required this.onLogin, required this.onRegister});

  final Future<UserIdentity> Function({
    required String username,
    required String password,
  })
  onLogin;
  final Future<UserIdentity> Function({
    required String username,
    required String password,
    required String inviteCode,
  })
  onRegister;

  @override
  State<AuthPage> createState() => _AuthPageState();
}

class _AuthPageState extends State<AuthPage> {
  final TextEditingController _usernameController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  final TextEditingController _inviteCodeController = TextEditingController();

  bool _registerMode = false;
  bool _submitting = false;
  bool _obscurePassword = true;
  String _errorText = '';

  @override
  void dispose() {
    _usernameController.dispose();
    _passwordController.dispose();
    _inviteCodeController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_submitting) {
      return;
    }

    setState(() {
      _submitting = true;
      _errorText = '';
    });

    try {
      if (_registerMode) {
        await widget.onRegister(
          username: _usernameController.text.trim(),
          password: _passwordController.text,
          inviteCode: _inviteCodeController.text.trim(),
        );
      } else {
        await widget.onLogin(
          username: _usernameController.text.trim(),
          password: _passwordController.text,
        );
      }
    } catch (error) {
      if (!mounted) {
        return;
      }
      setState(() {
        _errorText = error.toString().replaceFirst('Exception: ', '');
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
      backgroundColor: const Color(0xFFEAF2EE),
      body: Stack(
        fit: StackFit.expand,
        children: [
          const _GlassAuthBackdrop(),
          SafeArea(
            child: Center(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(24),
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 420),
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.34),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: Colors.white.withValues(alpha: 0.82),
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.white.withValues(alpha: 0.30),
                          blurRadius: 18,
                          spreadRadius: 1,
                        ),
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.05),
                          blurRadius: 30,
                          offset: const Offset(0, 16),
                        ),
                      ],
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(22),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Text(
                            _registerMode ? '创建账号' : '欢迎回来',
                            style: Theme.of(context).textTheme.headlineSmall
                                ?.copyWith(fontWeight: FontWeight.w800),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            _registerMode
                                ? '目前只向持有邀请码的用户开放。'
                                : '登录后进入 AIAgent。',
                            style: const TextStyle(color: Colors.black54),
                          ),
                          const SizedBox(height: 22),
                          TextField(
                            controller: _usernameController,
                            textInputAction: TextInputAction.next,
                            decoration: const InputDecoration(
                              labelText: '用户名',
                              prefixIcon: Icon(Icons.person_outline),
                            ),
                          ),
                          const SizedBox(height: 12),
                          TextField(
                            controller: _passwordController,
                            obscureText: _obscurePassword,
                            textInputAction: _registerMode
                                ? TextInputAction.next
                                : TextInputAction.done,
                            onSubmitted: (_) {
                              if (!_registerMode) {
                                _submit();
                              }
                            },
                            decoration: InputDecoration(
                              labelText: '密码',
                              prefixIcon: const Icon(Icons.lock_outline),
                              suffixIcon: IconButton(
                                tooltip: _obscurePassword ? '显示密码' : '隐藏密码',
                                onPressed: () {
                                  setState(() {
                                    _obscurePassword = !_obscurePassword;
                                  });
                                },
                                icon: Icon(
                                  _obscurePassword
                                      ? Icons.visibility_outlined
                                      : Icons.visibility_off_outlined,
                                ),
                              ),
                            ),
                          ),
                          if (_registerMode) ...[
                            const SizedBox(height: 12),
                            TextField(
                              controller: _inviteCodeController,
                              textInputAction: TextInputAction.done,
                              onSubmitted: (_) => _submit(),
                              decoration: const InputDecoration(
                                labelText: '邀请码',
                                prefixIcon: Icon(Icons.key_outlined),
                              ),
                            ),
                          ],
                          if (_errorText.isNotEmpty) ...[
                            const SizedBox(height: 12),
                            Text(
                              _errorText,
                              style: TextStyle(
                                color: Theme.of(context).colorScheme.error,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                          const SizedBox(height: 22),
                          FilledButton.icon(
                            onPressed: _submitting ? null : _submit,
                            icon: _submitting
                                ? const SizedBox(
                                    width: 16,
                                    height: 16,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                    ),
                                  )
                                : Icon(
                                    _registerMode
                                        ? Icons.person_add_alt
                                        : Icons.login,
                                  ),
                            label: Text(_registerMode ? '注册并进入' : '登录'),
                          ),
                          const SizedBox(height: 10),
                          TextButton(
                            onPressed: _submitting
                                ? null
                                : () {
                                    setState(() {
                                      _registerMode = !_registerMode;
                                      _errorText = '';
                                    });
                                  },
                            child: Text(
                              _registerMode ? '已有账号，去登录' : '没有账号，先注册',
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _GlassAuthBackdrop extends StatelessWidget {
  const _GlassAuthBackdrop();

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: [
        const ColoredBox(color: Color(0xFFEAF2EE)),
        Align(
          alignment: Alignment.bottomCenter,
          child: Image.asset(
            'assets/live2d_web/fallback_yzl.png',
            fit: BoxFit.contain,
            height: MediaQuery.sizeOf(context).height * 0.52,
            opacity: const AlwaysStoppedAnimation(0.07),
            errorBuilder: (context, error, stackTrace) {
              return const SizedBox.shrink();
            },
          ),
        ),
        ColoredBox(color: Colors.white.withValues(alpha: 0.30)),
      ],
    );
  }
}
