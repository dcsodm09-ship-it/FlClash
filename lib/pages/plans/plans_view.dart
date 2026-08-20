import 'dart:async';

import 'package:fl_clash/common/common.dart';
import 'package:fl_clash/hgfast/models/error.dart';
import 'package:fl_clash/hgfast/repository/hgfast_result_x.dart';
import 'package:fl_clash/hgfast/repository/repository.dart';
import 'package:fl_clash/hgfast/theme/hgfast_design.dart';
import 'package:fl_clash/hgfast/transport/decorrelated_jitter.dart';
import 'package:fl_clash/hgfast/transport/poll_policy.dart';
import 'package:fl_clash/providers/providers.dart';
import 'package:fl_clash/state.dart';
import 'package:fl_clash/widgets/widgets.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../hgfast_shared/hgfast_visual_kit.dart';

// 购买套餐 (purchase plans) screen.
//
// `plans()` is real, unauthenticated backend data (`GET /plans`, see
// v2board-adapter.js) — prices are cents, and a plan may legitimately omit
// some billing periods (`prices_cents.<period>` is `null`/absent), so this
// screen only ever renders the periods a plan actually offers, never a
// fabricated full set.
//
// `createOrder()` (`POST /order`) is real signing/plumbing, but the live
// backend keeps this write path permanently gated
// (`403 WRITE_DISABLED` / `501 WRITE_NOT_IMPLEMENTED`, see protocol.js) until
// it is routed through the panel's authed order/save flow. This screen must
// therefore never fabricate a success state for it — a gated response is
// surfaced as a calm, honest "not available yet" message, keyed on the raw
// `error.code` string so it also survives any future change to how that
// code gets mapped onto a `HgfastError` subtype.

const List<String> _periodOrder = [
  'month',
  'quarter',
  'half_year',
  'year',
  'onetime',
];

const Map<String, String> _periodLabels = {
  'month': '月付',
  'quarter': '季付',
  'half_year': '半年付',
  'year': '年付',
  'onetime': '一次性',
};

// Error codes for the permanent, deliberate write-path gate documented in
// protocol.js. Checked against `error.code` (not a specific `HgfastError`
// subtype) so this keeps working even if the mapping in
// hgfast_error_mapping.dart changes shape later.
const Set<String> _gatedOrderErrorCodes = {'WRITE_DISABLED', 'WRITE_NOT_IMPLEMENTED'};

const Duration _pollInterval = Duration(seconds: 4);
const int _maxPollAttempts = 15;

num? _asNum(Object? value) {
  if (value is num) return value;
  if (value is String) return num.tryParse(value);
  return null;
}

class _PlanPrice {
  const _PlanPrice({required this.period, required this.cents});

  final String period;
  final int cents;

  String get label => _periodLabels[period] ?? period;

  String get display => '¥${(cents / 100).toStringAsFixed(2)}';
}

class _PlanFeature {
  const _PlanFeature({required this.feature, required this.support});

  final String feature;
  final bool support;
}

class _PlanData {
  const _PlanData({
    required this.id,
    required this.name,
    required this.subtitle,
    required this.features,
    required this.transferGb,
    required this.deviceLimit,
    required this.speedLimitMbps,
    required this.prices,
  });

  final String id;
  final String name;
  final String? subtitle;
  final List<_PlanFeature> features;
  final int transferGb;
  final int? deviceLimit;
  final int? speedLimitMbps;
  final List<_PlanPrice> prices;

