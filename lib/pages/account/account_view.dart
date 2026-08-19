import 'dart:async';

import 'package:fl_clash/common/common.dart';
import 'package:fl_clash/hgfast/models/error.dart';
import 'package:fl_clash/hgfast/repository/hgfast_result_x.dart';
import 'package:fl_clash/hgfast/repository/repository.dart';
import 'package:fl_clash/hgfast/theme/hgfast_design.dart';
import 'package:fl_clash/providers/providers.dart';
import 'package:fl_clash/state.dart';
import 'package:fl_clash/widgets/widgets.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../auth/forgot_password_view.dart';
import '../docs/docs_view.dart';
import '../hgfast_shared/hgfast_visual_kit.dart';
import '../plans/plans_view.dart';
import '../support/support_view.dart';
import '../vip/vip_view.dart';

// 我的 (Account/Me) screen.
//
// `subscription()` (`GET /subscription`, real, authenticated) is real data —
// but ground-truthed against the live backend
// (core/client_api/data.js + lib/v2board-adapter.js on hgcloud, read-only,
// 2026-08-19) rather than guessed, because unlike `.plans()` no other screen
// in this codebase calls `.subscription()`/`.traffic()` yet and there was no
// existing ground truth to copy. Confirmed real response shape on the wire:
//   success: { sub_url, used_gb, total_gb, reset_at, device_limit }
//   no active plan: { sub_url: null, reason: 'banned'|'expired'|
//     'quota_exhausted'|'no_subscription'|'no_group' }
// BUT this repository's own `subscription()` (hgfast_repository_impl.dart)
// intercepts that `reason` field before it ever reaches this screen:
// mapHgfastAccountReason() (hgfast_error_mapping.dart) throws a typed
// HgfastError for banned/expired/quota_exhausted/no_group, turning those
// into an HgfastResult.failure — only 'no_subscription' (or a reason this
// mapper doesn't recognize) survives as a success payload with
// `sub_url: null`. A first version of this screen read `values['reason']`
// on the SUCCESS branch for all 4 cases — dead code for 3 of them, caught
// by review with a live probe (not by inspection): real banned/expired/
// quota_exhausted users were silently landing on the generic
// "套餐信息加载失败" retry card instead of an honest reason-specific message
// with a 续费/购买 CTA. Fixed: the reason-specific messages now key off the
// HgfastError subtype in the FAILURE branch (same pattern plans_view.dart's
// _describeOrderError already uses), and the success branch only ever
// needs the generic "暂无有效套餐" copy.
// Two more things worth knowing if this ever needs touching again:
// - `used_gb`/`total_gb` are decimal STRINGS ("42.30"), not numbers — the
//   backend's own comment says "契约禁浮点" (the contract forbids floats).
// - `reset_at` is misleadingly named on the wire: server-side it's a literal
//   passthrough of `v2_user.expired_at` (see v2board-adapter.js `subscription()`),
//   i.e. it's the account's *membership expiry*, not a traffic-cycle reset
//   date. Displayed here as "到期" for that reason, not "重置".
// There is no field anywhere (session, subscription, traffic, or plans) for
// a plan *name*/tier or a live "devices currently online" count — plans_view
// .dart's `device_limit` is a plan's cap, not a live count of connected
// devices. Both are therefore left out rather than fabricated. Likewise
// there is no real "断网保护 Kill Switch" setting anywhere in this app's
// config models (`VpnProps` has enable/systemProxy/allowBypass/dnsHijacking/
// accessControlProps — none of those is kill-switch semantics), so unlike
// the original UI-kit mockup this screen has no such toggle; adding one
// would mean a decorative control with no effect on anything.
class AccountView extends ConsumerStatefulWidget {
  const AccountView({super.key});

  @override
  ConsumerState<AccountView> createState() => _AccountViewState();
}

class _AccountViewState extends ConsumerState<AccountView> {
  late Future<HgfastResult<HgfastSubscription, HgfastError>> _future;

  @override
  void initState() {
    super.initState();
    _future = ref.read(hgfastRepositoryProvider).subscription();
  }

  Future<void> _reload() async {
    final future = ref.read(hgfastRepositoryProvider).subscription();
    setState(() {
      _future = future;
    });
    await future;
  }

