import 'package:fl_clash/common/common.dart';
import 'package:fl_clash/enum/enum.dart';
import 'package:fl_clash/manager/app_manager.dart';
import 'package:fl_clash/models/common.dart';
import 'package:fl_clash/providers/providers.dart';
import 'package:fl_clash/state.dart';
import 'package:fl_clash/widgets/widgets.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

typedef OnSelected = void Function(int index);

// vip/profiles/tools/invite are all desktop-rail/settings-adjacent items
// that don't fit mobile's 4-slot bottom bar. Reached on mobile through
// _MoreDrawer instead of a bottom-nav tab, so the bar stays short.
// dashboard/support were the original picks here but got swapped out for
// vip/invite (revenue/growth entries) — dashboard mostly duplicates stats
// already on the connect screen; support loses its only mobile drawer
// entry but stays reachable from Connect's access-gate CTAs
// (onContactSupport in connect.dart's _ConnectAccessGate).
const _moreDrawerLabels = {
  PageLabel.vip,
  PageLabel.profiles,
  PageLabel.tools,
  PageLabel.invite,
};

class HomePage extends ConsumerWidget {
  const HomePage({super.key});

  // Stable across rebuilds (HomePage has exactly one live instance as the
  // app's root page) so the Scaffold identity — and therefore the Drawer —
  // doesn't get torn down and recreated on every rebuild.
  static final _scaffoldKey = GlobalKey<ScaffoldState>();

  void _handleToPage(PageLabel pageLabel) {
    globalState.container
        .read(currentPageLabelProvider.notifier)
        .toPage(pageLabel);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final hasViewSize = ref.watch(
      viewSizeProvider.select((size) => !size.isEmpty),
    );
    if (!hasViewSize) {
      return const SizedBox.shrink();
    }
    return HomeBackScopeContainer(
      child: AppSidebarContainer(
        child: Material(
          color: context.colorScheme.surface,
          child: Consumer(
            builder: (context, ref, child) {
              final state = ref.watch(navigationStateProvider);
              final isMobile = state.viewMode == ViewMode.mobile;
              final navigationItems = state.navigationItems;
              final currentIndex = state.currentIndex;
              // Unfiltered list (navigationItemsStateProvider, not
              // currentNavigationItemsStateProvider) so items with
              // modes: [desktop] — now excluded from `navigationItems` on
              // mobile — can still be picked out for the drawer by label.
              final moreItems = isMobile
                  ? ref
                        .watch(navigationItemsStateProvider)
                        .value
                        .where((item) => _moreDrawerLabels.contains(item.label))
                        .toList()
                  : const <NavigationItem>[];
              final destinations = [
                ...navigationItems.map(
                  (e) => NavigationDestination(
                    icon: e.icon,
                    label: Intl.message(e.label.name),
                  ),
                ),
                if (moreItems.isNotEmpty)
                  NavigationDestination(
                    icon: const Icon(Icons.menu),
                    label: Intl.message('more'),
                  ),
              ];
              final bottomNavigationBar = NavigationBarTheme(
                data: _NavigationBarDefaultsM3(context),
                child: NavigationBar(
                  destinations: destinations,
                  onDestinationSelected: (index) {
                    if (index >= navigationItems.length) {
                      _scaffoldKey.currentState?.openDrawer();
                      return;
                    }
                    _handleToPage(navigationItems[index].label);
                  },
                  selectedIndex: currentIndex,
                ),
              );
              final content = Column(
                children: [
                  Flexible(
                    flex: 1,
                    child: FocusTraversalGroup(
                      policy: PageTraversalPolicy(),
                      child: MediaQuery.removePadding(
                        removeTop: false,
                        removeBottom: isMobile,
                        removeLeft: isMobile,
                        removeRight: isMobile,
                        context: context,
                        child: child!,
                      ),
                    ),
                  ),
                  AnimatedVisibility.bottomNavigation(
                    visible: isMobile,
                    child: MediaQuery.removePadding(
                      removeTop: true,
                      removeBottom: false,
                      removeLeft: true,
                      removeRight: true,
                      context: context,
                      child: bottomNavigationBar,
                    ),
                  ),
                ],
              );
              // Always Scaffold, never bare `content` — the drawer is the
              // only thing that varies with `moreItems`. Swapping the
              // widget TYPE at this position based on isMobile (as an
              // earlier version of this did) tears down and rebuilds the
              // whole subtree on every breakpoint crossing: the PageView's
              // PageController, every KeepScope-kept page, and each
              // desktop tab's nested Navigator all lose their state, and
              // an in-flight AnimatedVisibility transition gets cut short
              // instead of finishing. See test/pages/home_test.dart's
              // "screen-size transition" test.
              return Scaffold(
                key: _scaffoldKey,
                backgroundColor: Colors.transparent,
                drawer: moreItems.isEmpty
                    ? null
                    : _MoreDrawer(items: moreItems),
                body: content,
              );
            },
            child: Consumer(
              builder: (_, ref, _) {
                final navigationItems = ref
                    .watch(currentNavigationItemsStateProvider)
                    .value;
                final isMobile = ref.watch(isMobileViewProvider);
                return _HomePageView(
                  navigationItems: navigationItems,
                  pageBuilder: (_, index) {
                    final navigationItem = navigationItems[index];
                    final navigationView = navigationItem.builder(context);
                    final scopedView = PageFocusScope(child: navigationView);
                    final view = KeepScope(
                      key: ValueKey(navigationItem.label),
                      keep: navigationItem.keep,
                      child: isMobile
                          ? scopedView
                          : Navigator(
                              key: ValueKey(
                                '${navigationItem.label.name}_navigator',
                              ),
                              pages: [MaterialPage(child: scopedView)],
                              onDidRemovePage: (_) {},
                            ),
                    );
                    return Consumer(
                      key: ValueKey(navigationItem.label),
                      builder: (_, ref, child) {
                        final isActive = ref.watch(
                          currentPageLabelProvider.select(
                            (label) => label == navigationItem.label,
                          ),
                        );
                        return PageActivityScope(
                          isActive: isActive,
                          child: ExcludeFocus(
                            excluding: !isActive,
                            child: child!,
                          ),
                        );
                      },
                      child: view,
                    );
                  },
                );
              },
            ),
          ),
        ),
      ),
    );
  }
}

