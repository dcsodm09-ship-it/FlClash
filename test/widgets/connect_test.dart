import 'package:fl_clash/common/common.dart';
import 'package:fl_clash/common/theme.dart';
import 'package:fl_clash/enum/enum.dart';
import 'package:fl_clash/hgfast/models/error.dart';
import 'package:fl_clash/hgfast/models/node.dart';
import 'package:fl_clash/l10n/l10n.dart';
import 'package:fl_clash/providers/action.dart';
import 'package:fl_clash/providers/app.dart';
import 'package:fl_clash/providers/hgfast/nodes.dart';
import 'package:fl_clash/state.dart';
import 'package:fl_clash/views/connect/item.dart';
import 'package:fl_clash/views/views.dart';
import 'package:fl_clash/widgets/widgets.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('connect view filters the node list when a chip is tapped', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1000, 1200);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final container = _containerWithNodes(_fixtureNodes());
    addTearDown(container.dispose);
    globalState.container = container;

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const _TestApp(child: ConnectView()),
      ),
    );
    await tester.pump();

    expect(find.text('All'), findsOneWidget);
    expect(find.text('Recommended'), findsOneWidget);
    expect(find.text('Regional'), findsOneWidget);
    expect(find.text('VIP'), findsNothing);
    expect(container.read(connectFilterProvider), NodeTypeFilter.all);
    expect(find.byType(NodeItem), findsNWidgets(5));

    await tester.tap(find.text('Recommended'));
    await tester.pump();

    expect(container.read(connectFilterProvider), NodeTypeFilter.recommended);
    expect(find.text('Recommended order'), findsOneWidget);
    expect(find.byType(NodeItem), findsNWidgets(5));
    expect(tester.takeException(), null);

    await tester.tap(find.text('Regional'));
    await tester.pump();

    expect(container.read(connectFilterProvider), NodeTypeFilter.regional);
    expect(find.byType(NodeItem), findsNWidgets(5));
    expect(find.text('Grouped by region'), findsOneWidget);
    expect(tester.takeException(), null);
  });

  testWidgets(
    'connect view lays out its pinned header at the maximum text scale',
    (tester) async {
      tester.view.physicalSize = const Size(1000, 1200);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final container = _containerWithNodes(_fixtureNodes());
      addTearDown(container.dispose);
      globalState.container = container;

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: const _TestApp(textScaleFactor: 1.4, child: ConnectView()),
        ),
      );
      await tester.pump();

      expect(find.byType(NodeItem), findsNWidgets(5));
      expect(tester.takeException(), null);
    },
  );

  testWidgets(
    'loading with no cached catalog shows a spinner with a retry escape hatch',
    (tester) async {
      final syncAction = _SpyHgfastSyncAction();
      final container = ProviderContainer(
        overrides: [
          hgfastNodesProvider.overrideWith(
            () => _TestHgfastNodes(
              const HgfastNodesState(phase: HgfastNodesPhase.loading),
            ),
          ),
          hgfastSyncActionProvider.overrideWith(() => syncAction),
        ],
      );
      addTearDown(container.dispose);
      globalState.container = container;

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: const _TestApp(child: ConnectView()),
        ),
      );
      await tester.pump();

      expect(find.byType(NodeItem), findsNothing);
      expect(find.byType(CommonCircleLoading), findsOneWidget);

      await tester.tap(find.text('Retry'));
      await tester.pump();
      expect(syncAction.retryCount, 1);
      expect(tester.takeException(), null);
    },
  );

  testWidgets(
    'error with no cached catalog shows a retry button that calls retryNow',
    (tester) async {
      final syncAction = _SpyHgfastSyncAction();
      final container = ProviderContainer(
        overrides: [
          hgfastNodesProvider.overrideWith(
            () => _TestHgfastNodes(
              const HgfastNodesState(
                phase: HgfastNodesPhase.error,
                error: HgfastError.c1('E_NETWORK'),
              ),
            ),
          ),
          hgfastSyncActionProvider.overrideWith(() => syncAction),
        ],
      );
      addTearDown(container.dispose);
      globalState.container = container;

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: const _TestApp(child: ConnectView()),
        ),
      );
      await tester.pump();

      expect(find.text("Couldn't load nodes"), findsOneWidget);
      expect(find.byType(NodeItem), findsNothing);

      await tester.tap(find.text('Retry'));
      await tester.pump();

      expect(syncAction.retryCount, 1);
      expect(tester.takeException(), null);
    },
  );

  testWidgets(
    'error with a cached catalog shows the banner above the node list',
    (tester) async {
      final syncAction = _SpyHgfastSyncAction();
      final container = ProviderContainer(
        overrides: [
          hgfastNodesProvider.overrideWith(
            () => _TestHgfastNodes(
              HgfastNodesState(
                phase: HgfastNodesPhase.error,
                catalog: NodeCatalog(
                  automatic: true,
                  groups: {'test': _fixtureNodes()},
                ),
                error: const HgfastError.c1('E_NETWORK'),
              ),
            ),
          ),
          hgfastSyncActionProvider.overrideWith(() => syncAction),
        ],
      );
      addTearDown(container.dispose);
      globalState.container = container;

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: const _TestApp(child: ConnectView()),
        ),
      );
      await tester.pump();

      expect(find.text("Couldn't load nodes"), findsOneWidget);

      await tester.tap(find.text('Retry'));
      await tester.pump();
      expect(syncAction.retryCount, 1);
      expect(tester.takeException(), null);

      // The connect hero (power button + map + traffic pills) now sits above
      // the node list in the same scroll view, so on a phone-sized viewport
      // not all 5 fixture nodes are within the sliver's initial build extent
      // without scrolling — matches real device UX.
      await tester.drag(find.byType(Scrollable).first, const Offset(0, -1000));
      await tester.pump();
      expect(find.byType(NodeItem), findsNWidgets(5));
    },
  );

  testWidgets(
    'accountBlocked (expired) offers a view-plans CTA and a retry on desktop',
    (tester) async {
      final syncAction = _SpyHgfastSyncAction();
      final container = ProviderContainer(
        overrides: [
          hgfastNodesProvider.overrideWith(
            () => _TestHgfastNodes(
              const HgfastNodesState(
                phase: HgfastNodesPhase.accountBlocked,
                error: HgfastError.expired(),
              ),
            ),
          ),
          hgfastSyncActionProvider.overrideWith(() => syncAction),
        ],
      );
      addTearDown(container.dispose);
      globalState.container = container;
      container
          .read(viewSizeProvider.notifier)
          .update((_) => const Size(1200, 800));

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: const _TestApp(child: ConnectView()),
        ),
      );
      await tester.pump();

      expect(find.text('Your plan has expired'), findsOneWidget);
      expect(find.text('View plans'), findsOneWidget);

      await tester.tap(find.text('View plans'));
      await tester.pump();
      expect(container.read(currentPageLabelProvider), PageLabel.plans);

      await tester.tap(find.text('Retry'));
      await tester.pump();
      expect(syncAction.retryCount, 1);
      expect(tester.takeException(), null);
    },
  );

  testWidgets(
    'accountBlocked retry keeps the access gate visible while refreshing, '
    'not the stale cached node list',
    (tester) async {
      final container = ProviderContainer(
        overrides: [
          hgfastNodesProvider.overrideWith(
            () => _TestHgfastNodes(
              HgfastNodesState(
                phase: HgfastNodesPhase.accountBlocked,
                catalog: NodeCatalog(
                  automatic: true,
                  groups: {'test': _fixtureNodes()},
                ),
                error: const HgfastError.expired(),
              ),
            ),
          ),
          hgfastSyncActionProvider.overrideWith(
            () => _TransitioningHgfastSyncAction(),
          ),
        ],
      );
      addTearDown(container.dispose);
      globalState.container = container;
      container
          .read(viewSizeProvider.notifier)
          .update((_) => const Size(1200, 800));

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: const _TestApp(child: ConnectView()),
        ),
      );
      await tester.pump();

      expect(find.text('Your plan has expired'), findsOneWidget);
      expect(find.byType(NodeItem), findsNothing);

      await tester.tap(find.text('Retry'));
      await tester.pump();

      expect(find.text('Your plan has expired'), findsOneWidget);
      expect(find.byType(NodeItem), findsNothing);
      expect(find.byType(CommonCircleLoading), findsOneWidget);
      expect(tester.takeException(), null);
    },
  );

  testWidgets(
    'accountBlocked (expired) falls back to contact-support on mobile, '
    'where plans is unreachable',
    (tester) async {
      final container = ProviderContainer(
        overrides: [
          hgfastNodesProvider.overrideWith(
            () => _TestHgfastNodes(
              const HgfastNodesState(
                phase: HgfastNodesPhase.accountBlocked,
                error: HgfastError.expired(),
              ),
            ),
          ),
        ],
      );
      addTearDown(container.dispose);
      globalState.container = container;
      container
          .read(viewSizeProvider.notifier)
          .update((_) => const Size(400, 800));

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: const _TestApp(child: ConnectView()),
        ),
      );
      await tester.pump();

      expect(find.text('Your plan has expired'), findsOneWidget);
      expect(find.text('View plans'), findsNothing);
      expect(find.text('Contact support'), findsOneWidget);

      await tester.tap(find.text('Contact support'));
      await tester.pump();
      expect(container.read(currentPageLabelProvider), PageLabel.support);
      expect(tester.takeException(), null);
    },
  );

  testWidgets('accountBlocked (quotaExhausted) offers a view-plans CTA', (
    tester,
  ) async {
    final container = ProviderContainer(
      overrides: [
        hgfastNodesProvider.overrideWith(
          () => _TestHgfastNodes(
            const HgfastNodesState(
              phase: HgfastNodesPhase.accountBlocked,
              error: HgfastError.quotaExhausted(),
            ),
          ),
        ),
      ],
    );
    addTearDown(container.dispose);
    globalState.container = container;
    container
        .read(viewSizeProvider.notifier)
        .update((_) => const Size(1200, 800));

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const _TestApp(child: ConnectView()),
      ),
    );
    await tester.pump();

    expect(find.text("You've used up your traffic quota"), findsOneWidget);
    expect(find.text('View plans'), findsOneWidget);

    await tester.tap(find.text('View plans'));
    await tester.pump();
    expect(container.read(currentPageLabelProvider), PageLabel.plans);
    expect(tester.takeException(), null);
  });

  testWidgets('accountBlocked (banned) offers a contact-support CTA', (
    tester,
  ) async {
    final syncAction = _SpyHgfastSyncAction();
    final container = ProviderContainer(
      overrides: [
        hgfastNodesProvider.overrideWith(
          () => _TestHgfastNodes(
            const HgfastNodesState(
              phase: HgfastNodesPhase.accountBlocked,
              error: HgfastError.banned(),
            ),
          ),
        ),
        hgfastSyncActionProvider.overrideWith(() => syncAction),
      ],
    );
    addTearDown(container.dispose);
    globalState.container = container;

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const _TestApp(child: ConnectView()),
      ),
    );
    await tester.pump();

    expect(find.text('Your account has been suspended'), findsOneWidget);
    expect(find.text('Contact support'), findsOneWidget);

    await tester.tap(find.text('Contact support'));
    await tester.pump();
    expect(container.read(currentPageLabelProvider), PageLabel.support);

    await tester.tap(find.text('Retry'));
    await tester.pump();
    expect(syncAction.retryCount, 1);
    expect(tester.takeException(), null);
  });

  testWidgets('accountBlocked (noGroup) offers a contact-support CTA', (
    tester,
  ) async {
    final container = ProviderContainer(
      overrides: [
        hgfastNodesProvider.overrideWith(
          () => _TestHgfastNodes(
            const HgfastNodesState(
              phase: HgfastNodesPhase.accountBlocked,
              error: HgfastError.noGroup(),
            ),
          ),
        ),
      ],
    );
    addTearDown(container.dispose);
    globalState.container = container;

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const _TestApp(child: ConnectView()),
      ),
    );
    await tester.pump();

    expect(
      find.text("Your account hasn't been assigned a plan yet"),
      findsOneWidget,
    );
    expect(find.text('Contact support'), findsOneWidget);
    expect(tester.takeException(), null);
  });

  testWidgets(
    'notInCanary with no cached catalog shows an informational state',
    (tester) async {
      final syncAction = _SpyHgfastSyncAction();
      final container = ProviderContainer(
        overrides: [
          hgfastNodesProvider.overrideWith(
            () => _TestHgfastNodes(
              const HgfastNodesState(
                phase: HgfastNodesPhase.notInCanary,
                error: HgfastError.canaryDenied(HgfastResource.nodes),
              ),
            ),
          ),
          hgfastSyncActionProvider.overrideWith(() => syncAction),
        ],
      );
      addTearDown(container.dispose);
      globalState.container = container;

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: const _TestApp(child: ConnectView()),
        ),
      );
      await tester.pump();

      expect(
        find.text("This feature isn't open to your account yet"),
        findsOneWidget,
      );
      expect(find.byType(NodeItem), findsNothing);

      await tester.tap(find.text('Retry'));
      await tester.pump();
      expect(syncAction.retryCount, 1);
      expect(tester.takeException(), null);
    },
  );

  testWidgets(
    'notInCanary with a cached catalog shows a warning banner above the list',
    (tester) async {
      final syncAction = _SpyHgfastSyncAction();
      final container = ProviderContainer(
        overrides: [
          hgfastNodesProvider.overrideWith(
            () => _TestHgfastNodes(
              HgfastNodesState(
                phase: HgfastNodesPhase.notInCanary,
                catalog: NodeCatalog(
                  automatic: true,
                  groups: {'test': _fixtureNodes()},
                ),
                error: const HgfastError.canaryDenied(HgfastResource.nodes),
              ),
            ),
          ),
          hgfastSyncActionProvider.overrideWith(() => syncAction),
        ],
      );
      addTearDown(container.dispose);
      globalState.container = container;

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: const _TestApp(child: ConnectView()),
        ),
      );
      await tester.pump();

      expect(
        find.text("This feature isn't open to your account yet"),
        findsOneWidget,
      );

      await tester.tap(find.text('Retry'));
      await tester.pump();
      expect(syncAction.retryCount, 1);
      expect(tester.takeException(), null);

      // The connect hero (power button + map + traffic pills) now sits above
      // the node list in the same scroll view, so on a phone-sized viewport
      // not all 5 fixture nodes are within the sliver's initial build extent
      // without scrolling — matches real device UX.
      await tester.drag(find.byType(Scrollable).first, const Offset(0, -1000));
      await tester.pump();
      expect(find.byType(NodeItem), findsNWidgets(5));
    },
  );
}

