import 'package:fl_clash/common/common.dart';
import 'package:fl_clash/hgfast/models/error.dart';
import 'package:fl_clash/hgfast/repository/hgfast_result_x.dart';
import 'package:fl_clash/hgfast/repository/repository.dart';
import 'package:fl_clash/hgfast/theme/hgfast_design.dart';
import 'package:fl_clash/pages/auth/login_view.dart';
import 'package:fl_clash/providers/providers.dart';
import 'package:fl_clash/widgets/widgets.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../hgfast_shared/hgfast_visual_kit.dart';
import 'invite_providers.dart';

num? _asNum(Object? value) {
  if (value is num) return value;
  if (value is String) return num.tryParse(value);
  return null;
}

// invite() returns `{ code, invited_count, reward_cents, records: [] }`.
// `code` is literally `'HG' + userId.padStart(6, '0')` server-side (e.g.
// `HG000023`) — NOT a random alphanumeric string, so it is rendered as-is
// here, never re-derived client-side. `reward_cents` is commission money in
// cents, NOT a GB/traffic quota — it is divided by 100 and shown as
// currency below.
class _InviteData {
  const _InviteData({
    required this.code,
    required this.invitedCount,
    required this.rewardCents,
    required this.records,
  });

  final String code;
  final int invitedCount;
  final int rewardCents;
  final List<Map<String, Object?>> records;

  String get rewardDisplay => '¥${(rewardCents / 100).toStringAsFixed(2)}';

  factory _InviteData.fromInvite(HgfastInvite invite) {
    final values = invite.values;
    final rawRecords = values['records'];
    return _InviteData(
      code: (values['code'] ?? '').toString(),
      invitedCount: _asNum(values['invited_count'])?.toInt() ?? 0,
      rewardCents: _asNum(values['reward_cents'])?.toInt() ?? 0,
      records: rawRecords is List
          ? rawRecords
                .whereType<Map>()
                .map(
                  (entry) => entry.map((key, value) => MapEntry('$key', value)),
                )
                .toList()
          : const <Map<String, Object?>>[],
    );
  }
}

/// 邀请中心 (Invite center) screen. `invite()` is real, authenticated
/// backend data — no fabricated GB/traffic reward here, `reward_cents` is
/// commission money and is rendered as currency, and `code` is the real
/// `HG000023`-style server-issued code, not a randomly generated one.
///
/// Not currently wired into navigation.dart — see this file's header note
/// in the implementation report for the suggested `NavigationItem` wiring
/// (no nav slot for it exists under 'account'/'我的' yet).
class InviteView extends ConsumerStatefulWidget {
  const InviteView({super.key});

  @override
  ConsumerState<InviteView> createState() => _InviteViewState();
}

class _InviteViewState extends ConsumerState<InviteView> {
  late Future<HgfastResult<HgfastInvite, HgfastError>> _future;

  @override
  void initState() {
    super.initState();
    _future = ref.read(hgfastRepositoryProvider).invite();
  }

  Future<void> _reload() async {
    final future = ref.read(hgfastRepositoryProvider).invite();
    setState(() {
      _future = future;
    });
    await future;
  }

  void _copyCode(String code) {
    Clipboard.setData(ClipboardData(text: code));
    context.showNotifier(context.appLocalizations.copySuccess);
  }

  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(hgfastAuthProvider);
    return HgfastAuthScope(
      child: CommonScaffold(
        title: '邀请中心',
        body: switch (authState.phase) {
          HgfastAuthPhase.unknown || HgfastAuthPhase.authenticating =>
            const Center(child: CommonCircleLoading()),
          HgfastAuthPhase.unauthenticated => _SignedOutState(
            // includeWindowChrome: false — this LoginView is pushed as a
            // nested re-auth prompt while still inside the authenticated
            // sidebar shell (HomePage -> AppSidebarContainer), which
            // already reserves its own macOS traffic-light clearance via
            // the sidebar's SizedBox(height: 22). See
            // LoginView.includeWindowChrome's doc comment.
            onLogin: () => BaseNavigator.push(
              context,
              const LoginView(includeWindowChrome: false),
            ),
          ),
          HgfastAuthPhase.authenticated => _InviteBody(
            future: _future,
            onReload: _reload,
            onCopyCode: _copyCode,
          ),
        },
      ),
    );
  }
}

class _SignedOutState extends StatelessWidget {
  const _SignedOutState({required this.onLogin});

  final VoidCallback onLogin;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.card_giftcard_outlined,
              size: 48,
              color: context.colorScheme.onSurfaceVariant,
            ),
            const SizedBox(height: 16),
            Text(
              '请先登录以查看邀请中心',
              style: context.textTheme.titleMedium,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            HgfastGradientButton(onPressed: onLogin, child: const Text('去登录')),
          ],
        ),
      ),
    );
  }
}

class _InviteBody extends StatelessWidget {
  const _InviteBody({
    required this.future,
    required this.onReload,
    required this.onCopyCode,
  });

  final Future<HgfastResult<HgfastInvite, HgfastError>> future;
  final Future<void> Function() onReload;
  final ValueChanged<String> onCopyCode;