class _HomePageView extends ConsumerStatefulWidget {
  final IndexedWidgetBuilder pageBuilder;
  final List<NavigationItem> navigationItems;

  const _HomePageView({
    required this.pageBuilder,
    required this.navigationItems,
  });

  @override
  ConsumerState createState() => _HomePageViewState();
}

class _HomePageViewState extends ConsumerState<_HomePageView> {
  late PageController _pageController;

  @override
  void initState() {
    super.initState();
    final pageLabel = ref.read(currentPageLabelProvider);
    final index = widget.navigationItems.indexWhere(
      (item) => item.label == pageLabel,
    );
    _pageController = PageController(initialPage: index == -1 ? 0 : index);
    if (index == -1) {
      // A fresh State can be built directly onto an unreachable label —
      // e.g. the window was minimized (HomePage returns SizedBox.shrink,
      // disposing this State) while on a desktop-only page, then restored
      // below the mobile breakpoint. _pageController above already shows
      // page 0; reconcile currentPageLabelProvider to match, same as
      // _toPage's -1 branch — otherwise every page computes isActive:false
      // (label matches nothing in navigationItems), excluding focus and
      // breaking the back layer until the user taps a tab.
      _reconcileUnreachableLabel(0, pageLabel);
    }
    ref.listenManual(currentPageLabelProvider, (prev, next) {
      if (prev != next) {
        _toPage(next);
      }
    });
  }

