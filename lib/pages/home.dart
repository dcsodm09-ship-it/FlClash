import 'package:fl_clash/common/common.dart';
import 'package:fl_clash/enum/enum.dart';
import 'package:fl_clash/manager/app_manager.dart';
import 'package:fl_clash/models/common.dart';
import 'package:fl_clash/providers/providers.dart';
import 'package:fl_clash/state.dart';
import 'package:fl_clash/widgets/widgets.dart';
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
                drawer: moreItems.isEmpty ? null : _MoreDrawer(items: moreItems),
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
    _pageController = PageController(initialPage: _pageIndex);
    ref.listenManual(currentPageLabelProvider, (prev, next) {
      if (prev != next) {
        _toPage(next);
      }
    });
  }

  @override
  void didUpdateWidget(covariant _HomePageView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.navigationItems.length != widget.navigationItems.length) {
      _updatePageController();
    }
  }

  // Falls back to 0 rather than -1 when currentPageLabelProvider's value
  // isn't in this mode's navigationItems (e.g. desktop-only labels while
  // mobile) — PageController(initialPage: -1) doesn't crash outright, but
  // the first frame can render with nothing laid out until a later scroll
  // settles the clamp, same class of bug as the Scaffold-type-swap above.
  int get _pageIndex {
    final pageLabel = ref.read(currentPageLabelProvider);
    final index = widget.navigationItems.indexWhere(
      (item) => item.label == pageLabel,
    );
    return index == -1 ? 0 : index;
  }

  Future<void> _toPage(
    PageLabel pageLabel, [
    bool ignoreAnimateTo = false,
  ]) async {
    if (!mounted) {
      return;
    }
    final index = widget.navigationItems.indexWhere(
      (item) => item.label == pageLabel,
    );
    if (index == -1) {
      return;
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
