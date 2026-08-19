import 'package:fl_clash/common/common.dart';
import 'package:fl_clash/enum/enum.dart';
import 'package:fl_clash/hgfast/models/error.dart';
import 'package:fl_clash/hgfast/theme/hgfast_design.dart';
import 'package:fl_clash/providers/providers.dart';
import 'package:fl_clash/widgets/widgets.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'auth_shell.dart';
import 'forgot_password_view.dart';
import 'register_view.dart';

class LoginView extends ConsumerStatefulWidget {
  /// Whether to reserve the macOS drag-strip / traffic-light-clearance
  /// band above the AppBar (see `HgfastAuthScope.includeWindowChrome`'s doc
  /// comment). Defaults to `true` because the common case — reached via
  /// `AuthShell` at `application.dart`'s top-level
  /// `isAuthenticated ? HomePage : AuthShell` branch — has no sidebar and
  /// needs it. The one exception: `InviteView` pushes a `LoginView` as a
  /// nested re-auth prompt when a session expires while already inside the
  /// authenticated sidebar shell (`HomePage` → `AppSidebarContainer`) —
  /// that call site passes `false`, since the sidebar already reserves its
  /// own traffic-light clearance and a second strip there would reproduce
  /// the exact bug this was built to fix, just one screen deeper.
  final bool includeWindowChrome;

  const LoginView({super.key, this.includeWindowChrome = true});

  @override
  ConsumerState<LoginView> createState() => _LoginViewState();
}

class _LoginViewState extends ConsumerState<LoginView> {
  final _credentialController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _isSubmitting = false;
  bool _obscurePassword = true;
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
    final bool loggedIn;
    try {
      loggedIn = await ref
          .read(hgfastAuthActionProvider.notifier)
          .login(credential: credential, password: password);
    } on Object catch (error) {
      // Defensive backstop, not the primary fix: everything this call
      // chain reaches (HPKE seal, secure-storage device-identity mint,
      // network) is already supposed to convert its own failures into an
      // HgfastError instead of throwing (see hgfast_repository_impl.dart's
      // _deviceIdentity() call-site guards for a real example of a gap
      // that used to violate this and left this exact button stuck
      // spinning forever with _isSubmitting never reset). If something
      // still slips through uncaught, fail the same way any other login
      // failure does rather than hanging.
      commonPrint.log(
        'login threw: ${error.runtimeType}',
        logLevel: LogLevel.warning,
      );
      if (!mounted) {
        return;
      }
      setState(() {
        _isSubmitting = false;
        _errorMessage = '登录失败，请稍后再试';
      });
      return;
    }
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
    BaseNavigator.push(
      context,
      RegisterView(includeWindowChrome: widget.includeWindowChrome),
    );
  }

  void _handleForgotPassword() {
    BaseNavigator.push(
      context,
      ForgotPasswordView(includeWindowChrome: widget.includeWindowChrome),
    );
  }

  void _toggleObscurePassword() {
    setState(() {
      _obscurePassword = !_obscurePassword;
    });
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = context.colorScheme;
    return HgfastAuthScope(
      includeWindowChrome: widget.includeWindowChrome,
      child: CommonScaffold(
        title: '登录',
        actions: const [AuthTroubleButton()],
        body: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 360),
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Center(child: HgfastAppBrandHeader()),
                  const SizedBox(height: HgfastSpacing.lg),
                  Text(
                    '连接更快，一点即达',
                    textAlign: TextAlign.center,
                    style: context.textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: HgfastSpacing.xs),
                  Text(
                    '登录 HGFAST 账号，开启极速穿透连接',
                    textAlign: TextAlign.center,
                    style: context.textTheme.bodyMedium?.copyWith(
                      color: colorScheme.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(height: HgfastSpacing.xl),
                  HgfastTextField(
                    controller: _credentialController,
                    hintText: '账号 / 邮箱',
                    leadingIcon: Icons.mail_outline_rounded,
                    textInputAction: TextInputAction.next,
                    keyboardType: TextInputType.emailAddress,
                    autofillHints: const [AutofillHints.email],
                  ),
                  const SizedBox(height: HgfastSpacing.md),
                  HgfastTextField(
                    controller: _passwordController,
                    hintText: '密码',
                    leadingIcon: Icons.lock_outline_rounded,
                    obscureText: _obscurePassword,
                    textInputAction: TextInputAction.done,
                    autofillHints: const [AutofillHints.password],
                    suffixIcon: IconButton(
                      icon: Icon(
                        _obscurePassword
                            ? Icons.visibility_outlined
                            : Icons.visibility_off_outlined,
                        color: colorScheme.onSurfaceVariant,
                        size: 20,
                      ),
                      onPressed: _toggleObscurePassword,
                    ),
                    onSubmitted: (_) {
                      _handleLogin();
                    },
                  ),
                  if (_errorMessage != null) ...[
                    const SizedBox(height: HgfastSpacing.sm),
                    Text(
                      _errorMessage!,
                      style: TextStyle(color: colorScheme.error),
                    ),
                  ],
                  const SizedBox(height: HgfastSpacing.md),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      TextButton(
                        onPressed: _handleForgotPassword,
                        child: const Text('忘记密码？'),
                      ),
                      TextButton(
                        onPressed: _handleRegister,
                        child: const Text('还没有账号？去注册'),
                      ),
                    ],
                  ),
                  const SizedBox(height: HgfastSpacing.lg),
                  HgfastGradientButton(
                    onPressed: _isSubmitting ? null : _handleLogin,
                    child: _isSubmitting
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              valueColor: AlwaysStoppedAnimation(Colors.white),
                            ),
                          )
                        : const Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.power_settings_new_rounded),
                              SizedBox(width: HgfastSpacing.xs),
                              Text('登录'),
                            ],
                          ),
                  ),
                  const SizedBox(height: HgfastSpacing.lg),
                  const HgfastAuthFooterCaption(
                    text: 'HGFAST v1.0.0 · 登录即表示同意《用户协议》与《隐私政策》',
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