  // Schedules currentPageLabelProvider to catch up to whatever page is
  // actually being displayed at `displayedIndex`, when `triedLabel` (the
  // label that was supposed to show but isn't in navigationItems) differs
  // from it. Deferred to a post-frame callback since both call sites can
  // run from a widget lifecycle method (initState/didUpdateWidget), and
  // Riverpod forbids modifying a provider synchronously from one.
  void _reconcileUnreachableLabel(int displayedIndex, PageLabel triedLabel) {
    if (widget.navigationItems.isEmpty) {
      return;
    }
    final shownLabel = widget.navigationItems[displayedIndex].label;
    if (shownLabel == triedLabel) {
      return;
    }
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) {
        return;
      }
      ref.read(currentPageLabelProvider.notifier).toPage(shownLabel);
    });
  }

  @override
  void didUpdateWidget(covariant _HomePageView oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Not just a length check: two conditional desktop-only items
    // (proxies/hasProxies, logs/openLogs) can flip in opposite directions
    // within the same rebuild — e.g. BackupAction.restore(all) sets mode
    // (proxies leaves) and openLogs (logs enters) back-to-back with no
    // await between them — keeping the count identical while the actual
    // labels/positions shift. A length-only guard misses that: the page
    // controller never re-syncs, and if the current label just moved to a
    // different index (rather than leaving the list entirely), the
    // PageView shows a different page than what the tab/state agree on
    // with no -1 ever occurring to trigger the reconcile in _toPage.
    if (!listEquals(
      oldWidget.navigationItems.map((item) => item.label).toList(),
      widget.navigationItems.map((item) => item.label).toList(),
    )) {
      _updatePageController();
    }
  }

  Future<void> _toPage(
    PageLabel pageLabel, [
    bool ignoreAnimateTo = false,
  ]) async {
    if (!mounted) {
      return;
    }
    var index = widget.navigationItems.indexWhere(
      (item) => item.label == pageLabel,
    );
    if (index == -1) {
      // pageLabel just left this mode's navigationItems — most commonly
      // the user was on a desktop-only page (dashboard/profiles/tools/
      // support/vip/docs/plans/requests/connections/logs) and the window
      // shrank below the mobile breakpoint. Returning early here (the old
      // behavior) left
      // _pageController holding a scroll offset computed to preserve the
      // OLD page *index* against the NEW, smaller item count/viewport —
      // if that index is still in range for the new list it silently
      // shows a different, unrelated page with no visual cue at all; if
      // it's now out of range (e.g. the old page was near the end of a
      // long desktop nav) it can overscroll many viewports past the new
      // end, rendering blank for dozens of frames before settling.
      // navigationState's own currentIndex (used by the bottom bar/rail)
      // already falls back to 0 independently of any of this, so the
      // highlighted tab and the visible page disagree indefinitely until
      // the user taps a tab. Clamp the PageController to 0 AND reconcile
      // currentPageLabelProvider so both settle on the same, now-reachable
      // page instead of drifting apart.
      if (widget.navigationItems.isEmpty) {
        return;
      }
      index = 0;
      _reconcileUnreachableLabel(0, pageLabel);
    }
    final isAnimateToPage = ref.read(appSettingProvider).isAnimateToPage;
    final isMobile = ref.read(isMobileViewProvider);
    if (isAnimateToPage && isMobile && !ignoreAnimateTo) {
      await _pageController.animateToPage(
        index,
        duration: kTabScrollDuration,
        curve: Curves.easeOut,
      );
    } else {
      _pageController.jumpToPage(index);
    }
  }

  void _updatePageController() {
    final pageLabel = ref.read(currentPageLabelProvider);
    _toPage(pageLabel, true);
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final itemCount = ref.watch(
      currentNavigationItemsStateProvider.select((state) => state.value.length),
    );
    return PageView.builder(
      controller: _pageController,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: itemCount,
      findChildIndexCallback: (key) {
        if (key is! ValueKey<PageLabel>) {
          return null;
        }
        final index = widget.navigationItems.indexWhere(
          (item) => item.label == key.value,
        );
        return index == -1 ? null : index;
      },
      itemBuilder: (context, index) {
        return widget.pageBuilder(context, index);
      },
    );
  }
}

