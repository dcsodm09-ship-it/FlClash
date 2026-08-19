import 'package:fl_clash/common/common.dart';
import 'package:fl_clash/hgfast/models/error.dart';
import 'package:fl_clash/hgfast/repository/repository.dart';
import 'package:fl_clash/hgfast/theme/hgfast_design.dart';
import 'package:fl_clash/providers/providers.dart';
import 'package:fl_clash/widgets/widgets.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'auth_shell.dart';

// 找回密码 (forgot password) screen.
//
// This calls the real, signed POST /auth/reset/request and
// POST /auth/reset/confirm endpoints — they exist and are wired end to
// end, but the live backend keeps this write path permanently gated
// (403 WRITE_DISABLED / 501 WRITE_NOT_IMPLEMENTED, same shape as /order)
// until it is routed through the panel's already-hardened
// sendEmailCode(purpose:'reset')/resetPassword flow and audited — see
// repository.dart's doc comment on requestPasswordReset/
// confirmPasswordReset for why this was deliberately not reimplemented
// here. A gated response is surfaced as an honest "not available yet"
// message, keyed on the raw error.code string; the existing
// contact-support fallback stays visible below as the real, working
// path in the meantime — never a fabricated "code sent" / "password
// reset" success.
const Set<String> _gatedResetErrorCodes = {
  'WRITE_DISABLED',
  'WRITE_NOT_IMPLEMENTED',
};

class ForgotPasswordView extends ConsumerStatefulWidget {
  /// See `LoginView.includeWindowChrome`'s doc comment — pass whatever the
  /// caller determined about its own context instead of re-deciding
  /// independently. True (the default) when pushed from `LoginView` at the
  /// top level; `AccountView` passes `false` since it's reached from
  /// inside the authenticated sidebar shell instead.
  final bool includeWindowChrome;

  /// True when reached from `AccountView`'s "修改密码" row instead of the
  /// original logged-out "忘记密码？" flow — same real reset-by-email-code
  /// mechanism either way (there's no separate "change password while
  /// signed in" endpoint), but the copy below assumes a logged-out visitor
  /// by default ("返回登录", "登录即表示同意..."), which reads wrong for an
  /// already-authenticated user just changing their password.
  final bool fromAccountSettings;

  const ForgotPasswordView({
    super.key,
    this.includeWindowChrome = true,
    this.fromAccountSettings = false,
  });

  @override
  ConsumerState<ForgotPasswordView> createState() => _ForgotPasswordViewState();
}

class _ForgotPasswordViewState extends ConsumerState<ForgotPasswordView> {
  late final Future<List<Map<String, Object?>>> _contactsFuture;

  final _emailController = TextEditingController();
  final _codeController = TextEditingController();
  final _newPasswordController = TextEditingController();
  bool _obscurePassword = true;

  bool _isRequestingCode = false;
  bool _isConfirming = false;
  String? _requestMessage;
  String? _confirmMessage;
  bool _requestGated = false;
  bool _confirmGated = false;

  @override
  void initState() {
    super.initState();
    _contactsFuture = fetchFallbackContacts(ref);
  }

  @override
  void dispose() {
    _emailController.dispose();
    _codeController.dispose();
    _newPasswordController.dispose();
    super.dispose();
  }

  bool _isGated(HgfastError error) => _gatedResetErrorCodes.contains(error.code);

  Future<void> _handleRequestCode() async {
    final email = _emailController.text.trim();
    if (email.isEmpty) {
      setState(() {
        _requestMessage = '请输入邮箱地址';
        _requestGated = false;
      });
      return;
    }
    setState(() {
      _isRequestingCode = true;
      _requestMessage = null;
    });
    final result = await ref
        .read(hgfastRepositoryProvider)
        .requestPasswordReset(email: email);
    if (!mounted) return;
    switch (result) {
      case HgfastResultSuccess<HgfastJson, HgfastError>():
        setState(() {
          _isRequestingCode = false;
          _requestGated = false;
          _requestMessage = '验证码已发送，请查收邮箱';
        });
      case HgfastResultFailure<HgfastJson, HgfastError>(:final error):
        final gated = _isGated(error);
        setState(() {
          _isRequestingCode = false;
          _requestGated = gated;
          _requestMessage = gated
              ? '在线找回密码暂未开放，请使用下方联系方式'
              : (error.message ?? '发送失败，请稍后再试');
        });
    }
  }