  Future<void> _checkUpdate() async {
    // Same flow as the upstream About screen (lib/views/about.dart) — real,
    // already-wired update check, not rebuilt from scratch.
    final data = await globalState.safeRun<Map<String, dynamic>?>(
      request.checkForUpdate,
      title: context.appLocalizations.checkUpdate,
    );
    if (!mounted) {
      return;
    }
    globalState.container
        .read(commonActionProvider.notifier)
        .checkUpdateResultHandle(data: data, isUser: true);
  }

  Future<void> _confirmLogout() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('退出登录'),
        content: const Text('确定要退出当前账号吗？'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('取消'),
          ),
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('退出登录'),
          ),
        ],
      ),
    );
    if (confirmed != true) {
      return;
    }
    // Same pattern as globalState.handleSessionExpired() (lib/state.dart):
    // pop back to root first, then clear the session — the app-root
    // Consumer watching isAuthenticatedProvider (lib/application.dart)
    // reactively swaps to AuthShell/LoginView, no explicit push needed.
    globalState.navigatorKey.currentState?.popUntil((route) => route.isFirst);
    unawaited(ref.read(hgfastAuthActionProvider.notifier).logout());
  }

  Future<void> _openUnavailable(String label) async {
    context.showNotifier('$label暂未提供');
  }

  @override
  Widget build(BuildContext context) {
    final session = ref.watch(
      hgfastAuthProvider.select((state) => state.session),
    );
    final email = (session?.values['email'] as String?)?.trim();
    return HgfastAuthScope(
      child: CommonScaffold(
        title: '我的',
        body: RefreshIndicator(
          onRefresh: _reload,
          child: ListView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
            children: [
              _ProfileHeader(email: email),
              const SizedBox(height: HgfastSpacing.md),
              FutureBuilder<HgfastResult<HgfastSubscription, HgfastError>>(
                future: _future,
                builder: (context, snapshot) {
                  if (snapshot.connectionState != ConnectionState.done) {
                    return const Padding(
                      padding: EdgeInsets.symmetric(vertical: 32),
                      child: Center(child: CommonCircleLoading()),
                    );
                  }
                  final result = snapshot.data;
                  final subscription = result?.successValue;
                  if (subscription != null) {
                    return _SubscriptionCard(subscription: subscription);
                  }
                  // A "no active plan" state (banned/expired/quota
                  // exhausted/unbound) surfaces as a FAILURE with a typed
                  // HgfastError, not a success payload — see the
                  // file-level doc comment. Only fall back to the generic
                  // retry card for errors that aren't one of those.
                  final error = result?.failureError;
                  final reasonMessage = error != null
                      ? _describeAccountReasonError(error)
                      : null;
                  if (reasonMessage != null) {
                    return _NoSubscriptionCard(message: reasonMessage);
                  }
                  return _SubscriptionErrorCard(onRetry: _reload);
                },
              ),
              const SizedBox(height: HgfastSpacing.lg),
              const _SectionLabel('专属线路'),
              HgSurfaceCard(
                padding: EdgeInsets.zero,
                child: _ListRow(
                  icon: Icons.workspace_premium_outlined,
                  iconColor: Colors.amber,
                  label: 'VIP 专区',
                  trailing: const _Tag(text: '年付专享'),
                  onTap: () =>
                      BaseNavigator.push(context, const VipView()),
                ),
              ),
              const SizedBox(height: HgfastSpacing.lg),
              const _SectionLabel('设置'),
              HgSurfaceCard(
                padding: EdgeInsets.zero,
                child: Column(
                  children: [
                    _ListRow(
                      icon: Icons.lock_outline_rounded,
                      label: '修改密码',
                      // Reuses the real forgot-password flow (email code →
                      // new password) — there is no separate "change
                      // password while signed in" endpoint in
                      // HgfastRepository, and this one is real (gated the
                      // same way as the rest of the write path, honestly,
                      // by ForgotPasswordView itself).
                      onTap: () => BaseNavigator.push(
                        context,
                        const ForgotPasswordView(
                          includeWindowChrome: false,
                          fromAccountSettings: true,
                        ),
                      ),
                    ),
                    const Divider(height: 1),
                    _ListRow(
                      icon: Icons.menu_book_outlined,
                      label: '文档中心',
                      onTap: () =>
                          BaseNavigator.push(context, const DocsView()),
                    ),
                    const Divider(height: 1),
                    _ListRow(
                      icon: Icons.support_agent_outlined,
                      label: '联系客服',
                      onTap: () =>
                          BaseNavigator.push(context, const SupportView()),
                    ),
                    const Divider(height: 1),
                    _ListRow(
                      icon: Icons.system_update_outlined,
                      label: '检查更新',
                      onTap: _checkUpdate,
                    ),
                    const Divider(height: 1),
                    _ListRow(
                      icon: Icons.description_outlined,
                      label: '用户协议',
                      onTap: () => _openUnavailable('用户协议'),
                    ),
                    const Divider(height: 1),
                    _ListRow(
                      icon: Icons.privacy_tip_outlined,
                      label: '隐私政策',
                      onTap: () => _openUnavailable('隐私政策'),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: HgfastSpacing.xl),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: _confirmLogout,
                  style: OutlinedButton.styleFrom(
                    foregroundColor: context.colorScheme.error,
                    side: BorderSide(color: context.colorScheme.error),
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(HgfastRadii.pill),
                    ),
                  ),
                  icon: const Icon(Icons.power_settings_new_rounded),
                  label: const Text('退出登录'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ProfileHeader extends StatelessWidget {
  const _ProfileHeader({required this.email});

  final String? email;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 52,
          height: 52,
          decoration: const BoxDecoration(
            gradient: HgfastGradients.brand,
            shape: BoxShape.circle,
          ),
          child: const Icon(Icons.person, color: Colors.white),
        ),
        const SizedBox(width: HgfastSpacing.sm),
        Expanded(
          child: Text(
            (email?.isNotEmpty ?? false) ? email! : 'HGFAST 用户',
            style: context.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w800,
            ),
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }
}

num? _asNum(Object? value) {
  if (value is num) return value;
  if (value is String) return num.tryParse(value);
  return null;
}

/// Honest description of a `subscription()` failure that actually
/// represents "no active plan" rather than a real request/network error.
/// See the file-level doc comment: the repository layer already converts
/// the wire-level `reason` string into one of these typed HgfastError
/// subtypes before it ever reaches this screen, so this must switch on the
/// error type, not a raw `reason` string — a `values['reason']` check on
/// the success branch can never see these 4 cases in production. Returns
/// null for anything else (real network/protocol errors), which callers
/// treat as "show the generic retry card instead".
String? _describeAccountReasonError(HgfastError error) {
  return switch (error) {
    HgfastBanned() => '账号已被封禁，请联系客服',
    HgfastExpired() => '套餐已到期，续费后即可继续使用',
    HgfastQuotaExhausted() => '本期流量已用完，可续费或升级套餐',
    HgfastNoGroup() => '账号未绑定套餐组，请联系客服',
    _ => null,
  };
}

class _NoSubscriptionCard extends StatelessWidget {
  const _NoSubscriptionCard({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return HgSurfaceCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(message, style: context.textTheme.titleSmall),
          const SizedBox(height: HgfastSpacing.sm),
          SizedBox(
            width: double.infinity,
            child: HgfastGradientButton(
              onPressed: () => BaseNavigator.push(context, const PlansView()),
              child: const Text('去购买套餐'),
            ),
          ),
        ],
      ),
    );
  }
}

class _SubscriptionCard extends StatelessWidget {
  const _SubscriptionCard({required this.subscription});

  final HgfastSubscription subscription;

  @override
  Widget build(BuildContext context) {
    final values = subscription.values;
    final subUrl = values['sub_url'];
    final hasSubscription = subUrl is String && subUrl.trim().isNotEmpty;
    if (!hasSubscription) {
      // In production this is only ever reason: 'no_subscription' (every
      // other reason gets intercepted into an HgfastResult.failure before
      // reaching here — see the file-level doc comment) — kept as a
      // fallback rather than an assumption, since a success payload with
      // no sub_url genuinely means "nothing to show" regardless of why.
      return const _NoSubscriptionCard(message: '暂无有效套餐');
    }

    final usedGb = double.tryParse('${values['used_gb']}');
    final totalGb = double.tryParse('${values['total_gb']}');
    final deviceLimit = _asNum(values['device_limit'])?.toInt();
    final resetAtEpoch = _asNum(values['reset_at'])?.toInt() ?? 0;
    final progress = (usedGb != null && totalGb != null && totalGb > 0)
        ? (usedGb / totalGb).clamp(0.0, 1.0)
        : null;

    String? expiryLabel;
    if (resetAtEpoch > 0) {
      final expiry = DateTime.fromMillisecondsSinceEpoch(
        resetAtEpoch * 1000,
      );
      final now = DateTime.now();
      // Regression: `.inDays >= 0` truncates toward zero, so anything up
      // to 23h59m past expiry still reads `days == 0` -> "0 天后到期"
      // instead of "已到期". Check isBefore(now) directly instead of
      // inferring "already expired" from the truncated day count.
      expiryLabel = expiry.isBefore(now)
          ? '已到期'
          : '${expiry.difference(now).inDays} 天后到期';
    }

    return HgSurfaceCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const HgPillBadge(
                label: 'HGFAST 会员',
                icon: Icons.star_rounded,
              ),
              const Spacer(),
              if (expiryLabel != null)
                Text(
                  expiryLabel,
                  style: context.textTheme.bodySmall?.copyWith(
                    color: context.colorScheme.onSurfaceVariant,
                  ),
                ),
            ],
          ),
          if (progress != null) ...[
            const SizedBox(height: HgfastSpacing.sm),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  '本期流量',
                  style: context.textTheme.bodySmall?.copyWith(
                    color: context.colorScheme.onSurfaceVariant,
                  ),
                ),
                Text(
                  '${usedGb!.toStringAsFixed(2)}GB / ${totalGb!.toStringAsFixed(2)}GB',
                  style: context.textTheme.bodySmall,
                ),
              ],
            ),
            const SizedBox(height: 6),
            ClipRRect(
              borderRadius: BorderRadius.circular(HgfastRadii.pill),
              child: LinearProgressIndicator(
                value: progress,
                minHeight: 8,
                backgroundColor: context.colorScheme.surfaceContainerHighest,
              ),
            ),
          ],
          if (deviceLimit != null) ...[
            const SizedBox(height: HgfastSpacing.sm),
            Text(
              '最多可用设备 $deviceLimit 台',
              style: context.textTheme.bodySmall?.copyWith(
                color: context.colorScheme.onSurfaceVariant,
              ),
            ),
          ],
          const SizedBox(height: HgfastSpacing.md),
          SizedBox(
            width: double.infinity,
            child: HgfastGradientButton(
              onPressed: () => BaseNavigator.push(context, const PlansView()),
              child: const Text('续费 / 升级套餐'),
            ),
          ),
        ],
      ),
    );
  }
}

