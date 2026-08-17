import 'dart:async';

import 'package:fl_clash/common/common.dart';
import 'package:fl_clash/hgfast/models/error.dart';
import 'package:fl_clash/hgfast/repository/repository.dart';
import 'package:fl_clash/hgfast/theme/hgfast_design.dart';
import 'package:fl_clash/providers/providers.dart';
import 'package:fl_clash/state.dart';
import 'package:fl_clash/widgets/widgets.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

// Reuse the auth flow's fallback-contacts fetch + list widget instead of
// duplicating them — this file only *imports* lib/pages/auth/auth_shell.dart,
// it does not edit it.
import '../auth/auth_shell.dart'
    show AuthTroubleContactsBody, fetchFallbackContacts;
import '../hgfast_shared/hgfast_visual_kit.dart';

// ---------------------------------------------------------------------------
// AI-agent webview entry URL resolution.
//
// Known backend contradiction (flagged in a prior architecture review): the
// AI-agent contract reports `client_webview: { same_origin: true }`, but a
// same-origin webview can't safely carry the app's long-lived HGFAST session
// next to the third-party Crisp support-chat script that same page also
// loads — a same-origin embed would let that third-party script run inside
// an authenticated context. That flag is known-wrong; we deliberately do
// NOT honor it here.
//
// Instead this screen always opens the AI-agent entry point through
// `globalState.openUrl`, which hands the URL to the OS/system browser (see
// lib/state.dart). That is an independent origin and an independent
// cookie/storage jar by construction — it can never share the app's own
// webview session, regardless of what `same_origin` says.
//
// There is no `webview_flutter` (or similar) package in pubspec.yaml, and
// the only in-repo webview abstraction (`lib/common/hg_webview/api.dart`,
// `HgWebview`/`HgWebviewSpec`) is an interface with no concrete platform
// implementation or provider wired up anywhere yet — using it here would
// mean writing new native platform-channel code, which is out of scope for
// this screen. Per the task's own fallback rule, we use the
// already-a-dependency `url_launcher` (via `globalState.openUrl`) instead.
//
// The exact response field carrying the AI-agent entry URL has not been
// confirmed against live backend source from this client repo, so this is
// deliberately defensive: it tries a handful of plausible key names under
// `config()` and returns null (never a fabricated URL) if none match.
// TODO: confirm the real field name/shape against live backend and replace
// this with a typed accessor.
String? _resolveAiAgentUrl(HgfastConfig config) {
  final values = config.values;
  for (final containerKey in const ['ai_agent', 'client_webview']) {
    final container = values[containerKey];
    if (container is! Map) {
      continue;
    }
    for (final urlKey in const ['url', 'webview_url', 'entry_url', 'href']) {
      final candidate = container[urlKey];
      if (candidate is String && candidate.trim().isNotEmpty) {
        return candidate.trim();
      }
    }
  }
  return null;
}

class _SupportData {
  const _SupportData({required this.aiAgentUrl, required this.contacts});

  final String? aiAgentUrl;
  final List<Map<String, Object?>> contacts;
}

/// AI客服 (AI support) screen. The AI-agent entry is opened as an
/// independent-origin, scope-limited session in the system browser (see the
/// comment above `_resolveAiAgentUrl`), never as an in-app same-origin
/// webview. Human-staffed fallback contacts (Crisp / email / Telegram, from
/// bootstrap().fallback_contacts) are surfaced below it as a second, always
/// -available channel.
class SupportView extends ConsumerStatefulWidget {
  const SupportView({super.key});

  @override
  ConsumerState<SupportView> createState() => _SupportViewState();
}

class _SupportViewState extends ConsumerState<SupportView> {
  late Future<_SupportData> _dataFuture;

  @override
  void initState() {
    super.initState();
    _dataFuture = _load();
  }

  Future<_SupportData> _load() async {
    final repository = ref.read(hgfastRepositoryProvider);
    final configResult = await repository.config();
    final aiAgentUrl = switch (configResult) {
      HgfastResultSuccess<HgfastConfig, HgfastError>(:final value) =>
        _resolveAiAgentUrl(value),
      HgfastResultFailure<HgfastConfig, HgfastError>() => null,
    };
    final contacts = await fetchFallbackContacts(ref);
    return _SupportData(aiAgentUrl: aiAgentUrl, contacts: contacts);
  }

  Future<void> _reload() async {
    final future = _load();
    setState(() {
      _dataFuture = future;
    });
    await future;
  }

  void _openAiAgent(String url) {
    unawaited(globalState.openUrl(url));
  }

  @override
  Widget build(BuildContext context) {
    final appLocalizations = context.appLocalizations;
    return HgfastAuthScope(
      child: CommonScaffold(
        title: appLocalizations.support,
        body: FutureBuilder<_SupportData>(
          future: _dataFuture,
          builder: (context, snapshot) {
            if (snapshot.connectionState != ConnectionState.done) {
              return const Center(child: CommonCircleLoading());
            }
            final data =
                snapshot.data ??
                const _SupportData(aiAgentUrl: null, contacts: []);
            return RefreshIndicator(
              onRefresh: _reload,
              child: ListView(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
                children: [
                  _AiAgentCard(
                    url: data.aiAgentUrl,
                    onOpen: data.aiAgentUrl == null
                        ? null
                        : () => _openAiAgent(data.aiAgentUrl!),
                  ),
                  const SizedBox(height: 24),
                  Text('其他联系方式', style: context.textTheme.titleMedium),
                  const SizedBox(height: 12),
                  HgSurfaceCard(
                    padding: EdgeInsets.zero,
                    child: AuthTroubleContactsBody(contacts: data.contacts),
                  ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }
}

class _AiAgentCard extends StatelessWidget {
  const _AiAgentCard({required this.url, required this.onOpen});

  final String? url;
  final VoidCallback? onOpen;

  @override
  Widget build(BuildContext context) {
    return HgSurfaceCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: const BoxDecoration(
                  gradient: HgfastGradients.brand,
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.smart_toy_outlined,
                  size: 20,
                  color: Colors.white,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  'AI 智能客服',
                  style: context.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            url != null
                ? '在独立会话中打开 AI 客服，随时获得节点、账号与套餐相关的帮助。'
                : 'AI 客服入口暂未从服务端下发，请先使用下方联系方式。',
            style: context.textTheme.bodyMedium,
          ),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            child: HgfastGradientButton(
              onPressed: onOpen,
              child: const Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.open_in_new),
                  SizedBox(width: 8),
                  Text('打开 AI 客服'),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