class _NavigationBarDefaultsM3 extends NavigationBarThemeData {
  _NavigationBarDefaultsM3(this.context)
    : super(
        height: 80.0,
        elevation: 3.0,
        labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
      );

  final BuildContext context;
  late final ColorScheme _colors = Theme.of(context).colorScheme;
  late final TextTheme _textTheme = Theme.of(context).textTheme;

  @override
  Color? get backgroundColor => _colors.surfaceContainer;

  @override
  Color? get shadowColor => Colors.transparent;

  @override
  Color? get surfaceTintColor => Colors.transparent;

  @override
  WidgetStateProperty<IconThemeData?>? get iconTheme {
    return WidgetStateProperty.resolveWith((Set<WidgetState> states) {
      return IconThemeData(
        size: 24.0,
        color: states.contains(WidgetState.disabled)
            ? _colors.onSurfaceVariant.opacity38
            : states.contains(WidgetState.selected)
            ? _colors.onSecondaryContainer
            : _colors.onSurfaceVariant,
      );
    });
  }

  @override
  Color? get indicatorColor => _colors.secondaryContainer;

  @override
  ShapeBorder? get indicatorShape => const StadiumBorder();

  @override
  WidgetStateProperty<TextStyle?>? get labelTextStyle {
    return WidgetStateProperty.resolveWith((Set<WidgetState> states) {
      final TextStyle style = _textTheme.labelMedium!;
      return style.apply(
        overflow: TextOverflow.ellipsis,
        color: states.contains(WidgetState.disabled)
            ? _colors.onSurfaceVariant.opacity38
            : states.contains(WidgetState.selected)
            ? _colors.onSurface
            : _colors.onSurfaceVariant,
      );
    });
  }
}

class HomeBackScopeContainer extends ConsumerWidget {
  final Widget child;

  const HomeBackScopeContainer({super.key, required this.child});

  @override
  Widget build(BuildContext context, ref) {
    return CommonPopScope(
      onPop: (context) async {
        final pageLabel = ref.read(currentPageLabelProvider);
        final realContext =
            GlobalObjectKey(pageLabel).currentContext ?? context;
        final canPop = Navigator.canPop(realContext);
        if (canPop) {
          Navigator.of(realContext).pop();
        } else {
          await globalState.container
              .read(systemActionProvider.notifier)
              .handleClose();
        }
        return false;
      },
      child: child,
    );
  }
}

// No ListItem.open here: it hardcodes onTap to null (see lib/widgets/list.dart),
// so it can't close this Drawer before pushing. Plain ListTile + BaseNavigator.push
// mirrors the pattern account_view.dart's _ListRow already uses for the same
// "row that opens another screen" need. Pushes `pushablePage(item.label)`
// (keyless) rather than `item.builder(context)` (carries a
// GlobalObjectKey(label)) — see navigation.dart's pushablePage doc for why.
class _MoreDrawer extends StatelessWidget {
  final List<NavigationItem> items;

  const _MoreDrawer({required this.items});

  @override
  Widget build(BuildContext context) {
    return Drawer(
      child: SafeArea(
        child: ListView(
          padding: EdgeInsets.zero,
          children: [
            DrawerHeader(
              child: Align(
                alignment: AlignmentDirectional.bottomStart,
                child: Text(
                  Intl.message('more'),
                  style: context.textTheme.titleLarge,
                ),
              ),
            ),
            for (final item in items)
              ListTile(
                leading: item.icon,
                title: Text(Intl.message(item.label.name)),
                subtitle: item.description != null
                    ? Text(Intl.message(item.description!))
                    : null,
                onTap: () {
                  Navigator.of(context).pop();
                  BaseNavigator.push(
                    context,
                    pushablePage(item.label) ?? item.builder(context),
                  );
                },
              ),
          ],
        ),
      ),
    );
  }
}