class _SubscriptionErrorCard extends StatelessWidget {
  const _SubscriptionErrorCard({required this.onRetry});

  final Future<void> Function() onRetry;

  @override
  Widget build(BuildContext context) {
    return HgSurfaceCard(
      child: Row(
        children: [
          Icon(
            Icons.error_outline,
            color: context.colorScheme.onSurfaceVariant,
          ),
          const SizedBox(width: HgfastSpacing.sm),
          const Expanded(child: Text('套餐信息加载失败')),
          TextButton(
            onPressed: () => onRetry(),
            child: Text(context.appLocalizations.retry),
          ),
        ],
      ),
    );
  }
}

class _SectionLabel extends StatelessWidget {
  const _SectionLabel(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: HgfastSpacing.sm, left: 4),
      child: Text(
        text,
        style: context.textTheme.labelMedium?.copyWith(
          color: context.colorScheme.onSurfaceVariant,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

class _Tag extends StatelessWidget {
  const _Tag({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
      decoration: BoxDecoration(
        color: Colors.amber.withValues(alpha: 0.16),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        text,
        style: const TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.w800,
          color: Colors.amber,
        ),
      ),
    );
  }
}

class _ListRow extends StatelessWidget {
  const _ListRow({
    required this.icon,
    required this.label,
    this.iconColor,
    this.trailing,
    this.onTap,
  });

  final IconData icon;
  final String label;
  final Color? iconColor;
  final Widget? trailing;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
        child: Row(
          children: [
            Icon(
              icon,
              color: iconColor ?? context.colorScheme.onSurfaceVariant,
              size: 20,
            ),
            const SizedBox(width: HgfastSpacing.sm),
            Expanded(child: Text(label)),
            if (trailing != null) ...[
              trailing!,
              const SizedBox(width: 6),
            ],
            Icon(
              Icons.chevron_right_rounded,
              color: context.colorScheme.onSurfaceVariant,
            ),
          ],
        ),
      ),
    );
  }
}
