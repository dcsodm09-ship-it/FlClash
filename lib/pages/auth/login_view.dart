import 'package:fl_clash/common/common.dart';
import 'package:fl_clash/enum/enum.dart';
import 'package:fl_clash/hgfast/models/error.dart';
import 'package:fl_clash/providers/providers.dart';
import 'package:fl_clash/widgets/widgets.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'auth_shell.dart';
import 'forgot_password_view.dart';
import 'register_view.dart';

class LoginView extends ConsumerStatefulWidget {
  const LoginView({super.key});

  @override
  ConsumerState<LoginView> createState() => _LoginViewState();
}

class _LoginViewState extends ConsumerState<LoginView> {
  final _credentialController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _isSubmitting = false;
  String? _errorMessage;

  @override
  void dispose() {
    _credentialController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  String _describeError(HgfastError error) {
    return switch (error) {
      HgfastAuthFailed() => '账号或密码错误',
      HgfastBanned() => '账号已被封禁',
      HgfastExpired() => '账号已过期',
      HgfastClientApiStateUnavailable() => '服务暂不可用，请稍后再试',
      HgfastCanaryDenied() => '登录尚未开放',
      _ => '登录失败，请稍后再试',
    };
  }

  Future<void> _handleLogin() async {
    final credential = _credentialController.text.trim();
    final password = _passwordController.text;
    if (credential.isEmpty || password.isEmpty) {
      setState(() {
        _errorMessage = '请输入账号和密码';
      });
      return;
    }
    setState(() {
      _isSubmitting = true;
      _errorMessage = null;
    });
    final loggedIn = await ref
        .read(hgfastAuthActionProvider.notifier)
        .login(credential: credential, password: password);
    if (!mounted) {
      return;
    }
    if (loggedIn) {
      setState(() {
        _isSubmitting = false;
      });
      return;
    }
    final error = ref.read(hgfastAuthProvider).error;
    if (error != null) {
      commonPrint.log(
        'login failed: ${error.code} ${error.message}',
        logLevel: LogLevel.warning,
      );
    }
    setState(() {
      _isSubmitting = false;
      _errorMessage = error != null ? _describeError(error) : '登录失败，请稍后再试';
    });
  }

  void _handleRegister() {
    BaseNavigator.push(context, const RegisterView());
  }

  void _handleForgotPassword() {
    BaseNavigator.push(context, const ForgotPasswordView());
  }

  @override
  Widget build(BuildContext context) {
    return CommonScaffold(
      title: '登录',
      actions: const [AuthTroubleButton()],
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 360),
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: _credentialController,
                  decoration: const InputDecoration(
                    border: OutlineInputBorder(),
                    labelText: '账号',
                  ),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: _passwordController,
                  obscureText: true,
                  decoration: const InputDecoration(
                    border: OutlineInputBorder(),
                    labelText: '密码',
                  ),
                  onSubmitted: (_) {
                    _handleLogin();
                  },
                ),
                if (_errorMessage != null) ...[
                  const SizedBox(height: 12),
                  Text(
                    _errorMessage!,
                    style: TextStyle(color: context.colorScheme.error),
                  ),
                ],
                const SizedBox(height: 24),
                FilledButton(
                  onPressed: _isSubmitting ? null : _handleLogin,
                  child: _isSubmitting
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Text('登录'),
                ),
                const SizedBox(height: 12),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    TextButton(
                      onPressed: _handleRegister,
                      child: const Text('还没有账号？去注册'),
                    ),
                    TextButton(
                      onPressed: _handleForgotPassword,
                      child: const Text('忘记密码？'),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
