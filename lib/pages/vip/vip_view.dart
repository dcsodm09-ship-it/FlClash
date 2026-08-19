import 'package:fl_clash/common/common.dart';
import 'package:fl_clash/enum/enum.dart';
import 'package:fl_clash/hgfast/models/node.dart';
import 'package:fl_clash/hgfast/theme/hgfast_design.dart';
import 'package:fl_clash/models/models.dart';
import 'package:fl_clash/providers/providers.dart';
import 'package:fl_clash/widgets/widgets.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../hgfast_shared/hgfast_visual_kit.dart';

// VIP 专区 screen.
//
// All three sections below read the SAME already-real, already-wired data
// source Connect's own line-filter chips use
// (filterConnectNodesStateProvider(NodeTypeFilter.x) →
// NodeSpec.category == NodeCategory.vip/.dedicatedIp/.residential, see
// lib/providers/state.dart) — nothing here is fabricated or duplicated;
// this screen is just a different presentation of the same node catalog
// Connect already filters, grouped by category instead of shown as pills.
class VipView extends StatelessWidget {
  const VipView({super.key});

  @override
  Widget build(BuildContext context) {
    return HgfastAuthScope(
      child: CommonScaffold(
        title: 'VIP 专区',
        body: ListView(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
          children: const [
            _VipSection(
              filter: NodeTypeFilter.vip,
              title: 'VIP 专线（订阅导入）',
              icon: Icons.star_rounded,
              iconColor: Colors.amber,
              subtitle: '定制线路',
            ),
            SizedBox(height: HgfastSpacing.md),
            _VipSection(
              filter: NodeTypeFilter.dedicatedIp,
              title: '独享 IP',
              icon: Icons.public_rounded,
              subtitle: '独享出口，不与其他用户共享',
            ),
            SizedBox(height: HgfastSpacing.md),
            _VipSection(
              filter: NodeTypeFilter.residential,
              title: '住宅 IP',
              icon: Icons.home_rounded,
              subtitle: '住宅 IP，风控识别率更低',
            ),
          ],
        ),
      ),
    );
  }
}

class _VipSection extends ConsumerWidget {
  const _VipSection({
    required this.filter,
    required this.title,
    required this.icon,
    required this.subtitle,
    this.iconColor,
  });

  final NodeTypeFilter filter;
  final String title;
  final IconData icon;
  final String subtitle;
  final Color? iconColor;

  void _goToConnect(BuildContext context, WidgetRef ref) {
    ref.read(currentPageLabelProvider.notifier).toPage(PageLabel.connect);
    // VipView can be reached two ways: as its own desktop-only nav-rail
    // destination (nothing to pop — canPop() is false), or pushed from
    // AccountView on mobile/narrow width, where PageLabel.vip has no nav
    // slot at all (see lib/common/navigation.dart). canPop() tells them
    // apart safely without assuming which one this build is.
    if (Navigator.of(context).canPop()) {
      Navigator.of(context).pop();
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(filterConnectNodesStateProvider(filter));
    return HgSurfaceCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                icon,
                color: iconColor ?? context.colorScheme.onSurfaceVariant,
              ),
              const SizedBox(width: HgfastSpacing.sm),
              Expanded(
                child: Text(
                  title,
                  style: context.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            subtitle,
            style: context.textTheme.bodySmall?.copyWith(
              color: context.colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: HgfastSpacing.sm),
          _VipSectionBody(
            state: state,
            requestedFilter: filter,
            onGoToConnect: () => _goToConnect(context, ref),
          ),
        ],
      ),
    );
  }
}

class _VipSectionBody extends StatelessWidget {
  const _VipSectionBody({
    required this.state,
    required this.requestedFilter,
    required this.onGoToConnect,
  });

  final ConnectNodesState state;
  final NodeTypeFilter requestedFilter;
  final VoidCallback onGoToConnect;

  @override
  Widget build(BuildContext context) {
    switch (state.phase) {
      case ConnectLoadPhase.loading:
        return const Padding(
          padding: EdgeInsets.symmetric(vertical: 8),
          child: SizedBox(
            height: 18,
            width: 18,
            child: CircularProgressIndicator(strokeWidth: 2),
          ),
        );
      case ConnectLoadPhase.error:
      case ConnectLoadPhase.accountBlocked:
      case ConnectLoadPhase.notInCanary:
        return Text(
          '暂时无法加载线路信息',
          style: TextStyle(color: context.colorScheme.onSurfaceVariant),
        );
      case ConnectLoadPhase.loaded:
        break;
    }
    // filterConnectNodesStateProvider silently reconciles an unavailable
    // filter back to NodeTypeFilter.all (see connectAvailableFilters /
    // filterConnectNodesState in lib/providers/state.dart) — sensible for
    // Connect's own chips, which never request a filter that isn't already
    // offered, but wrong here: this screen always asks for all 3
    // categories regardless of whether the catalog actually has any nodes
    // of that type. Trusting state.nodes directly in that case would show
    // every node in the catalog mislabeled as e.g. "VIP 专线".
    // state.selectedFilter != requestedFilter is exactly the signal that
    // reconciliation happened, i.e. the real count for this category is
    // zero — caught by a real widget test (vip_test.dart) before this
    // shipped, not by inspection.
    final reconciledAway = state.selectedFilter != requestedFilter;
    final nodes = reconciledAway ? const <NodeSpec>[] : state.nodes;
    if (nodes.isEmpty) {
      return Text(
        '当前套餐暂未包含此类线路',
        style: TextStyle(color: context.colorScheme.onSurfaceVariant),
      );
    }
    return Row(
      children: [
        Expanded(
          child: Text(
            '已导入 ${nodes.length} 条线路 · ${nodes.take(2).map((node) => node.name).join(' · ')}',
            overflow: TextOverflow.ellipsis,
          ),
        ),
        const SizedBox(width: HgfastSpacing.sm),
        TextButton(onPressed: onGoToConnect, child: const Text('去连接')),
      ],
    );
  }
}
