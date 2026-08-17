import 'package:fl_clash/common/common.dart';
import 'package:fl_clash/common/theme.dart';
import 'package:fl_clash/enum/enum.dart';
import 'package:fl_clash/l10n/l10n.dart';
import 'package:fl_clash/providers/app.dart';
import 'package:fl_clash/state.dart';
import 'package:fl_clash/views/connect/item.dart';
import 'package:fl_clash/views/views.dart';
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

    final container = ProviderContainer();
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

      final container = ProviderContainer();
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
