import 'package:fl_clash/common/common.dart';
import 'package:fl_clash/hgfast/models/error.dart';
import 'package:fl_clash/hgfast/theme/hgfast_design.dart';
import 'package:fl_clash/widgets/widgets.dart';
import 'package:flutter/material.dart';

import 'auth_shell.dart';

class RegisterView extends StatelessWidget {
  /// See `LoginView.includeWindowChrome`'s doc comment — this screen is
  /// only ever reached by being pushed from a `LoginView`, so it just
  /// inherits whatever that caller determined about its own context
  /// instead of re-deciding independently.
  final bool includeWindowChrome;

  const RegisterView({super.key, this.includeWindowChrome = true});

  @override
  Widget build(BuildContext context) {
    // NOTE: production registration is currently disabled server-side (see
    // HgfastError.registerDisabled below) — there is no live email /
    // password / confirm-password form to wire up yet, so this screen stays
    // a styled "not available" notice. Business logic is unchanged from
    // before this visual pass; only presentation below was restyled.
    const error = HgfastError.registerDisabled();
    final description = switch (error) {
      HgfastRegisterDisabled() => '暂不支持在线注册，如需帮助请联系客服',
      _ => '注册暂未开放',
    };
    return HgfastAuthScope(
      includeWindowChrome: includeWindowChrome,
      child: CommonScaffold(
        title: '注册',
        actions: const [AuthTroubleButton()],
        body: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 360),
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const HgfastBrandMark(icon: Icons.hourglass_empty_rounded),
                  const SizedBox(height: HgfastSpacing.lg),
                  Text(
                    '注册暂未开放',
                    style: context.textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: HgfastSpacing.xs),
                  Text(
                    description,
                    style: context.textTheme.bodyMedium?.copyWith(
                      color: context.colorScheme.onSurfaceVariant,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  // Designated (currently inert) mount point for the
                  // production register form's antibot/challenge widget —
                  // see HgfastAntibotSlot doc comment for why this stays
                  // empty until a real register form exists.
                  const HgfastAntibotSlot(),
                  const SizedBox(height: HgfastSpacing.xl),
                  HgfastGradientButton(
                    onPressed: () {
                      Navigator.of(context).pop();
                    },
                    child: const Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.arrow_back_rounded),
                        SizedBox(width: HgfastSpacing.xs),
                        Text('返回登录'),
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
