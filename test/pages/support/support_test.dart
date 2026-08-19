// Pins support_view.dart's real native AI-chat UI (calls the actual
// authenticated aiChat() endpoint, never a fabricated reply) and its
// defensive exception handling — replacing the previous version's tests,
// which pinned an external-URL-resolution design this screen no longer
// uses (see the doc comment at the top of support_view.dart for why that
// design could never resolve a real URL in production).
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
  Future<ProviderContainer> pump(
    WidgetTester tester, {
    HgfastResult<HgfastAiResponse, HgfastError>? aiChatResult,
    bool throwOnAiChat = false,
    List<Map<String, Object?>> contacts = const [],
  }) async {
    final container = ProviderContainer(
      overrides: [
        hgfastRepositoryProvider.overrideWithValue(
          _FakeRepository(
            aiChatResult:
                aiChatResult ??
                HgfastResult.success(
                  HgfastAiResponse({'reply': '这是一条测试回复'}),
                ),
            throwOnAiChat: throwOnAiChat,
            contacts: contacts,
          ),
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
    return container;
  }

  testWidgets('shows a greeting message on open, calls no repository method', (
    tester,
  ) async {
    await pump(tester);

    expect(tester.takeException(), null);
    expect(find.text('你好，我是 HGFAST 智能客服，请描述你遇到的问题。'), findsOneWidget);
  });

  testWidgets(
    'sending a message shows the user bubble then a real aiChat() reply, '
    'never a fabricated one',
    (tester) async {
      await pump(
        tester,
        aiChatResult: HgfastResult.success(
          HgfastAiResponse({'reply': '你的节点问题已收到，请稍等。'}),
        ),
      );

      await tester.enterText(find.byType(TextField), '我的节点连不上');
      await tester.tap(find.byIcon(Icons.send_rounded));
      await tester.pump();
      await tester.pump();

      expect(find.text('我的节点连不上'), findsOneWidget);
      expect(find.text('你的节点问题已收到，请稍等。'), findsOneWidget);
    },
  );

  testWidgets(
    'the backend stub reply (fallback:true, canned text) is rendered '
    'honestly, exactly as returned — this is the real production response '
    'shape today',
    (tester) async {
      await pump(
        tester,
        aiChatResult: HgfastResult.success(
          HgfastAiResponse({
            'reply': 'AI 客服暂未开放，请通过在线客服联系人工',
            'actions': [],
            'fallback': true,
          }),
        ),
      );

      await tester.enterText(find.byType(TextField), '你好');
      await tester.tap(find.byIcon(Icons.send_rounded));
      await tester.pump();
      await tester.pump();

      expect(find.text('AI 客服暂未开放，请通过在线客服联系人工'), findsOneWidget);
    },
  );

  testWidgets('a mapped failure shows the honest error message, no fake reply', (
    tester,
  ) async {
    await pump(
      tester,
      aiChatResult: const HgfastResult.failure(
        HgfastError.clientApiStateUnavailable(),
      ),
    );

    await tester.enterText(find.byType(TextField), '你好');
    await tester.tap(find.byIcon(Icons.send_rounded));
    await tester.pump();
    await tester.pump();

    expect(find.text('服务暂不可用，请稍后再试'), findsOneWidget);
  });

  testWidgets(
    'an uncaught exception from aiChat() resets the send button instead of '
    'leaving it stuck (same defensive pattern as login_view.dart)',
    (tester) async {
      await pump(tester, throwOnAiChat: true);

      await tester.enterText(find.byType(TextField), '你好');
      await tester.tap(find.byIcon(Icons.send_rounded));
      await tester.pump();
      await tester.pump();

      expect(find.text('发送失败，请稍后再试'), findsOneWidget);
      // The send icon (not a stuck spinner) must be back.
      expect(find.byIcon(Icons.send_rounded), findsOneWidget);
    },
  );

  testWidgets('an empty message does not call aiChat()', (tester) async {
    final container = ProviderContainer(
      overrides: [
        hgfastRepositoryProvider.overrideWithValue(
          _FakeRepository(
            aiChatResult: HgfastResult.success(
              HgfastAiResponse({'reply': 'should not appear'}),
            ),
            contacts: const [],
          ),
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

    await tester.tap(find.byIcon(Icons.send_rounded));
    await tester.pump();
    await tester.pump();

    final repository =
        container.read(hgfastRepositoryProvider) as _FakeRepository;
    expect(repository.aiChatCalls, 0);
    expect(find.text('should not appear'), findsNothing);
  });

  testWidgets(
    'never renders the auth screens\' macOS drag strip (regression: this '
    'screen is a real sidebar nav destination that already gets its own '
    'macOS traffic-light clearance from AppSidebarContainer — a second '
    'strip here would insert a mismatched-colored band in the content '
    'column only, reproducing the exact "横条" bug the strip was built to '
    'fix)',
    (tester) async {
      final container = ProviderContainer(
        overrides: [
          hgfastRepositoryProvider.overrideWithValue(
            _FakeRepository(
              aiChatResult: HgfastResult.success(HgfastAiResponse(const {})),
              contacts: const [],
            ),
          ),
          viewSizeProvider.overrideWithBuild((_, _) => const Size(680, 580)),
          versionProvider.overrideWithBuild((_, _) => 15),
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

      expect(tester.takeException(), null);
      expect(
        find.byKey(const ValueKey('hgfastAuthWindowDragStrip')),
        findsNothing,
      );
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

final class _FakeRepository implements HgfastRepository {
  _FakeRepository({
    required this.aiChatResult,
    required this.contacts,
    this.throwOnAiChat = false,
  });

  final HgfastResult<HgfastAiResponse, HgfastError> aiChatResult;
  final List<Map<String, Object?>> contacts;
  final bool throwOnAiChat;
  int aiChatCalls = 0;

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
    return HgfastResult.success(HgfastConfig({}));
  }

  @override
  Future<HgfastResult<HgfastAnnouncementCatalog, HgfastError>>
  announcements() async {
    return HgfastResult.success(HgfastAnnouncementCatalog({}));
  }

  @override
  Future<HgfastResult<HgfastPlanCatalog, HgfastError>> plans() async {
    return HgfastResult.success(HgfastPlanCatalog({}));
  }

  @override
  Future<HgfastResult<NodeCatalog, HgfastError>> nodes() async {
    return HgfastResult.success(NodeCatalog(automatic: true, groups: const {}));
  }

  @override
  Future<HgfastResult<HgfastSubscription, HgfastError>> subscription() async {
    return HgfastResult.success(HgfastSubscription({}));
  }

  @override
  Future<HgfastResult<HgfastTraffic, HgfastError>> traffic() async {
    return HgfastResult.success(HgfastTraffic({}));
  }

  @override
  Future<HgfastResult<HgfastInvite, HgfastError>> invite() async {
    return HgfastResult.success(HgfastInvite({}));
  }

  @override
  Future<HgfastResult<HgfastLotteryStatus, HgfastError>> lotteryStatus() async {
    return HgfastResult.success(HgfastLotteryStatus({}));
  }

  @override
  Future<HgfastResult<HgfastAiResponse, HgfastError>> aiChat({
    required String message,
    String? model,
    HgfastJson? context,
  }) async {
    aiChatCalls++;
    if (throwOnAiChat) {
      throw StateError('simulated uncaught failure below the repository');
    }
    return aiChatResult;
  }

  @override
  Future<HgfastResult<HgfastOrderStatus, HgfastError>> orderStatus(
    String orderId,
  ) async {
    return HgfastResult.success(HgfastOrderStatus({}));
  }

  @override
  Future<HgfastResult<HgfastOrderStatus, HgfastError>> createOrder({
    required String planId,
    required String period,
    String? couponCode,
  }) async {
    return HgfastResult.success(HgfastOrderStatus({}));
  }

  @override
  Future<HgfastResult<HgfastJson, HgfastError>> requestPasswordReset({
    required String email,
  }) async {
    return const HgfastResult.success(<String, Object?>{});
  }

  @override
  Future<HgfastResult<HgfastJson, HgfastError>> confirmPasswordReset({
    required String email,
    required String code,
    required String newPassword,
  }) async {
    return const HgfastResult.success(<String, Object?>{});
  }
}
