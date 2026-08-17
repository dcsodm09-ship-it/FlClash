// Pins the invariants for the 购买套餐 (purchase plans) screen: real
// prices_cents-as-currency rendering, a plan only ever shows the billing
// periods it actually offers (never a fabricated full set), a genuinely
// empty /plans response renders the real empty state (not fabricated
// placeholder plans), and a gated createOrder() failure
// (WRITE_DISABLED/WRITE_NOT_IMPLEMENTED) shows the honest "not available
// yet" message rather than crashing or claiming success.
import 'package:fl_clash/hgfast/models/error.dart';
import 'package:fl_clash/hgfast/models/node.dart';
import 'package:fl_clash/hgfast/repository/repository.dart';
import 'package:fl_clash/l10n/l10n.dart';
import 'package:fl_clash/pages/plans/plans_view.dart';
import 'package:fl_clash/providers/providers.dart';
import 'package:fl_clash/state.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('PlansView', () {
    Future<void> pump(
      WidgetTester tester,
      ProviderContainer container,
    ) async {
      globalState.container = container;
      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: const _TestApp(child: PlansView()),
        ),
      );
      await tester.pump();
      await tester.pump();
    }

    testWidgets('renders real plans with correctly formatted per-period '
        'prices', (tester) async {
      final container = ProviderContainer(
        overrides: [
          hgfastRepositoryProvider.overrideWithValue(
            _FakeRepository(
              plansValues: const {
                'plans': [
                  {
                    'id': 'plan:1',
                    'name': '标准套餐',
                    'transfer_gb': 200,
                    'device_limit': 3,
                    'route_type': 'direct',
                    'prices_cents': {
                      'month': 1990,
                      'quarter': 5370,
                      'half_year': null,
                      'year': 19080,
                      'onetime': null,
                    },
                  },
                ],
              },
            ),
          ),
        ],
      );
      addTearDown(container.dispose);
      await pump(tester, container);

      expect(find.text('标准套餐'), findsOneWidget);
      expect(find.text('200 GB/月'), findsOneWidget);
      expect(find.text('最多可用设备 3 台'), findsOneWidget);
      // Correctly formatted: cents / 100, two decimal places.
      expect(find.text('月付 ¥19.90'), findsOneWidget);
      expect(find.text('季付 ¥53.70'), findsOneWidget);
      expect(find.text('年付 ¥190.80'), findsOneWidget);
    });

    testWidgets(
      'a plan with only some periods present only shows those periods',
      (tester) async {
        final container = ProviderContainer(
          overrides: [
            hgfastRepositoryProvider.overrideWithValue(
              _FakeRepository(
                plansValues: const {
                  'plans': [
                    {
                      'id': 'plan:2',
                      'name': '仅月付套餐',
                      'transfer_gb': 100,
                      'device_limit': null,
                      'prices_cents': {
                        'month': 990,
                        'quarter': null,
                        'half_year': null,
                        'year': null,
                        'onetime': null,
                      },
                    },
                  ],
                },
              ),
            ),
          ],
        );
        addTearDown(container.dispose);
        await pump(tester, container);

        expect(find.text('仅月付套餐'), findsOneWidget);
        expect(find.text('设备数不限'), findsOneWidget);
        expect(find.text('月付 ¥9.90'), findsOneWidget);
        // The absent periods must never be fabricated/shown.
        expect(find.textContaining('季付'), findsNothing);
        expect(find.textContaining('半年付'), findsNothing);
        expect(find.textContaining('年付 '), findsNothing);
        expect(find.textContaining('一次性'), findsNothing);
      },
    );

    testWidgets('an empty plans response shows the real empty state, not '
        'fabricated data', (tester) async {
      final container = ProviderContainer(
        overrides: [
          hgfastRepositoryProvider.overrideWithValue(
            _FakeRepository(plansValues: const {'plans': []}),
          ),
        ],
      );
      addTearDown(container.dispose);
      await pump(tester, container);

      expect(find.text('暂无套餐'), findsOneWidget);
      // No fabricated placeholder plan card content.
      expect(find.textContaining('GB/月'), findsNothing);
      expect(find.textContaining('¥'), findsNothing);
    });

    testWidgets(
      'purchase against a WRITE_DISABLED-shaped failure shows the honest '
      '"not yet available" message, not a crash or fake success',
      (tester) async {
        final container = ProviderContainer(
          overrides: [
            hgfastRepositoryProvider.overrideWithValue(
              _FakeRepository(
                plansValues: const {
                  'plans': [
                    {
                      'id': 'plan:3',
                      'name': '测试套餐',
                      'transfer_gb': 50,
                      'device_limit': 1,
                      'prices_cents': {'month': 500},
                    },
                  ],
                },
                createOrderResult: const HgfastResult.failure(
                  HgfastError.writeDisabled(message: '写路径未开放(gated)'),
                ),
              ),
            ),
          ],
        );
        addTearDown(container.dispose);
        await pump(tester, container);

        await tester.tap(find.text('购买'));
        await tester.pump();
        await tester.pump();

        expect(tester.takeException(), null);
        expect(find.text('购买功能暂未开放，敬请期待'), findsOneWidget);
        // Never a generic error and never a fake success.
        expect(find.text('购买失败，请稍后重试'), findsNothing);
        expect(find.text('已跳转至支付页面，请完成支付'), findsNothing);
        expect(find.text('订单已创建，等待支付结果'), findsNothing);
      },
    );

    testWidgets(
      'purchase against a WRITE_NOT_IMPLEMENTED-shaped failure also shows '
      'the honest message',
      (tester) async {
        final container = ProviderContainer(
          overrides: [
            hgfastRepositoryProvider.overrideWithValue(
              _FakeRepository(
                plansValues: const {
                  'plans': [
                    {
                      'id': 'plan:4',
                      'name': '测试套餐二',
                      'transfer_gb': 50,
                      'device_limit': 1,
                      'prices_cents': {'month': 500},
                    },
                  ],
                },
                createOrderResult: const HgfastResult.failure(
                  HgfastError.writeNotImplemented(
                    message: 'order 须经面板 authed req.user 入原 order/save',
                  ),
                ),
              ),
            ),
          ],
        );
        addTearDown(container.dispose);
        await pump(tester, container);

        await tester.tap(find.text('购买'));
        await tester.pump();
        await tester.pump();

        expect(tester.takeException(), null);
        expect(find.text('购买功能暂未开放，敬请期待'), findsOneWidget);
      },
    );
  });
}

class _TestApp extends StatelessWidget {
  final Widget child;

  const _TestApp({required this.child});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      // Pinned explicitly: this screen's own strings are all Chinese, and
      // the test environment's resolved default locale is 'en', which would
      // otherwise make the localized nullTip() empty-state assertion below
      // flaky/host-dependent.
      locale: const Locale('zh'),
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
    this.plansValues = const {},
    this.createOrderResult = const HgfastResult.failure(
      HgfastError.writeDisabled(),
    ),
  });

  final Map<String, Object?> plansValues;
  final HgfastResult<HgfastOrderStatus, HgfastError> createOrderResult;

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
    return HgfastResult.success(HgfastPlanCatalog(plansValues));
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
    return createOrderResult;
  }
}
