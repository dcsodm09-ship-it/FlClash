// Pins support_view.dart's defensive AI-agent URL resolution (never a
// fabricated URL, config-shape tolerant) and the fallback-contacts render
// path — the one screen named in the original P1-3 finding that was still
// left uncovered after the first pass.
import 'package:fl_clash/hgfast/models/error.dart';
import 'package:fl_clash/hgfast/models/node.dart';
import 'package:fl_clash/hgfast/repository/repository.dart';
import 'package:fl_clash/l10n/l10n.dart';
import 'package:fl_clash/pages/support/support_view.dart';
import 'package:fl_clash/providers/providers.dart';
import 'package:fl_clash/state.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  Future<void> pump(
    WidgetTester tester, {
    Map<String, Object?> configValues = const {},
    List<Map<String, Object?>> contacts = const [],
  }) async {
    final container = ProviderContainer(
      overrides: [
        hgfastRepositoryProvider.overrideWithValue(
          _FakeRepository(configValues: configValues, contacts: contacts),
        ),
      ],
    );
    addTearDown(container.dispose);
    globalState.container = container;

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const _TestApp(child: SupportView()),
      ),
    );
    await tester.pump();
    await tester.pump();
  }

  testWidgets(
    'no recognizable ai_agent field falls back to contacts, never a fake URL',
    (tester) async {
      await pump(
        tester,
        configValues: const {'unrelated': 'field'},
        contacts: const [
          {'label': 'Telegram', 'value': '@example'},
        ],
      );

      expect(tester.takeException(), null);
      expect(find.text('AI 客服入口暂未从服务端下发，请先使用下方联系方式。'), findsOneWidget);
      expect(find.text('Telegram'), findsOneWidget);
      // The "打开 AI 客服" button must be disabled (onOpen == null) rather
      // than wired to a fabricated URL.
      final button = tester.widget<FilledButton>(
        find.widgetWithText(FilledButton, '打开 AI 客服'),
      );
      expect(button.onPressed, isNull);
    },
  );

  testWidgets('resolves a real ai_agent.url and enables the open button', (
    tester,
  ) async {
    await pump(
      tester,
      configValues: const {
        'ai_agent': {'url': 'https://support.example.com/agent'},
      },
    );

    expect(tester.takeException(), null);
    final button = tester.widget<FilledButton>(
      find.widgetWithText(FilledButton, '打开 AI 客服'),
    );
    expect(button.onPressed, isNotNull);
  });

  testWidgets(
    'also resolves under the client_webview container / webview_url key',
    (tester) async {
      await pump(
        tester,
        configValues: const {
          'client_webview': {'webview_url': 'https://support.example.com/w'},
        },
      );

      expect(tester.takeException(), null);
      final button = tester.widget<FilledButton>(
        find.widgetWithText(FilledButton, '打开 AI 客服'),
      );
      expect(button.onPressed, isNotNull);
    },
  );

  testWidgets('a blank url string does not count as resolved', (
    tester,
  ) async {
    await pump(
      tester,
      configValues: const {
        'ai_agent': {'url': '   '},
      },
    );

    expect(tester.takeException(), null);
    final button = tester.widget<FilledButton>(
      find.widgetWithText(FilledButton, '打开 AI 客服'),
    );
    expect(button.onPressed, isNull);
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

final class _FakeRepository implements HgfastRepository {
  _FakeRepository({required this.configValues, required this.contacts});

  final Map<String, Object?> configValues;
  final List<Map<String, Object?>> contacts;

  @override
  Future<HgfastResult<HgfastSession, HgfastError>> login({
    required String credential,
    required String password,
  }) async {
    return const HgfastResult.failure(HgfastError.authFailed());
  }

  @override
  Future<HgfastResult<void, HgfastError>> logout() async {
    return const HgfastResult.success(null);
  }

  @override
  Future<HgfastResult<HgfastSession?, HgfastError>> restoreSession() async {
    return const HgfastResult.success(null);
  }

  @override
  Future<HgfastResult<HgfastBootstrap, HgfastError>> bootstrap() async {
    return HgfastResult.success(
      HgfastBootstrap({'fallback_contacts': contacts}),
    );
  }

  @override
  Future<HgfastResult<HgfastConfig, HgfastError>> config() async {
    return HgfastResult.success(HgfastConfig(configValues));
  }

  @override
  Future<HgfastResult<HgfastAnnouncementCatalog, HgfastError>>
  announcements() async {
    return HgfastResult.success(HgfastAnnouncementCatalog(const {}));
  }

  @override
  Future<HgfastResult<HgfastPlanCatalog, HgfastError>> plans() async {
    return HgfastResult.success(HgfastPlanCatalog(const {}));
  }

  @override
  Future<HgfastResult<NodeCatalog, HgfastError>> nodes() async {
    return HgfastResult.success(NodeCatalog(automatic: true, groups: const {}));
  }

  @override
  Future<HgfastResult<HgfastSubscription, HgfastError>> subscription() async {
    return HgfastResult.success(HgfastSubscription(const {}));
  }

  @override
  Future<HgfastResult<HgfastTraffic, HgfastError>> traffic() async {
    return HgfastResult.success(HgfastTraffic(const {}));
  }

  @override
  Future<HgfastResult<HgfastInvite, HgfastError>> invite() async {
    return HgfastResult.success(HgfastInvite(const {}));
  }

  @override
  Future<HgfastResult<HgfastLotteryStatus, HgfastError>> lotteryStatus() async {
    return HgfastResult.success(HgfastLotteryStatus(const {}));
  }

  @override
  Future<HgfastResult<HgfastAiResponse, HgfastError>> aiChat({
    required String message,
    String? model,
    HgfastJson? context,
  }) async {
    return HgfastResult.success(HgfastAiResponse(const {}));
  }

  @override
  Future<HgfastResult<HgfastOrderStatus, HgfastError>> orderStatus(
    String orderId,
  ) async {
    return HgfastResult.success(HgfastOrderStatus(const {}));
  }

  @override
  Future<HgfastResult<HgfastOrderStatus, HgfastError>> createOrder({
    required String planId,
    required String period,
    String? couponCode,
  }) async {
    return HgfastResult.success(HgfastOrderStatus(const {}));
  }
}
