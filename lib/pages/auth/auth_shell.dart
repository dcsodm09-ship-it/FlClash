import 'package:fl_clash/common/common.dart';
import 'package:fl_clash/hgfast/models/error.dart';
import 'package:fl_clash/hgfast/repository/repository.dart';
import 'package:fl_clash/state.dart';
import 'package:fl_clash/widgets/widgets.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'login_view.dart';

class AuthShell extends StatelessWidget {
  const AuthShell({super.key});

  @override
  Widget build(BuildContext context) {
    return const LoginView();
  }
}

List<Map<String, Object?>> extractFallbackContacts(HgfastBootstrap bootstrap) {
  final raw = bootstrap.values['fallback_contacts'];
  if (raw is! List) {
    return const [];
  }
  return raw
      .whereType<Map<Object?, Object?>>()
      .map((entry) => entry.map((key, value) => MapEntry('$key', value)))
      .toList();
}

Future<List<Map<String, Object?>>> fetchFallbackContacts(WidgetRef ref) async {
  final repository = ref.read(authRepositoryProvider);
  final result = await repository.bootstrap();
  return switch (result) {
    HgfastResultSuccess<HgfastBootstrap, HgfastError>(:final value) =>
      extractFallbackContacts(value),
    HgfastResultFailure<HgfastBootstrap, HgfastError>() => const [],
  };
}

class AuthTroubleContactsBody extends StatelessWidget {
  final List<Map<String, Object?>> contacts;

  const AuthTroubleContactsBody({super.key, required this.contacts});

  @override
  Widget build(BuildContext context) {
    if (contacts.isEmpty) {
      return Padding(
        padding: const EdgeInsets.all(24),
        child: Text('客服联系方式暂未配置，请稍后再试', style: context.textTheme.bodyMedium),
      );
    }
    return ListView.separated(
      shrinkWrap: true,
      padding: const EdgeInsets.symmetric(vertical: 8),
      itemCount: contacts.length,
      separatorBuilder: (_, _) => const Divider(height: 0),
      itemBuilder: (_, index) {
        final contact = contacts[index];
        final label =
            contact['label']?.toString() ?? contact['type']?.toString();
        final value = contact['value']?.toString() ?? '';
        return ListTile(
          title: Text(label ?? value),
          subtitle: label != null && value.isNotEmpty ? Text(value) : null,
        );
      },
    );
  }
}

Future<void> showAuthTroubleSheet(BuildContext context, WidgetRef ref) async {
  final contacts = await fetchFallbackContacts(ref);
  if (!context.mounted) {
    return;
  }
  await showSheet(
    context: context,
    builder: (_) {
      return AdaptiveSheetScaffold(
        title: '遇到问题？',
        body: AuthTroubleContactsBody(contacts: contacts),
      );
    },
  );
}

class AuthTroubleButton extends ConsumerWidget {
  const AuthTroubleButton({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return TextButton(
      onPressed: () {
        showAuthTroubleSheet(context, ref);
      },
      child: const Text('遇到问题？'),
    );
  }
}
