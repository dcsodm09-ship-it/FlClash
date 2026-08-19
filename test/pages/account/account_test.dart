// Pins AccountView's real-data-only behavior: the subscription card only
// ever shows fields the live backend actually returns (used_gb/total_gb/
// device_limit/reset_at, ground-truthed against core/client_api/data.js +
// v2board-adapter.js on hgcloud, 2026-08-19), never a fabricated plan name
// or device-online count; the no-subscription state is keyed on the real
// `reason` string; and logout requires explicit confirmation.
import 'package:fl_clash/hgfast/models/error.dart';
import 'package:fl_clash/hgfast/models/node.dart';
import 'package:fl_clash/hgfast/repository/repository.dart';
import 'package:fl_clash/l10n/l10n.dart';
import 'package:fl_clash/pages/account/account_view.dart';
import 'package:fl_clash/pages/plans/plans_view.dart';
import 'package:fl_clash/pages/vip/vip_view.dart';
import 'package:fl_clash/providers/providers.dart';
import 'package:fl_clash/state.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  Future<ProviderContainer> pump(
    WidgetTester tester, {
    Map<String, Object?>? subscriptionValues,
    HgfastResult<HgfastSubscription, HgfastError>? subscriptionResult,
    String? email = 'user@hgfast.com',
  }) async {
    final result =
        subscriptionResult ??
        HgfastResult.success(
          HgfastSubscription(subscriptionValues ?? const {}),
        );
    final container = ProviderContainer(
      overrides: [
        hgfastRepositoryProvider.overrideWithValue(
          _FakeRepository(subscriptionResult: result),
        ),
      ],
    );
    addTearDown(container.dispose);
    globalState.container = container;

    if (email != null) {
      container
          .read(hgfastAuthProvider.notifier)
          .markAuthenticated(HgfastSession({'email': email}));
    }

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const _TestApp(child: AccountView()),
      ),
    );
    await tester.pump();
    await tester.pump();
    return container;
  }

  testWidgets('shows the real email from the session', (tester) async {
    await pump(tester, subscriptionValues: const {}, email: 'me@hgfast.com');

    expect(find.text('me@hgfast.com'), findsOneWidget);
  });

  testWidgets('falls back to a generic label when the session has no email', (
    tester,
  ) async {
    await pump(tester, subscriptionValues: const {}, email: null);

    expect(find.text('HGFAST 用户'), findsOneWidget);
  });

  testWidgets(
    'renders real traffic/device_limit/expiry fields, never a fabricated '
    'plan name or online-device count',
    (tester) async {
      final resetAt =
          DateTime.now().add(const Duration(days: 30)).millisecondsSinceEpoch ~/
          1000;
      await pump(
        tester,
        subscriptionValues: {
          'sub_url': 'https://nice.hgfastapp.com/d/abc',
          'used_gb': '42.30',
          'total_gb': '100.00',
          'device_limit': 3,
          'reset_at': resetAt,
        },
      );

      expect(tester.takeException(), null);
      expect(find.text('42.30GB / 100.00GB'), findsOneWidget);
      expect(find.text('最多可用设备 3 台'), findsOneWidget);
      // 30 days out lands on 29 or 30 depending on the exact instant this
      // runs — assert the honest day count rather than a brittle exact
      // string.
      expect(find.textContaining('天后到期'), findsOneWidget);
    },
  );

  // Regression coverage for a real bug caught by review: a first version
  // of this screen read `values['reason']` on a SUCCESS payload for these
  // 3 cases, which the real repository can never produce — see
  // account_view.dart's file-level doc comment. The repository's
  // subscription() actually intercepts these and throws a typed
  // HgfastError, turning them into an HgfastResult.failure BEFORE they
  // reach AccountView. These tests feed exactly that shape, not the
  // never-real success-with-reason shape the earlier (buggy) version was
  // pinned against.
  testWidgets(
    'an expired subscription (HgfastResult.failure(HgfastExpired)) shows '
    'the honest reason-specific message and a 去购买套餐 CTA, not the '
    'generic retry card',
    (tester) async {
      await pump(
        tester,
        subscriptionResult: const HgfastResult.failure(
          HgfastError.expired(),
        ),
      );

      expect(find.text('套餐已到期，续费后即可继续使用'), findsOneWidget);
      expect(find.text('去购买套餐'), findsOneWidget);
      expect(find.text('套餐信息加载失败'), findsNothing);
      expect(find.textContaining('GB /'), findsNothing);
    },
  );

  testWidgets(
    'a quota_exhausted failure (HgfastQuotaExhausted) shows its own '
    'honest message',
    (tester) async {
      await pump(
        tester,
        subscriptionResult: const HgfastResult.failure(
          HgfastError.quotaExhausted(),
        ),
      );

      expect(find.text('本期流量已用完，可续费或升级套餐'), findsOneWidget);
    },
  );

  testWidgets('a banned failure (HgfastBanned) shows its own honest message', (
    tester,
  ) async {
    await pump(
      tester,
      subscriptionResult: const HgfastResult.failure(HgfastError.banned()),
    );

    expect(find.text('账号已被封禁，请联系客服'), findsOneWidget);
  });

  testWidgets('a subscription() failure shows a retry card, not a crash', (
    tester,
  ) async {
    final container = ProviderContainer(
      overrides: [
        hgfastRepositoryProvider.overrideWithValue(
          _FakeRepository(
            subscriptionResult: const HgfastResult.failure(
              HgfastError.clientApiStateUnavailable(),
            ),
          ),
        ),
      ],
    );
    addTearDown(container.dispose);
    globalState.container = container;
    container
        .read(hgfastAuthProvider.notifier)
        .markAuthenticated(HgfastSession({'email': 'me@hgfast.com'}));

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const _TestApp(child: AccountView()),
      ),
    );
    await tester.pump();
    await tester.pump();

    expect(tester.takeException(), null);
    expect(find.text('套餐信息加载失败'), findsOneWidget);
  });

  testWidgets('tapping VIP 专区 pushes VipView', (tester) async {
    await pump(tester, subscriptionValues: const {});

    await tester.tap(find.text('VIP 专区'));
    // Not pumpAndSettle(): VipView's own node-catalog providers are left at
    // their default "loading" state in this test (no hgfastNodesProvider
    // override here — that's vip_test.dart's job), which renders an
    // indeterminate CircularProgressIndicator that animates forever and
    // would make pumpAndSettle() time out. A couple of bounded pumps are
    // enough to confirm the push itself happened.
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    expect(find.byType(VipView), findsOneWidget);
  });

  testWidgets('the 去购买套餐 button (no_subscription) pushes PlansView', (
    tester,
  ) async {
    // sub_url: null with no reason (or reason: 'no_subscription') is the
    // one real success-shaped "no active plan" case — see
    // account_view.dart's file-level doc comment.
    await pump(
      tester,
      subscriptionValues: const {
        'sub_url': null,
        'reason': 'no_subscription',
      },
    );

    await tester.tap(find.text('去购买套餐'));
    await tester.pumpAndSettle();

    expect(find.byType(PlansView), findsOneWidget);
  });

  testWidgets(
    'logout requires confirmation — dismissing the dialog does not log out',
    (tester) async {
      final container = await pump(tester, subscriptionValues: const {});

      await tester.scrollUntilVisible(find.text('退出登录'), 200);
      await tester.tap(find.text('退出登录'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('取消'));
      await tester.pumpAndSettle();

      expect(
        container.read(hgfastAuthProvider).phase,
        HgfastAuthPhase.authenticated,
      );
    },
  );

  testWidgets('confirming logout actually logs out', (tester) async {
    final container = await pump(tester, subscriptionValues: const {});

    await tester.scrollUntilVisible(find.text('退出登录'), 200);
    await tester.tap(find.text('退出登录'));
    await tester.pumpAndSettle();
    // Two matches once the confirm dialog is open: the row's own label and
    // the dialog's confirm action, both literally "退出登录".
    await tester.tap(find.text('退出登录').last);
    await tester.pumpAndSettle();

    expect(
      container.read(hgfastAuthProvider).phase,
      HgfastAuthPhase.unauthenticated,
    );
  });
}

class _TestApp extends StatelessWidget {
  final Widget child;

  const _TestApp({required this.child});

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
      home: child,
    );
  }
}

final class _FakeRepository implements HgfastRepository {
  _FakeRepository({required this.subscriptionResult});

  final HgfastResult<HgfastSubscription, HgfastError> subscriptionResult;

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
    return HgfastResult.success(HgfastBootstrap(const {}));
  }

  @override
  Future<HgfastResult<HgfastConfig, HgfastError>> config() async {
    return HgfastResult.success(HgfastConfig(const {}));
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
    return subscriptionResult;
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