ProviderContainer _containerWithNodes(List<NodeSpec> nodes) {
  return ProviderContainer(
    overrides: [
      hgfastNodesProvider.overrideWith(
        () => _TestHgfastNodes(
          HgfastNodesState(
            phase: HgfastNodesPhase.loaded,
            catalog: NodeCatalog(automatic: true, groups: {'test': nodes}),
          ),
        ),
      ),
    ],
  );
}

List<NodeSpec> _fixtureNodes() {
  return [
    _node(name: 'hk-01', region: 'HK', sort: 10),
    _node(name: 'jp-01', region: 'JP', sort: 20),
    _node(name: 'sg-01', region: 'SG', sort: 30),
    _node(name: 'us-01', region: 'US', sort: 40),
    _node(name: 'de-01', region: 'DE', sort: 50),
  ];
}

NodeSpec _node({
  required String name,
  required String region,
  required int sort,
}) {
  return NodeSpec(
    name: name,
    server: '$name.fixture.internal',
    serverPort: 20025,
    password: 'fixture-password',
    serverName: '$name.fixture.internal',
    insecure: false,
    protocol: 'anytls',
    region: region,
    routeLabel: region,
    rate: '1',
    sort: sort,
    groupId: 'test',
    category: NodeCategory.standard,
  );
}

