// Pins VipView's use of the SAME real node-filtering data Connect's own
// line-filter chips already use (filterConnectNodesStateProvider +
// NodeCategory) — never a separately-fabricated count.
import 'package:fl_clash/enum/enum.dart';
import 'package:fl_clash/hgfast/models/node.dart';
import 'package:fl_clash/l10n/l10n.dart';
import 'package:fl_clash/pages/vip/vip_view.dart';
import 'package:fl_clash/providers/providers.dart';
import 'package:fl_clash/state.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  NodeSpec node({
    required String name,
    NodeCategory category = NodeCategory.standard,
  }) {
    return NodeSpec(
      name: name,
      server: 'server.test',
      serverPort: 20025,
      password: 'fixture-password',
      serverName: 'server.test',
      insecure: false,
      protocol: 'anytls',
      region: 'HK',
      routeLabel: 'HK',
      rate: '1',
      sort: 0,
      groupId: 'test',
      category: category,
    );
  }

  Future<ProviderContainer> pump(
    WidgetTester tester, {
    required List<NodeSpec> nodes,
  }) async {
    final container = ProviderContainer(
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
    addTearDown(container.dispose);
    globalState.container = container;

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const _TestApp(child: VipView()),
      ),
    );
    await tester.pump();
    await tester.pump();
    return container;
  }

  testWidgets(
    'shows real per-category node counts, matching Connect\'s own '
    'category filtering, not a separately-fabricated number',
    (tester) async {
      await pump(
        tester,
        nodes: [
          node(name: '定制线路 01', category: NodeCategory.vip),
          node(name: '定制线路 02', category: NodeCategory.vip),
          node(name: '固定IP · 上海联通', category: NodeCategory.dedicatedIp),
          node(name: '家宽 · 东京软银', category: NodeCategory.residential),
          node(name: '香港 01'), // standard — must not count toward any section
        ],
      );

      expect(tester.takeException(), null);
      expect(find.textContaining('已导入 2 条线路'), findsOneWidget);
      expect(find.textContaining('定制线路 01'), findsOneWidget);
      expect(find.textContaining('已导入 1 条线路'), findsNWidgets(2));
    },
  );

  testWidgets(
    'a category with zero matching nodes shows the honest empty state, '
    'not a fabricated count',
    (tester) async {
      await pump(tester, nodes: [node(name: '香港 01')]);

      expect(tester.takeException(), null);
      expect(find.text('当前套餐暂未包含此类线路'), findsNWidgets(3));
      expect(find.textContaining('已导入'), findsNothing);
    },
  );

  testWidgets(
    '去连接 switches the active page to Connect (VipView as a bare root — '
    'the desktop nav-rail-tab reachability path, where canPop() is false)',
    (tester) async {
      final container = await pump(
        tester,
        nodes: [node(name: '定制线路 01', category: NodeCategory.vip)],
      );

      await tester.tap(find.text('去连接').first);
      await tester.pump();

      expect(
        container.read(currentPageLabelProvider),
        PageLabel.connect,
      );
    },
  );

  testWidgets(
    '去连接 also pops back when VipView was pushed on top of another '
    'screen (the mobile/narrow-width reachability path via AccountView, '
    'where canPop() is true) — regression coverage for the half of '
    '_goToConnect a review found untested',
    (tester) async {
      final container = ProviderContainer(
        overrides: [
          hgfastNodesProvider.overrideWith(
            () => _TestHgfastNodes(
              HgfastNodesState(
                phase: HgfastNodesPhase.loaded,
                catalog: NodeCatalog(
                  automatic: true,
                  groups: {
                    'test': [
                      node(name: '定制线路 01', category: NodeCategory.vip),
                    ],
                  },
                ),
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
          child: MaterialApp(
            localizationsDelegates: const [
              AppLocalizations.delegate,
              GlobalMaterialLocalizations.delegate,
              GlobalCupertinoLocalizations.delegate,
              GlobalWidgetsLocalizations.delegate,
            ],
            supportedLocales: AppLocalizations.delegate.supportedLocales,
            home: Builder(
              builder: (context) => Scaffold(
                body: Center(
                  child: TextButton(
                    onPressed: () => Navigator.of(context).push(
                      MaterialPageRoute(builder: (_) => const VipView()),
                    ),
                    child: const Text('open vip'),
                  ),
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pump();

      await tester.tap(find.text('open vip'));
      await tester.pumpAndSettle();
      expect(find.byType(VipView), findsOneWidget);

      await tester.tap(find.text('去连接').first);
      await tester.pumpAndSettle();

      expect(
        container.read(currentPageLabelProvider),
        PageLabel.connect,
      );
      // The push is gone — back at the underlying "open vip" screen —
      // proving the pop() half of _goToConnect actually ran, not just the
      // toPage() half.
      expect(find.byType(VipView), findsNothing);
      expect(find.text('open vip'), findsOneWidget);
    },
  );
}

class _TestApp extends StatelessWidget {
  final Widget child;

  const _TestApp({required this.child});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      localizationsDelegates: const [
        AppLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
      ],
      supportedLocales: AppLocalizations.delegate.supportedLocales,
      home: child,
    );
  }
}

class _TestHgfastNodes extends HgfastNodes {
  _TestHgfastNodes(this.initial);

  final HgfastNodesState initial;

  @override
  HgfastNodesState build() => initial;
}
