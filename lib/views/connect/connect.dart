import 'package:fl_clash/common/common.dart';
import 'package:fl_clash/enum/enum.dart';
import 'package:fl_clash/models/models.dart';
import 'package:fl_clash/providers/providers.dart';
import 'package:fl_clash/widgets/widgets.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:super_sliver_list/super_sliver_list.dart';

import 'item.dart';

class ConnectView extends ConsumerWidget {
  const ConnectView({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final appLocalizations = context.appLocalizations;
    final rawFilter = ref.watch(connectFilterProvider);
    final ConnectNodesState(:nodes, :availableFilters, :selectedFilter) = ref
        .watch(filterConnectNodesStateProvider(rawFilter));
    final hintText = switch (selectedFilter) {
      NodeTypeFilter.recommended => appLocalizations.recommendedSort,
      NodeTypeFilter.regional => appLocalizations.regionalGrouped,
      _ => null,
    };
    return CommonScaffold(
      title: appLocalizations.connect,
      body: CustomScrollView(
        slivers: [
          SliverPersistentHeader(
            pinned: true,
            delegate: _ConnectFilterHeaderDelegate(
              availableFilters: availableFilters,
              selectedFilter: selectedFilter,
              onSelected: (filter) {
                ref.read(connectFilterProvider.notifier).value = filter;
              },
              hintText: hintText,
              backgroundColor: context.colorScheme.surface,
            ),
          ),
          if (nodes.isEmpty)
            SliverFillRemaining(
              hasScrollBody: false,
              child: NullStatus(
                label: appLocalizations.nullTip(appLocalizations.nodes),
              ),
            )
          else
            SliverPadding(
              padding: const EdgeInsets.only(top: 8, bottom: 16),
              sliver: SuperSliverList.builder(
                itemCount: nodes.length,
                itemBuilder: (context, index) {
                  return NodeItem(node: nodes[index]);
                },
              ),
            ),
        ],
      ),
    );
  }
}

class _ConnectFilterHeaderDelegate extends SliverPersistentHeaderDelegate {
  final List<NodeTypeFilter> availableFilters;
  final NodeTypeFilter selectedFilter;
  final ValueChanged<NodeTypeFilter> onSelected;
  final String? hintText;
  final Color backgroundColor;

  const _ConnectFilterHeaderDelegate({
    required this.availableFilters,
    required this.selectedFilter,
    required this.onSelected,
    required this.hintText,
    required this.backgroundColor,
  });

  double get _chipsRowHeight => 56.ap;

  double get _hintRowHeight => 32.ap;

  @override
  double get minExtent => _chipsRowHeight + _hintRowHeight;

  @override
  double get maxExtent => minExtent;

  @override
  Widget build(
    BuildContext context,
    double shrinkOffset,
    bool overlapsContent,
  ) {
    return Material(
      color: backgroundColor,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            height: _chipsRowHeight,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              itemCount: availableFilters.length,
              separatorBuilder: (_, _) => const SizedBox(width: 8),
              itemBuilder: (context, index) {
                final filter = availableFilters[index];
                final isSelected = filter == selectedFilter;
                return CommonChip(
                  label: Intl.message(filter.name),
                  avatar: isSelected ? const Icon(Icons.check, size: 16) : null,
                  labelStyle: isSelected
                      ? TextStyle(
                          color: context.colorScheme.onSecondaryContainer,
                        )
                      : null,
                  onPressed: () => onSelected(filter),
                );
              },
            ),
          ),
          SizedBox(
            height: _hintRowHeight,
            child: hintText == null
                ? null
                : Padding(
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                    child: Align(
                      alignment: Alignment.centerLeft,
                      child: Text(
                        hintText!,
                        style: context.textTheme.bodySmall?.copyWith(
                          color: context.colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ),
                  ),
          ),
        ],
      ),
    );
  }

  @override
  bool shouldRebuild(covariant _ConnectFilterHeaderDelegate oldDelegate) {
    return availableFilters != oldDelegate.availableFilters ||
        selectedFilter != oldDelegate.selectedFilter ||
        hintText != oldDelegate.hintText ||
        backgroundColor != oldDelegate.backgroundColor;
  }
}