  factory _PlanData.fromJson(Map<String, Object?> json) {
    final pricesRaw = json['prices_cents'];
    final pricesMap = pricesRaw is Map
        ? pricesRaw.map((key, value) => MapEntry('$key', value))
        : const <String, Object?>{};
    // Matches the live web store's own availability rule (v2_plan rows use
    // 0, not just null/absent, to mean "this period isn't offered" —
    // app/public/views/store/render.js and public_v3_src/views/store.ts
    // both gate on > 0). A bare `!= null` check would render a real "月付
    // ¥0.00" buy chip for a period the website itself hides.
    final prices = <_PlanPrice>[
      for (final period in _periodOrder)
        if ((_asNum(pricesMap[period]) ?? 0) > 0)
          _PlanPrice(period: period, cents: _asNum(pricesMap[period])!.toInt()),
    ];
    final subtitleRaw = json['subtitle'];
    final featuresRaw = json['features'];
    // v2board-adapter.js's parsePlanFeatures() already validates each entry
    // server-side (JSON-array-of-{feature:string,support:bool} or []) — this
    // is a second, independent check on the client rather than trusting the
    // wire shape, matching how prices_cents is validated above instead of
    // cast straight through.
    final features = featuresRaw is List
        ? featuresRaw
              .whereType<Map>()
              .map((entry) => entry.map((key, value) => MapEntry('$key', value)))
              .where(
                (entry) =>
                    entry['feature'] is String && entry['support'] is bool,
              )
              .map(
                (entry) => _PlanFeature(
                  feature: entry['feature'] as String,
                  support: entry['support'] as bool,
                ),
              )
              .toList(growable: false)
        : const <_PlanFeature>[];
    return _PlanData(
      id: (json['id'] ?? '').toString(),
      name: (json['name'] ?? '').toString(),
      subtitle: (subtitleRaw is String && subtitleRaw.trim().isNotEmpty)
          ? subtitleRaw.trim()
          : null,
      features: features,
      transferGb: _asNum(json['transfer_gb'])?.toInt() ?? 0,
      deviceLimit: _asNum(json['device_limit'])?.toInt(),
      speedLimitMbps: _asNum(json['speed_limit_mbps'])?.toInt(),
      prices: prices,
    );
  }
}

List<_PlanData> _parsePlans(HgfastPlanCatalog catalog) {
  final raw = catalog.values['plans'];
  if (raw is! List) {
    return const <_PlanData>[];
  }
  return raw
      .whereType<Map>()
      .map(
        (entry) =>
            _PlanData.fromJson(entry.map((key, value) => MapEntry('$key', value))),
      )
      .where((plan) => plan.id.isNotEmpty)
      .toList(growable: false);
}

String? _resolvePayUrl(HgfastOrderStatus status) {
  for (final key in const ['pay_url', 'payUrl', 'url']) {
    final value = status.values[key];
    if (value is String && value.trim().isNotEmpty) {
      return value.trim();
    }
  }
  return null;
}

String? _resolveOrderId(HgfastOrderStatus status) {
  for (final key in const ['order_id', 'trade_no', 'id']) {
    final value = status.values[key];
    if (value is String && value.trim().isNotEmpty) {
      return value.trim();
    }
    if (value is num) {
      return value.toString();
    }
  }
  return null;
}

int? _resolveOrderStatusCode(HgfastOrderStatus status) {
  return _asNum(status.values['status'])?.toInt();
}

/// Honest description of a `createOrder()` failure. Never claims success and
/// never shows a generic message for the (currently permanent) write-path
/// gate — that case gets its own calm, explicit copy.
String _describeOrderError(HgfastError error) {
  if (_gatedOrderErrorCodes.contains(error.code)) {
    return '购买功能暂未开放，敬请期待';
  }
  return switch (error) {
    HgfastAuthFailed() => '请先登录后再购买',
    HgfastBadPlanId() => '套餐参数有误，请刷新页面后重试',
    HgfastBanned() => '账号已被封禁，暂时无法购买',
    HgfastExpired() => '账号已过期，请先续费或联系客服',
    HgfastNoGroup() => '账号未绑定套餐组，请联系客服',
    HgfastCanaryDenied() => '当前账号暂未开放该功能',
    HgfastClientApiStateUnavailable() => '服务暂不可用，请稍后重试',
    _ =>
      (error.message?.isNotEmpty ?? false) ? error.message! : '购买失败，请稍后重试',
  };
}

class PlansView extends ConsumerStatefulWidget {
  const PlansView({super.key});

  @override
  ConsumerState<PlansView> createState() => _PlansViewState();
}

class _PlansViewState extends ConsumerState<PlansView> {
  late Future<HgfastResult<HgfastPlanCatalog, HgfastError>> _future;

  @override
  void initState() {
    super.initState();
    _future = ref.read(hgfastRepositoryProvider).plans();
  }

  Future<void> _reload() async {
    final future = ref.read(hgfastRepositoryProvider).plans();
    setState(() {
      _future = future;
    });
    await future;
  }

