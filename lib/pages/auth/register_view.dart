import 'package:fl_clash/common/common.dart';
import 'package:fl_clash/hgfast/models/error.dart';
import 'package:fl_clash/widgets/widgets.dart';
import 'package:flutter/material.dart';

import 'auth_shell.dart';

class RegisterView extends StatelessWidget {
  const RegisterView({super.key});

  @override
  Widget build(BuildContext context) {
    const error = HgfastError.registerDisabled();
    final description = switch (error) {
      HgfastRegisterDisabled() => '暂不支持在线注册，如需帮助请联系客服',
      _ => '注册暂未开放',
    };
    return CommonScaffold(
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
                Icon(
                  Icons.hourglass_empty,
                  size: 48,
                  color: context.colorScheme.onSurfaceVariant,
                ),
                const SizedBox(height: 16),
                Text(
                  '注册暂未开放',
                  style: context.textTheme.titleLarge,
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 8),
                Text(
                  description,
                  style: context.textTheme.bodyMedium,
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 24),
                FilledButton(
                  onPressed: () {
                    Navigator.of(context).pop();
                  },
                  child: const Text('返回登录'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
