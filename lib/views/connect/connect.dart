// TODO: swap to shared hgfast_design tokens once
// `lib/hgfast/theme/hgfast_design.dart` lands (see hero.dart for details).

import 'dart:async';

import 'package:fl_clash/common/common.dart';
import 'package:fl_clash/enum/enum.dart';
import 'package:fl_clash/hgfast/models/error.dart';
import 'package:fl_clash/models/models.dart';
import 'package:fl_clash/providers/providers.dart';
import 'package:fl_clash/widgets/widgets.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:super_sliver_list/super_sliver_list.dart';

import 'hero.dart';
import 'item.dart';

class ConnectView extends ConsumerStatefulWidget {
  const ConnectView({super.key});

  @override
  ConsumerState<ConnectView> createState() => _ConnectViewState();
}

class _ConnectViewState extends ConsumerState<ConnectView> {
  bool _accessGateActive = false;
  HgfastError? _lastAccessGateError;

  @override
  Widget build(BuildContext context) {
    final appLocalizations = context.appLocalizations;
    final rawFilter = ref.watch(connectFilterProvider);
    final state = ref.watch(filterConnectNodesStateProvider(rawFilter));
    final isMobile = ref.watch(isMobileViewProvider);
    final hasCachedNodes = state.nodes.isNotEmpty;

    if (state.phase == ConnectLoadPhase.accountBlocked) {
      _accessGateActive = true;
      _lastAccessGateError = state.error;
    } else if (state.phase != ConnectLoadPhase.loading) {
      _accessGateActive = false;
    }

    void handleSelected(NodeTypeFilter filter) {
      ref.read(connectFilterProvider.notifier).value = filter;
    }

    void handleRetry() {
      unawaited(ref.read(hgfastSyncActionProvider.notifier).retryNow());
    }

    void handleNavigateTo(PageLabel label) {
      ref.read(currentPageLabelProvider.notifier).toPage(label);
    }

    final Widget body = switch (state.phase) {
      ConnectLoadPhase.accountBlocked => _ConnectAccessGate(
        error: state.error,
        isMobile: isMobile,
        onViewPlans: () => handleNavigateTo(PageLabel.plans),
        onContactSupport: () => handleNavigateTo(PageLabel.support),
        onRetry: handleRetry,
      ),
      ConnectLoadPhase.notInCanary =>
        hasCachedNodes
            ? _ConnectNodeList(
                state: state,
                onSelected: handleSelected,
                banner: _ConnectBanner(
                  tone: _BannerTone.warning,
                  message: appLocalizations.connectNotInCanary,
                  onRetry: handleRetry,
                ),
              )
            : _ConnectMessage(
                icon: Icons.hourglass_empty,
                message: appLocalizations.connectNotInCanary,
                onRetry: handleRetry,
              ),
      ConnectLoadPhase.error =>
        hasCachedNodes
            ? _ConnectNodeList(
                state: state,
                onSelected: handleSelected,
                banner: _ConnectBanner(
                  tone: _BannerTone.error,
                  message: appLocalizations.connectLoadFailed,
                  onRetry: handleRetry,
                ),
              )
            : _ConnectMessage(
                icon: Icons.error_outline,
                message: appLocalizations.connectLoadFailed,
                onRetry: handleRetry,
              ),
      ConnectLoadPhase.loading when _accessGateActive => _ConnectAccessGate(
        error: _lastAccessGateError,
        isMobile: isMobile,
        isRefreshing: true,
        onViewPlans: () => handleNavigateTo(PageLabel.plans),
        onContactSupport: () => handleNavigateTo(PageLabel.support),
        onRetry: handleRetry,
      ),
      ConnectLoadPhase.loading =>
        hasCachedNodes
            ? _ConnectNodeList(state: state, onSelected: handleSelected)
            : _ConnectLoading(onRetry: handleRetry),
      ConnectLoadPhase.loaded => _ConnectNodeList(
        state: state,
        onSelected: handleSelected,
      ),
    };

    return Theme(
      data: buildConnectHeroTheme(context),
      child: CommonScaffold(
        title: appLocalizations.connect,
        backgroundColor: hgHeroBackground,
        isLoading:
            state.phase == ConnectLoadPhase.loading &&
            hasCachedNodes &&
            !_accessGateActive,
        body: body,
      ),
    );
  }
}

class _ConnectNodeList extends StatelessWidget {
  final ConnectNodesState state;
  final ValueChanged<NodeTypeFilter> onSelected;
  final Widget? banner;

  const _ConnectNodeList({
    required this.state,
    required this.onSelected,
    this.banner,
  });

