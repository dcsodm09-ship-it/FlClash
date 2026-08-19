// Pins DocsView's real, working local search/filter over its static
// reference content — there is no docs/CMS backend anywhere in this
// codebase (see the file-level doc comment in docs_view.dart), so the
// content itself is real static copy, not fabricated business data; this
// only pins that the search/filter interaction actually works.
import 'package:fl_clash/l10n/l10n.dart';
import 'package:fl_clash/pages/docs/docs_view.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  Future<void> pump(WidgetTester tester) async {
    await tester.pumpWidget(const _TestApp(child: DocsView()));
    await tester.pump();
  }

  testWidgets('defaults to the first category and shows its entries', (
    tester,
  ) async {
    await pump(tester);

    expect(tester.takeException(), null);
    expect(find.text('如何开始使用 HGFAST'), findsOneWidget);
    expect(find.text('首次连接指南（三端通用）'), findsOneWidget);
    // A different category's entries must not leak into the default view.
    expect(find.text('连接失败怎么办'), findsNothing);
  });

  testWidgets('switching category chips shows that category\'s entries only', (
    tester,
  ) async {
    await pump(tester);

    await tester.tap(find.text('节点与线路'));
    await tester.pump();

    expect(find.text('VIP 专区 / 独享 IP / 住宅 IP 是什么'), findsOneWidget);
    expect(find.text('如何选择最优节点'), findsOneWidget);
    expect(find.text('如何开始使用 HGFAST'), findsNothing);
  });

  testWidgets(
    'searching overrides the category filter and searches every category',
    (tester) async {
      await pump(tester);

      await tester.enterText(find.byType(TextField), '设备数超限');
      await tester.pump();

      expect(find.text('设备数超限怎么办'), findsOneWidget);
      // This entry belongs to 账号与套餐, not the default 新手入门 category —
      // proves search isn't scoped to whatever chip was selected before.
      expect(find.text('如何开始使用 HGFAST'), findsNothing);
    },
  );

  testWidgets('a query matching nothing shows the honest empty state', (
    tester,
  ) async {
    await pump(tester);

    await tester.enterText(find.byType(TextField), '这是一个不存在的关键词zzz');
    await tester.pump();

    expect(find.text('没有找到相关内容'), findsOneWidget);
  });

  testWidgets('tapping a FAQ card expands it to show the real answer', (
    tester,
  ) async {
    await pump(tester);

    expect(find.text('登录账号后，在"连接"页选择一个节点并点击中间的电源按钮即可开始连接。系统会自动选择延迟最低的节点，也可以手动切换。'), findsNothing);

    await tester.tap(find.text('如何开始使用 HGFAST'));
    await tester.pump();

    expect(find.text('登录账号后，在"连接"页选择一个节点并点击中间的电源按钮即可开始连接。系统会自动选择延迟最低的节点，也可以手动切换。'), findsOneWidget);
  });
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