  @override
  Widget build(BuildContext context) {
    final appLocalizations = context.appLocalizations;
    return FutureBuilder<HgfastResult<HgfastInvite, HgfastError>>(
      future: future,
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return const Center(child: CommonCircleLoading());
        }
        final invite = snapshot.data?.successValue;
        if (invite == null) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.error_outline,
                    size: 48,
                    color: context.colorScheme.onSurfaceVariant,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    '邀请信息加载失败',
                    style: context.textTheme.titleMedium,
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 16),
                  HgfastGradientButton(
                    onPressed: () => onReload(),
                    child: Text(appLocalizations.retry),
                  ),
                ],
              ),
            ),
          );
        }
        final data = _InviteData.fromInvite(invite);
        return RefreshIndicator(
          onRefresh: onReload,
          child: ListView(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
            children: [
              _InviteCodeCard(
                code: data.code,
                onCopy: () => onCopyCode(data.code),
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: _StatTile(
                      label: '已邀请人数',
                      value: '${data.invitedCount}',
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _StatTile(label: '累计佣金', value: data.rewardDisplay),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              const _LotteryEntry(),
              const SizedBox(height: 24),
              Text('邀请记录', style: context.textTheme.titleMedium),
              const SizedBox(height: 12),
              if (data.records.isEmpty)
                HgSurfaceCard(
                  child: Center(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      child: Text(
                        appLocalizations.nullTip('邀请记录'),
                        style: context.textTheme.bodyMedium,
                      ),
                    ),
                  ),
                )
              else
                HgSurfaceCard(
                  padding: EdgeInsets.zero,
                  child: Column(
                    children: [
                      for (var i = 0; i < data.records.length; i++) ...[
                        if (i > 0) const Divider(height: 1),
                        _InviteRecordTile(record: data.records[i]),
                      ],
                    ],
                  ),
                ),
            ],
          ),
        );
      },
    );
  }
}

class _InviteCodeCard extends StatelessWidget {
  const _InviteCodeCard({required this.code, required this.onCopy});

  final String code;
  final VoidCallback onCopy;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: HgfastGradients.brand,
        borderRadius: BorderRadius.circular(HgfastRadii.card),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            '我的邀请码',
            style: TextStyle(color: Colors.white70, fontSize: 13),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: Text(
                  code.isEmpty ? '—' : code,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 28,
                    fontWeight: FontWeight.w700,
                    fontFamily: 'JetBrainsMono',
                    letterSpacing: 1.5,
                  ),
                ),
              ),
              IconButton(
                onPressed: code.isEmpty ? null : onCopy,
                icon: const Icon(Icons.copy, color: Colors.white),
                tooltip: context.appLocalizations.copy,
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _StatTile extends StatelessWidget {
  const _StatTile({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return HgSurfaceCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: context.textTheme.bodySmall?.copyWith(
              color: context.colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            value,
            style: context.textTheme.titleLarge?.copyWith(
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

/// 抽奖 (prize draw) entry point. The original UI Kit mockup always shows
/// this, but the backend's `feature_flags.lottery` is currently `false` —
/// see invite_providers.dart's `hgfastLotteryEnabledProvider` for how this
/// is derived and why it defaults to hidden. This widget renders nothing at
/// all unless that provider resolves to an explicit `true`.
class _LotteryEntry extends ConsumerWidget {
  const _LotteryEntry();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final enabled = ref.watch(hgfastLotteryEnabledProvider);
    final isEnabled = enabled.asData?.value ?? false;
    if (!isEnabled) {
      return const SizedBox.shrink();
    }
    return HgSurfaceCard(
      child: Row(
        children: [
          const Icon(Icons.card_giftcard, color: HgfastColors.violet),
          const SizedBox(width: 12),
          Expanded(
            child: Text('参与抽奖赢取奖励', style: context.textTheme.bodyMedium),
          ),
          HgfastGradientButton(
            onPressed: () {
              context.showNotifier('抽奖功能即将上线');
            },
            child: const Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.celebration_outlined),
                SizedBox(width: 8),
                Text('抽奖'),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _InviteRecordTile extends StatelessWidget {
  const _InviteRecordTile({required this.record});

  final Map<String, Object?> record;

  @override
  Widget build(BuildContext context) {
    final user =
        (record['invited_user'] ??
                record['username'] ??
                record['user'] ??
                record['email'])
            ?.toString();
    final time = (record['created_at'] ?? record['time'] ?? record['date'])
        ?.toString();
    final rewardCents = _asNum(record['reward_cents'])?.toInt();
    return ListTile(
      leading: const CircleAvatar(child: Icon(Icons.person_outline)),
      title: Text(user?.isNotEmpty == true ? user! : '被邀请用户'),
      subtitle: time != null ? Text(time) : null,
      trailing: rewardCents != null
          ? Text(
              '+¥${(rewardCents / 100).toStringAsFixed(2)}',
              style: context.textTheme.bodyMedium?.copyWith(
                fontWeight: FontWeight.w700,
                color: HgfastColors.violet,
              ),
            )
          : null,
    );
  }
}