  Future<void> _handleConfirmReset() async {
    final email = _emailController.text.trim();
    final code = _codeController.text.trim();
    final newPassword = _newPasswordController.text;
    if (email.isEmpty || code.isEmpty || newPassword.isEmpty) {
      setState(() {
        _confirmMessage = '请填写邮箱、验证码和新密码';
        _confirmGated = false;
      });
      return;
    }
    setState(() {
      _isConfirming = true;
      _confirmMessage = null;
    });
    final result = await ref.read(hgfastRepositoryProvider).confirmPasswordReset(
      email: email,
      code: code,
      newPassword: newPassword,
    );
    if (!mounted) return;
    switch (result) {
      case HgfastResultSuccess<HgfastJson, HgfastError>():
        setState(() {
          _isConfirming = false;
          _confirmGated = false;
          _confirmMessage = '密码已重置，请使用新密码登录';
        });
      case HgfastResultFailure<HgfastJson, HgfastError>(:final error):
        final gated = _isGated(error);
        setState(() {
          _isConfirming = false;
          _confirmGated = gated;
          _confirmMessage = gated
              ? '在线找回密码暂未开放，请使用下方联系方式'
              : (error.message ?? '重置失败，请检查验证码后重试');
        });
    }
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = context.colorScheme;
    return HgfastAuthScope(
      includeWindowChrome: widget.includeWindowChrome,
      child: CommonScaffold(
        title: '找回密码',
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
                  const Center(child: HgfastBrandMark(icon: Icons.key_rounded)),
                  const SizedBox(height: HgfastSpacing.lg),
                  Text(
                    '找回密码',
                    textAlign: TextAlign.center,
                    style: context.textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: HgfastSpacing.xs),
                  Text(
                    '输入注册邮箱获取验证码，重置账号密码',
                    textAlign: TextAlign.center,
                    style: context.textTheme.bodyMedium?.copyWith(
                      color: colorScheme.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(height: HgfastSpacing.xl),
                  HgfastTextField(
                    controller: _emailController,
                    hintText: '账号 / 邮箱',
                    leadingIcon: Icons.mail_outline_rounded,
                    textInputAction: TextInputAction.next,
                    keyboardType: TextInputType.emailAddress,
                    autofillHints: const [AutofillHints.email],
                  ),
                  const SizedBox(height: HgfastSpacing.md),
                  Row(
                    children: [
                      Expanded(
                        child: HgfastTextField(
                          controller: _codeController,
                          hintText: '验证码',
                          leadingIcon: Icons.pin_outlined,
                          textInputAction: TextInputAction.next,
                          keyboardType: TextInputType.number,
                        ),
                      ),
                      const SizedBox(width: HgfastSpacing.sm),
                      SizedBox(
                        height: 52,
                        child: FilledButton(
                          onPressed: _isRequestingCode ? null : _handleRequestCode,
                          child: _isRequestingCode
                              ? const SizedBox(
                                  width: 18,
                                  height: 18,
                                  child: CircularProgressIndicator(strokeWidth: 2),
                                )
                              : const Text('获取验证码'),
                        ),
                      ),
                    ],
                  ),
                  if (_requestMessage != null) ...[
                    const SizedBox(height: HgfastSpacing.xs),
                    Text(
                      _requestMessage!,
                      style: TextStyle(
                        color: _requestGated
                            ? colorScheme.onSurfaceVariant
                            : colorScheme.error,
                      ),
                    ),
                  ],
                  const SizedBox(height: HgfastSpacing.md),
                  HgfastTextField(
                    controller: _newPasswordController,
                    hintText: '新密码',
                    leadingIcon: Icons.lock_outline_rounded,
                    obscureText: _obscurePassword,
                    textInputAction: TextInputAction.done,
                    autofillHints: const [AutofillHints.newPassword],
                    suffixIcon: IconButton(
                      icon: Icon(
                        _obscurePassword
                            ? Icons.visibility_outlined
                            : Icons.visibility_off_outlined,
                        color: colorScheme.onSurfaceVariant,
                        size: 20,
                      ),
                      onPressed: () =>
                          setState(() => _obscurePassword = !_obscurePassword),
                    ),
                    onSubmitted: (_) => _handleConfirmReset(),
                  ),
                  if (_confirmMessage != null) ...[
                    const SizedBox(height: HgfastSpacing.sm),
                    Text(
                      _confirmMessage!,
                      style: TextStyle(
                        color: _confirmGated
                            ? colorScheme.onSurfaceVariant
                            : colorScheme.error,
                      ),
                    ),
                  ],
                  const SizedBox(height: HgfastSpacing.lg),
                  HgfastGradientButton(
                    onPressed: _isConfirming ? null : _handleConfirmReset,
                    child: _isConfirming
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              valueColor: AlwaysStoppedAnimation(Colors.white),
                            ),
                          )
                        : const Text('重置密码'),
                  ),
                  const SizedBox(height: HgfastSpacing.lg),
                  Text(
                    '在线找回密码暂未开放期间，也可通过以下方式联系客服协助找回：',
                    textAlign: TextAlign.center,
                    style: context.textTheme.bodySmall?.copyWith(
                      color: colorScheme.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(height: HgfastSpacing.sm),
                  DecoratedBox(
                    decoration: BoxDecoration(
                      color: colorScheme.surface,
                      borderRadius: BorderRadius.circular(HgfastRadii.card),
                      border: Border.all(color: colorScheme.outline),
                    ),
                    child: FutureBuilder<List<Map<String, Object?>>>(
                      future: _contactsFuture,
                      builder: (context, snapshot) {
                        if (snapshot.connectionState != ConnectionState.done) {
                          return const Padding(
                            padding: EdgeInsets.all(24),
                            child: Center(
                              child: CircularProgressIndicator(strokeWidth: 2),
                            ),
                          );
                        }
                        return AuthTroubleContactsBody(
                          contacts: snapshot.data ?? const [],
                          // Already inside this screen's own
                          // SingleChildScrollView.
                          physics: const NeverScrollableScrollPhysics(),
                        );
                      },
                    ),
                  ),
                  const SizedBox(height: HgfastSpacing.lg),
                  TextButton(
                    onPressed: () {
                      Navigator.of(context).pop();
                    },
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.arrow_back_rounded, size: 18),
                        const SizedBox(width: HgfastSpacing.xs),
                        Text(widget.fromAccountSettings ? '返回' : '返回登录'),
                      ],
                    ),
                  ),
                  const SizedBox(height: HgfastSpacing.lg),
                  HgfastAuthFooterCaption(
                    text: widget.fromAccountSettings
                        ? 'HGFAST v1.0.0'
                        : 'HGFAST v1.0.0 · 登录即表示同意《用户协议》与《隐私政策》',
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
