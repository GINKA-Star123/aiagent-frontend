import 'package:flutter/material.dart';

import '../identity/user_identity.dart';

class AuthPage extends StatefulWidget {
  const AuthPage({
    super.key,
    required this.onLogin,
    required this.onRegister,
    this.initialApiBaseUrl = '',
  });

  final Future<UserIdentity> Function({
    required String identifier,
    required String password,
    required String baseUrl,
  })
  onLogin;
  final Future<UserIdentity> Function({
    required String email,
    required String username,
    required String password,
    required String baseUrl,
  })
  onRegister;
  final String initialApiBaseUrl;

  @override
  State<AuthPage> createState() => _AuthPageState();
}

class _AuthPageState extends State<AuthPage> {
  late final TextEditingController _identifierController;
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _usernameController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  final TextEditingController _confirmController = TextEditingController();
  late final TextEditingController _serverController;

  bool _registerMode = false;
  bool _submitting = false;
  bool _obscurePassword = true;
  String _errorText = '';

  static final RegExp _emailPattern = RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$');

  @override
  void initState() {
    super.initState();
    _identifierController = TextEditingController();
    _serverController = TextEditingController(text: widget.initialApiBaseUrl);
  }

  @override
  void dispose() {
    _identifierController.dispose();
    _emailController.dispose();
    _usernameController.dispose();
    _passwordController.dispose();
    _confirmController.dispose();
    _serverController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_submitting) {
      return;
    }
    final baseUrl = _serverController.text.trim();
    if (baseUrl.isEmpty) {
      setState(() {
        _errorText = '请填写服务器地址。';
      });
      return;
    }

    final password = _passwordController.text;
    if (password.length < 6) {
      setState(() {
        _errorText = '密码至少需要 6 个字符。';
      });
      return;
    }

    if (_registerMode) {
      final email = _emailController.text.trim().toLowerCase();
      final username = _usernameController.text.trim();
      if (!_emailPattern.hasMatch(email)) {
        setState(() {
          _errorText = '请输入有效的邮箱地址。';
        });
        return;
      }
      if (username.length < 2 || username.length > 32) {
        setState(() {
          _errorText = '用户名需为 2–32 个字符。';
        });
        return;
      }
      if (password != _confirmController.text) {
        setState(() {
          _errorText = '两次输入的密码不一致。';
        });
        return;
      }
      setState(() {
        _submitting = true;
        _errorText = '';
      });
      try {
        await widget.onRegister(
          email: email,
          username: username,
          password: password,
          baseUrl: baseUrl,
        );
      } catch (error) {
        if (!mounted) {
          return;
        }
        setState(() {
          _errorText = _friendlyError(error);
        });
      } finally {
        if (mounted) {
          setState(() {
            _submitting = false;
          });
        }
      }
      return;
    }

    final identifier = _identifierController.text.trim();
    if (identifier.isEmpty) {
      setState(() {
        _errorText = '请输入邮箱或用户名。';
      });
      return;
    }
    setState(() {
      _submitting = true;
      _errorText = '';
    });
    try {
      await widget.onLogin(
        identifier: identifier,
        password: password,
        baseUrl: baseUrl,
      );
    } catch (error) {
      if (!mounted) {
        return;
      }
      setState(() {
        _errorText = _friendlyError(error);
      });
    } finally {
      if (mounted) {
        setState(() {
          _submitting = false;
        });
      }
    }
  }

  String _friendlyError(Object error) {
    final text = error.toString();
    if (text.startsWith('Exception: ')) {
      return text.substring('Exception: '.length);
    }
    return text;
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
                      color: Colors.white.withValues(alpha: 0.36),
                      borderRadius: BorderRadius.circular(10),
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
                            _registerMode ? '创建账号' : '登录 AIAgent',
                            style: Theme.of(context).textTheme.headlineSmall
                                ?.copyWith(fontWeight: FontWeight.w800),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            _registerMode
                                ? '邮箱 + 用户名 + 密码。服务端账号仍使用用户名。'
                                : '使用邮箱或用户名登录。',
                            style: const TextStyle(color: Colors.black54),
                          ),
                          const SizedBox(height: 20),
                          if (_registerMode) ...[
                            TextField(
                              controller: _emailController,
                              keyboardType: TextInputType.emailAddress,
                              autocorrect: false,
                              textInputAction: TextInputAction.next,
                              decoration: const InputDecoration(
                                labelText: '邮箱',
                                helperText: '邮箱仅保存在本机，用于本机登录别名。',
                                prefixIcon: Icon(Icons.mail_outline),
                              ),
                            ),
                            const SizedBox(height: 12),
                            TextField(
                              controller: _usernameController,
                              textInputAction: TextInputAction.next,
                              decoration: const InputDecoration(
                                labelText: '用户名',
                                helperText: '2–32 个字符；服务端唯一。',
                                prefixIcon: Icon(Icons.person_outline),
                              ),
                            ),
                          ] else
                            TextField(
                              controller: _identifierController,
                              textInputAction: TextInputAction.next,
                              decoration: const InputDecoration(
                                labelText: '邮箱或用户名',
                                helperText: '邮箱登录需在本机注册过该邮箱。',
                                prefixIcon: Icon(Icons.account_circle_outlined),
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
                              helperText: '至少 6 个字符。',
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
                              controller: _confirmController,
                              obscureText: _obscurePassword,
                              textInputAction: TextInputAction.next,
                              decoration: const InputDecoration(
                                labelText: '确认密码',
                                prefixIcon: Icon(Icons.lock_reset_outlined),
                              ),
                            ),
                          ],
                          const SizedBox(height: 12),
                          TextField(
                            controller: _serverController,
                            keyboardType: TextInputType.url,
                            autocorrect: false,
                            textInputAction: TextInputAction.done,
                            onSubmitted: (_) => _submit(),
                            decoration: const InputDecoration(
                              labelText: '服务器地址',
                              hintText: 'https://api.example.com',
                              helperText: '留空无效；登录成功后保存到设置。',
                              prefixIcon: Icon(Icons.dns_outlined),
                            ),
                          ),
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
                          const SizedBox(height: 20),
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
                          const SizedBox(height: 8),
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
        ColoredBox(color: Colors.white.withValues(alpha: 0.30)),
      ],
    );
  }
}