  @override
  Widget build(BuildContext context) {
    final appLocalizations = context.appLocalizations;
    return HgfastAuthScope(
      child: CommonScaffold(
        title: '购买套餐',
        body: FutureBuilder<HgfastResult<HgfastPlanCatalog, HgfastError>>(
          future: _future,
          builder: (context, snapshot) {
            if (snapshot.connectionState != ConnectionState.done) {
              return const Center(child: CommonCircleLoading());
            }
            final catalog = snapshot.data?.successValue;
            if (catalog == null) {
              return _MessageState(
                icon: Icons.error_outline,
                message: '套餐加载失败',
                retryLabel: appLocalizations.retry,
                onRetry: _reload,
              );
            }
            final plans = _parsePlans(catalog);
            if (plans.isEmpty) {
              return _MessageState(
                icon: Icons.inventory_2_outlined,
                message: appLocalizations.nullTip('套餐'),
                retryLabel: appLocalizations.retry,
                onRetry: _reload,
              );
            }
            return RefreshIndicator(
              onRefresh: _reload,
              child: ListView.separated(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
                itemCount: plans.length,
                separatorBuilder: (_, _) => const SizedBox(height: 16),
                itemBuilder: (context, index) => _PlanCard(plan: plans[index]),
              ),
            );
          },
        ),
      ),
    );
  }
}

class _MessageState extends StatelessWidget {
  const _MessageState({
    required this.icon,
    required this.message,
    required this.retryLabel,
    required this.onRetry,
  });

  final IconData icon;
  final String message;
  final String retryLabel;
  final Future<void> Function() onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 48, color: context.colorScheme.onSurfaceVariant),
            const SizedBox(height: 16),
            Text(
              message,
              style: context.textTheme.titleMedium,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            HgfastGradientButton(
              onPressed: () => onRetry(),
              child: Text(retryLabel),
            ),
          ],
        ),
      ),
    );
  }
}

class _PlanFeatureList extends StatelessWidget {
  const _PlanFeatureList({required this.features});

  final List<_PlanFeature> features;

