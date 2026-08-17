import 'package:fl_clash/common/common.dart';
import 'package:fl_clash/hgfast/theme/hgfast_design.dart';
import 'package:fl_clash/widgets/widgets.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'auth_shell.dart';

class ForgotPasswordView extends ConsumerStatefulWidget {
  const ForgotPasswordView({super.key});

  @override
  ConsumerState<ForgotPasswordView> createState() => _ForgotPasswordViewState();
}

class _ForgotPasswordViewState extends ConsumerState<ForgotPasswordView> {
  late final Future<List<Map<String, Object?>>> _contactsFuture;

  @override
  void initState() {
    super.initState();
    _contactsFuture = fetchFallbackContacts(ref);
  }

  @override
  Widget build(BuildContext context) {
    return HgfastAuthScope(
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
                    '暂不支持在线重置密码，请通过以下方式联系客服协助找回：',
                    textAlign: TextAlign.center,
                    style: context.textTheme.bodyMedium?.copyWith(
                      color: context.colorScheme.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(height: HgfastSpacing.lg),
                  DecoratedBox(
                    decoration: BoxDecoration(
                      color: context.colorScheme.surface,
                      borderRadius: BorderRadius.circular(HgfastRadii.card),
                      border: Border.all(color: context.colorScheme.outline),
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