  @override
  Widget build(BuildContext context) {
    final appLocalizations = context.appLocalizations;
    final hintText = switch (state.selectedFilter) {
      NodeTypeFilter.recommended => appLocalizations.recommendedSort,
      NodeTypeFilter.regional => appLocalizations.regionalGrouped,
      _ => null,
    };
    return Column(
      children: [
        ?banner,
        Expanded(
          child: DecoratedBox(
            decoration: const BoxDecoration(color: hgHeroBackground),
            child: CustomScrollView(
              slivers: [
                const SliverToBoxAdapter(child: ConnectHero()),
                SliverPersistentHeader(
                  pinned: true,
                  delegate: _ConnectFilterHeaderDelegate(
                    availableFilters: state.availableFilters,
                    selectedFilter: state.selectedFilter,
                    onSelected: onSelected,
                    hintText: hintText,
                    backgroundColor: hgHeroBackground,
                  ),
                ),
                if (state.nodes.isEmpty)
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
                      itemCount: state.nodes.length,
                      itemBuilder: (context, index) {
                        return NodeItem(node: state.nodes[index]);
                      },
                    ),
                  ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _ConnectLoading extends StatelessWidget {
  final VoidCallback onRetry;

  const _ConnectLoading({required this.onRetry});

  @override
  Widget build(BuildContext context) {
    final appLocalizations = context.appLocalizations;
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const CommonCircleLoading(),
          const SizedBox(height: 16),
          TextButton(onPressed: onRetry, child: Text(appLocalizations.retry)),
        ],
      ),
    );
  }
}

class _ConnectMessage extends StatelessWidget {
  final IconData icon;
  final String message;
  final VoidCallback? onRetry;

  const _ConnectMessage({
    required this.icon,
    required this.message,
    this.onRetry,
  });

  @override
  Widget build(BuildContext context) {
    final appLocalizations = context.appLocalizations;
    final colorScheme = context.colorScheme;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 48, color: colorScheme.onSurfaceVariant),
            const SizedBox(height: 16),
            Text(
              message,
              textAlign: TextAlign.center,
              style: context.textTheme.titleMedium,
            ),
            if (onRetry != null) ...[
              const SizedBox(height: 16),
              FilledButton(
                onPressed: onRetry,
                child: Text(appLocalizations.retry),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _ConnectAccessGate extends StatelessWidget {
  final HgfastError? error;
  final bool isMobile;
  final bool isRefreshing;
  final VoidCallback onViewPlans;
  final VoidCallback onContactSupport;
  final VoidCallback onRetry;

  const _ConnectAccessGate({
    required this.error,
    required this.isMobile,
    this.isRefreshing = false,
    required this.onViewPlans,
    required this.onContactSupport,
    required this.onRetry,
  });

  @override
  Widget build(BuildContext context) {
    final appLocalizations = context.appLocalizations;
    final colorScheme = context.colorScheme;
    final viewPlansCta = isMobile
        ? (appLocalizations.contactSupport, onContactSupport)
        : (appLocalizations.viewPlans, onViewPlans);
    final (message, ctaLabel, onCta) = switch (error) {
      HgfastBanned() => (
        appLocalizations.accessGateBanned,
        appLocalizations.contactSupport,
        onContactSupport,
      ),
      HgfastExpired() => (
        appLocalizations.accessGateExpired,
        viewPlansCta.$1,
        viewPlansCta.$2,
      ),
      HgfastQuotaExhausted() => (
        appLocalizations.accessGateQuotaExhausted,
        viewPlansCta.$1,
        viewPlansCta.$2,
      ),
      HgfastNoGroup() => (
        appLocalizations.accessGateNoGroup,
        appLocalizations.contactSupport,
        onContactSupport,
      ),
      _ => (
        appLocalizations.connectLoadFailed,
        appLocalizations.contactSupport,
        onContactSupport,
      ),
    };
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.lock_outline,
              size: 48,
              color: colorScheme.onSurfaceVariant,
            ),
            const SizedBox(height: 16),
            Text(
              message,
              textAlign: TextAlign.center,
              style: context.textTheme.titleMedium,
            ),
            const SizedBox(height: 16),
            if (isRefreshing)
              const CommonCircleLoading()
            else ...[
              FilledButton(onPressed: onCta, child: Text(ctaLabel)),
              const SizedBox(height: 16),
              TextButton(
                onPressed: onRetry,
                child: Text(appLocalizations.retry),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

enum _BannerTone { warning, error }

class _ConnectBanner extends StatelessWidget {
  final _BannerTone tone;
  final String message;
  final VoidCallback onRetry;

  const _ConnectBanner({
    required this.tone,
    required this.message,
    required this.onRetry,
  });

  @override
  Widget build(BuildContext context) {
    final appLocalizations = context.appLocalizations;
    final colorScheme = context.colorScheme;
    final (background, foreground) = switch (tone) {
      _BannerTone.warning => (
        colorScheme.tertiaryContainer,
        colorScheme.onTertiaryContainer,
      ),
      _BannerTone.error => (
        colorScheme.errorContainer,
        colorScheme.onErrorContainer,
      ),
    };
    return Container(
      width: double.infinity,
      color: background,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        children: [
          Icon(
            tone == _BannerTone.error
                ? Icons.error_outline
                : Icons.info_outline,
            size: 18,
            color: foreground,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              message,
              style: context.textTheme.bodySmall?.copyWith(color: foreground),
            ),
          ),
          TextButton(
            onPressed: onRetry,
            child: Text(
              appLocalizations.retry,
              style: TextStyle(color: foreground),
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
                // Pill-shaped chip: a gradient-filled Container carries the
                // shape/background, CommonChip's underlying Material Chip is
                // themed transparent so the gradient shows through.
                return DecoratedBox(
                  decoration: ShapeDecoration(
                    shape: const StadiumBorder(),
                    gradient: isSelected ? hgBrandGradient : null,
                    color: isSelected ? null : hgHeroSurface,
                  ),
                  child: Theme(
                    data: Theme.of(context).copyWith(
                      chipTheme: Theme.of(context).chipTheme.copyWith(
                        backgroundColor: Colors.transparent,
                        shape: const StadiumBorder(side: BorderSide.none),
                        side: BorderSide.none,
                        elevation: 0,
                        pressElevation: 0,
                      ),
                    ),
                    child: CommonChip(
                      label: Intl.message(filter.name),
                      avatar: isSelected
                          ? const Icon(
                              Icons.check,
                              size: 16,
                              color: Colors.white,
                            )
                          : null,
                      labelStyle: TextStyle(
                        color: isSelected ? Colors.white : hgTextSecondary,
                        fontWeight: FontWeight.w600,
                      ),
                      onPressed: () => onSelected(filter),
                    ),
                  ),
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