  @override
  Widget build(BuildContext context) {
    final colorScheme = context.colorScheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (final feature in features)
          Padding(
            padding: const EdgeInsets.only(bottom: 6),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(
                  feature.support ? Icons.check_circle : Icons.cancel,
                  size: 16,
                  color: feature.support
                      ? colorScheme.primary
                      : colorScheme.onSurfaceVariant,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    feature.feature,
                    style: context.textTheme.bodySmall?.copyWith(
                      color: feature.support
                          ? colorScheme.onSurface
                          : colorScheme.onSurfaceVariant,
                      decoration: feature.support
                          ? null
                          : TextDecoration.lineThrough,
                    ),
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }
}

class _PlanCard extends ConsumerStatefulWidget {
  const _PlanCard({required this.plan});

  final _PlanData plan;

  @override
  ConsumerState<_PlanCard> createState() => _PlanCardState();
}

class _PlanCardState extends ConsumerState<_PlanCard> {
  String? _selectedPeriod;
  bool _isPurchasing = false;
  String? _statusMessage;

  @override
  void initState() {
    super.initState();
    _selectedPeriod =
        widget.plan.prices.isEmpty ? null : widget.plan.prices.first.period;
  }

  Future<void> _purchase() async {
    final period = _selectedPeriod;
    if (period == null || _isPurchasing) {
      return;
    }
    setState(() {
      _isPurchasing = true;
      _statusMessage = null;
    });
    final result = await ref
        .read(hgfastRepositoryProvider)
        .createOrder(planId: widget.plan.id, period: period);
    if (!mounted) {
      return;
    }
    final order = result.successValue;
    if (order != null) {
      await _handleOrderSuccess(order);
      return;
    }
    final error = result.failureError;
    setState(() {
      _isPurchasing = false;
      _statusMessage = error != null
          ? _describeOrderError(error)
          : '购买失败，请稍后重试';
    });
  }

  Future<void> _handleOrderSuccess(HgfastOrderStatus order) async {
    final payUrl = _resolvePayUrl(order);
    if (payUrl != null) {
      // Real flow: the pay_url is an EPay payment-gateway link and must be
      // opened in the system browser, never an in-app webview — same
      // mechanism support_view.dart uses for the AI-agent entry point.
      unawaited(globalState.openUrl(payUrl));
    }
    if (!mounted) {
      return;
    }
    final orderId = _resolveOrderId(order);
    setState(() {
      _isPurchasing = false;
      _statusMessage = payUrl != null ? '已跳转至支付页面，请完成支付' : '订单已创建，等待支付结果';
    });
    if (orderId != null) {
      unawaited(_pollOrderStatus(orderId));
    }
  }

  Future<void> _pollOrderStatus(String orderId) async {
    // The backend hands out a decorrelated-jitter schedule specifically so
    // polling traffic doesn't have the fixed period + fixed size shape a
    // traffic classifier keys on (see poll_policy.dart's own doc comment,
    // quoting app/core/client_api/data.js). A fixed _pollInterval defeats
    // that even though the server-side padding half of the mitigation still
    // applies — so this always tries the real schedule first, only falling
    // back to the fixed interval if /config or its poll_policy is
    // unreachable/malformed (order-status polling must still work then).
    final schedule = await _orderStatusPollSchedule();
    for (var attempt = 0; attempt < _maxPollAttempts; attempt++) {
      await Future.delayed(schedule?.next() ?? _pollInterval);
      if (!mounted) {
        return;
      }
      final result = await ref.read(hgfastRepositoryProvider).orderStatus(orderId);
      if (!mounted) {
        return;
      }
      final status = result.successValue;
      if (status == null) {
        continue;
      }
      // 0=待支付 → 3=已完成, per orderCreateSpec()'s documented flow.
      if (_resolveOrderStatusCode(status) == 3) {
        setState(() {
          _statusMessage = '支付已完成';
        });
        return;
      }
    }
  }

  Future<HgfastDecorrelatedJitterSchedule?> _orderStatusPollSchedule() async {
    final result = await ref.read(hgfastRepositoryProvider).config();
    final policyJson = result.successValue?.values['poll_policy'];
    if (policyJson is! Map) {
      return null;
    }
    try {
      final policy = HgfastPollPolicy.fromJson(
        policyJson.map((key, value) => MapEntry('$key', value)),
      );
      return HgfastDecorrelatedJitterSchedule(policy: policy.orderStatus);
    } on FormatException {
      return null;
    }
  }

  @override
  Widget build(BuildContext context) {
    final plan = widget.plan;
    return HgSurfaceCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Text(
                  plan.name.isEmpty ? '—' : plan.name,
                  style: context.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Wrap(
                spacing: 6,
                runSpacing: 6,
                alignment: WrapAlignment.end,
                children: [
                  HgPillBadge(label: '${plan.transferGb} GB/月'),
                  if (plan.speedLimitMbps != null)
                    HgPillBadge(label: '${plan.speedLimitMbps}Mbps'),
                ],
              ),
            ],
          ),
          if (plan.subtitle != null) ...[
            const SizedBox(height: 4),
            Text(
              plan.subtitle!,
              style: context.textTheme.bodySmall?.copyWith(
                color: context.colorScheme.primary,
              ),
            ),
          ],
          const SizedBox(height: 8),
          Text(
            plan.deviceLimit != null ? '最多可用设备 ${plan.deviceLimit} 台' : '设备数不限',
            style: context.textTheme.bodySmall?.copyWith(
              color: context.colorScheme.onSurfaceVariant,
            ),
          ),
          if (plan.features.isNotEmpty) ...[
            const SizedBox(height: 12),
            _PlanFeatureList(features: plan.features),
          ],
          const SizedBox(height: 16),
          if (plan.prices.isEmpty)
            Text('暂无可选购买周期', style: context.textTheme.bodyMedium)
          else ...[
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final price in plan.prices)
                  ChoiceChip(
                    label: Text('${price.label} ${price.display}'),
                    selected: _selectedPeriod == price.period,
                    onSelected: _isPurchasing
                        ? null
                        : (_) => setState(() => _selectedPeriod = price.period),
                  ),
              ],
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: HgfastGradientButton(
                onPressed: (_isPurchasing || _selectedPeriod == null)
                    ? null
                    : _purchase,
                child: _isPurchasing
                    ? const SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : const Text('购买'),
              ),
            ),
          ],
          if (_statusMessage != null) ...[
            const SizedBox(height: 12),
            Text(
              _statusMessage!,
              style: context.textTheme.bodySmall?.copyWith(
                color: context.colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ],
      ),
    );
  }
}
