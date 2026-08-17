import 'package:fl_clash/common/common.dart';
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
    return CommonScaffold(
      title: '找回密码',
      actions: const [AuthTroubleButton()],
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              '暂不支持在线重置密码，请通过以下方式联系客服协助找回：',
              style: context.textTheme.bodyMedium,
            ),
            const SizedBox(height: 16),
            Expanded(
              child: FutureBuilder<List<Map<String, Object?>>>(
                future: _contactsFuture,
                builder: (context, snapshot) {
                  if (snapshot.connectionState != ConnectionState.done) {
                    return const Center(
                      child: CircularProgressIndicator(strokeWidth: 2),
                    );
                  }
                  return AuthTroubleContactsBody(
                    contacts: snapshot.data ?? const [],
                  );
                },
              ),
            ),
            const SizedBox(height: 16),
            FilledButton(
              onPressed: () {
                Navigator.of(context).pop();
              },
              child: const Text('返回登录'),
            ),
          ],
        ),
      ),
    );
  }
}
