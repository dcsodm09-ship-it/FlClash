import 'package:fl_clash/hgfast/models/error.dart';
import 'package:fl_clash/hgfast/models/node.dart';
import 'package:fl_clash/hgfast/repository/repository.dart';
import 'package:fl_clash/l10n/l10n.dart';
import 'package:fl_clash/pages/auth/forgot_password_view.dart';
import 'package:fl_clash/providers/providers.dart';
import 'package:fl_clash/state.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('shows the generic fallback when bootstrap has no contacts', (
    tester,
  ) async {
    final container = ProviderContainer(
      overrides: [
        hgfastRepositoryProvider.overrideWithValue(
          _FakeRepository(contacts: const []),
        ),
      ],
    );
    addTearDown(container.dispose);
    globalState.container = container;

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const _TestApp(child: ForgotPasswordView()),
      ),
    );
    await tester.pump();
    await tester.pump();

    expect(find.text('客服联系方式暂未配置，请稍后再试'), findsOneWidget);
  });

  testWidgets('renders fallback_contacts from bootstrap', (tester) async {
    final container = ProviderContainer(
      overrides: [
        hgfastRepositoryProvider.overrideWithValue(
          _FakeRepository(
            contacts: const [
              {'label': 'Telegram', 'value': '@example'},
            ],
          ),
        ),
      ],
    );
    addTearDown(container.dispose);
    globalState.container = container;

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const _TestApp(child: ForgotPasswordView()),
      ),
    );
    await tester.pump();
    await tester.pump();

    expect(find.text('Telegram'), findsOneWidget);
    expect(find.text('@example'), findsOneWidget);
  });

  testWidgets('back button pops the route', (tester) async {
    final container = ProviderContainer(
      overrides: [
        hgfastRepositoryProvider.overrideWithValue(
          _FakeRepository(contacts: const []),
        ),
      ],
    );
    addTearDown(container.dispose);
    globalState.container = container;

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: _TestApp(
          child: Builder(
            builder: (context) {
              return TextButton(
                onPressed: () {
                  Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => const ForgotPasswordView(),
                    ),
                  );
                },
                child: const Text('open forgot password'),
              );
            },
          ),
        ),
      ),
    );
    await tester.pump();

    await tester.tap(find.text('open forgot password'));
    await tester.pumpAndSettle();
    expect(find.byType(ForgotPasswordView), findsOneWidget);

    await tester.tap(find.widgetWithText(FilledButton, '返回登录'));
    await tester.pumpAndSettle();

    expect(find.byType(ForgotPasswordView), findsNothing);
    expect(find.text('open forgot password'), findsOneWidget);
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
  _FakeRepository({required this.contacts});

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
    return HgfastResult.success(NodeCatalog(automatic: true, groups: {}));
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
    return HgfastResult.success(HgfastAiResponse({}));
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
}
