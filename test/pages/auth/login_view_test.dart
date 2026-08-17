import 'package:fl_clash/hgfast/models/error.dart';
import 'package:fl_clash/hgfast/models/node.dart';
import 'package:fl_clash/hgfast/repository/repository.dart';
import 'package:fl_clash/l10n/l10n.dart';
import 'package:fl_clash/pages/auth/forgot_password_view.dart';
import 'package:fl_clash/pages/auth/login_view.dart';
import 'package:fl_clash/pages/auth/register_view.dart';
import 'package:fl_clash/providers/providers.dart';
import 'package:fl_clash/state.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('shows a validation message when fields are empty', (
    tester,
  ) async {
    final container = ProviderContainer();
    addTearDown(container.dispose);
    globalState.container = container;

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const _TestApp(child: LoginView()),
      ),
    );
    await tester.pump();

    await tester.tap(find.widgetWithText(FilledButton, '登录'));
    await tester.pump();

    expect(find.text('请输入账号和密码'), findsOneWidget);
    expect(container.read(isAuthenticatedProvider), isNull);
  });

  testWidgets('successful login flips isAuthenticatedProvider', (tester) async {
    final container = ProviderContainer(
      overrides: [
        hgfastRepositoryProvider.overrideWithValue(
          _FakeRepository(succeed: true),
        ),
        hgfastSyncActionProvider.overrideWith(() => _NoopSyncAction()),
      ],
    );
    addTearDown(container.dispose);
    globalState.container = container;

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const _TestApp(child: LoginView()),
      ),
    );
    await tester.pump();

    await tester.enterText(find.byType(TextField).first, 'user@example.com');
    await tester.enterText(find.byType(TextField).last, 'password');
    await tester.tap(find.widgetWithText(FilledButton, '登录'));
    await tester.pump();
    await tester.pump();

    expect(container.read(isAuthenticatedProvider), isTrue);
  });

  testWidgets('failed login shows the mapped error message', (tester) async {
    final container = ProviderContainer(
      overrides: [
        hgfastRepositoryProvider.overrideWithValue(
          _FakeRepository(succeed: false),
        ),
        hgfastSyncActionProvider.overrideWith(() => _NoopSyncAction()),
      ],
    );
    addTearDown(container.dispose);
    globalState.container = container;

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const _TestApp(child: LoginView()),
      ),
    );
    await tester.pump();

    await tester.enterText(find.byType(TextField).first, 'user@example.com');
    await tester.enterText(find.byType(TextField).last, 'wrong');
    await tester.tap(find.widgetWithText(FilledButton, '登录'));
    await tester.pump();
    await tester.pump();

    expect(find.text('账号或密码错误'), findsOneWidget);
    expect(find.textContaining('10.0.0.5'), findsNothing);
    expect(container.read(isAuthenticatedProvider), isFalse);
  });

  testWidgets('register entry pushes RegisterView on the root navigator', (
    tester,
  ) async {
    final container = ProviderContainer();
    addTearDown(container.dispose);
    globalState.container = container;

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const _TestApp(child: LoginView()),
      ),
    );
    await tester.pump();

    await tester.tap(find.text('还没有账号？去注册'));
    await tester.pumpAndSettle();

    expect(find.byType(RegisterView), findsOneWidget);
  });

  testWidgets('forgot-password entry pushes ForgotPasswordView', (
    tester,
  ) async {
    final container = ProviderContainer(
      overrides: [
        hgfastRepositoryProvider.overrideWithValue(
          _FakeRepository(succeed: false),
        ),
      ],
    );
    addTearDown(container.dispose);
    globalState.container = container;

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const _TestApp(child: LoginView()),
      ),
    );
    await tester.pump();

    await tester.tap(find.text('忘记密码？'));
    await tester.pumpAndSettle();

    expect(find.byType(ForgotPasswordView), findsOneWidget);
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

final class _NoopSyncAction extends HgfastSyncAction {
  @override
  void build() {}

  @override
  Future<void> syncAfterLogin() async {}

  @override
  void stopPolling() {}
}

final class _FakeRepository implements HgfastRepository {
  _FakeRepository({required this.succeed});

  final bool succeed;

  @override
  Future<HgfastResult<HgfastSession, HgfastError>> login({
    required String credential,
    required String password,
  }) async {
    if (succeed) {
      return HgfastResult.success(HgfastSession({}));
    }
    return const HgfastResult.failure(
      HgfastError.authFailed(message: 'internal: upstream 500 at 10.0.0.5'),
    );
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
      HgfastBootstrap({'fallback_contacts': const []}),
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