class _TestHgfastNodes extends HgfastNodes {
  _TestHgfastNodes(this.initial);

  final HgfastNodesState initial;

  @override
  HgfastNodesState build() => initial;
}

class _SpyHgfastSyncAction extends HgfastSyncAction {
  int retryCount = 0;

  @override
  void build() {}

  @override
  Future<void> retryNow() async {
    retryCount++;
  }
}

class _TransitioningHgfastSyncAction extends HgfastSyncAction {
  @override
  void build() {}

  @override
  Future<void> retryNow() async {
    ref.read(hgfastNodesProvider.notifier).markLoading();
  }
}

class _TestApp extends StatelessWidget {
  final Widget child;
  final double textScaleFactor;

  const _TestApp({required this.child, this.textScaleFactor = 1});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      navigatorKey: globalState.navigatorKey,
      localizationsDelegates: const [
        AppLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
      ],
      supportedLocales: AppLocalizations.delegate.supportedLocales,
      builder: (context, child) {
        globalState.measure = Measure.of(context, textScaleFactor);
        globalState.theme = CommonTheme.of(context, textScaleFactor);
        return MediaQuery(
          data: MediaQuery.of(
            context,
          ).copyWith(textScaler: TextScaler.linear(textScaleFactor)),
          child: child!,
        );
      },
      home: child,
    );
  }
}
