// Pins two invariants flagged in review as high-risk and previously
// uncovered: (1) the 抽奖 (prize draw) entry must default to hidden on every
// lotteryStatus() response shape except an explicit `true`, and (2)
// InviteView must render real reward_cents-as-currency / server-issued code
// data, and must not crash on malformed invite record entries.
import 'package:fl_clash/hgfast/models/error.dart';
import 'package:fl_clash/hgfast/models/node.dart';
import 'package:fl_clash/hgfast/repository/repository.dart';
import 'package:fl_clash/l10n/l10n.dart';
import 'package:fl_clash/pages/invite/invite_providers.dart';
import 'package:fl_clash/pages/invite/invite_view.dart';
import 'package:fl_clash/providers/providers.dart';
import 'package:fl_clash/state.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('hgfastLotteryEnabledProvider defaults to hidden', () {
    Future<bool> resolve(_FakeRepository repository) async {
      final container = ProviderContainer(
        overrides: [hgfastRepositoryProvider.overrideWithValue(repository)],
      );
      addTearDown(container.dispose);
      return container.read(hgfastLotteryEnabledProvider.future);
    }

    test('hidden when lotteryStatus() returns no recognizable field', () async {
      expect(
        await resolve(_FakeRepository(lotteryValues: const {})),
        isFalse,
      );
    });

    test('hidden when feature_flags.lottery is explicitly false', () async {
      expect(
        await resolve(
          _FakeRepository(
            lotteryValues: const {
              'feature_flags': {'lottery': false},
            },
          ),
        ),
        isFalse,
      );
    });

    test('hidden when the endpoint fails outright', () async {
      expect(
        await resolve(_FakeRepository(lotteryFails: true)),
        isFalse,
      );
    });

    test('hidden when a recognized field is present but not a bool', () async {
      expect(
        await resolve(
          _FakeRepository(lotteryValues: const {'enabled': 'yes'}),
        ),
        isFalse,
      );
    });

    test('only visible on an explicit true', () async {
      expect(
        await resolve(_FakeRepository(lotteryValues: const {'enabled': true})),
        isTrue,
      );
    });
  });

  group('InviteView', () {
    Future<void> pumpAuthenticated(
      WidgetTester tester,
      ProviderContainer container,
    ) async {
      globalState.container = container;
      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: const _TestApp(child: InviteView()),
        ),
      );
      // Reach the authenticated branch the same way real login does, rather
      // than assuming a particular initial phase.
      container
          .read(hgfastAuthProvider.notifier)
          .markAuthenticated(HgfastSession({}));
      await tester.pump();
      await tester.pump();
    }

    testWidgets('renders reward_cents as currency and the real HG code', (
      tester,
    ) async {
      final container = ProviderContainer(
        overrides: [
          hgfastRepositoryProvider.overrideWithValue(
            _FakeRepository(
              inviteValues: const {
                'code': 'HG000023',
                'invited_count': 4,
                'reward_cents': 1250,
                'records': [],
              },
            ),
          ),
        ],
      );
      addTearDown(container.dispose);
      await pumpAuthenticated(tester, container);

      expect(find.text('HG000023'), findsOneWidget);
      expect(find.text('¥12.50'), findsOneWidget);
      expect(find.text('4'), findsOneWidget);
      // Never a fabricated GB/traffic reward label.
      expect(find.textContaining('GB'), findsNothing);
    });

    testWidgets('skips malformed record entries instead of crashing', (
      tester,
    ) async {
      final container = ProviderContainer(
        overrides: [
          hgfastRepositoryProvider.overrideWithValue(
            _FakeRepository(
              inviteValues: const {
                'code': 'HG000099',
                'invited_count': 1,
                'reward_cents': 0,
                'records': [
                  'not a map',
                  42,
                  {'invited_user': 'alice', 'reward_cents': 500},
                ],
              },
            ),
          ),
        ],
      );
      addTearDown(container.dispose);
      await pumpAuthenticated(tester, container);

      expect(tester.takeException(), null);
      expect(find.text('alice'), findsOneWidget);
      expect(find.text('+¥5.00'), findsOneWidget);
    });

    testWidgets('lottery entry stays hidden even with a cached invite', (
      tester,
    ) async {
      final container = ProviderContainer(
        overrides: [
          hgfastRepositoryProvider.overrideWithValue(
            _FakeRepository(
              inviteValues: const {
                'code': 'HG000001',
                'invited_count': 0,
                'reward_cents': 0,
                'records': [],
              },
              lotteryValues: const {},
            ),
          ),
        ],
      );
      addTearDown(container.dispose);
      await pumpAuthenticated(tester, container);
      // Let the autoDispose lottery FutureProvider settle.
      await tester.pump();

      expect(find.text('参与抽奖赢取奖励'), findsNothing);
    });
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
  _FakeRepository({
    this.inviteValues = const {},
    this.lotteryValues = const {},
    this.lotteryFails = false,
  });

  final Map<String, Object?> inviteValues;
  final Map<String, Object?> lotteryValues;
  final bool lotteryFails;

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
    return HgfastResult.success(HgfastSubscription(const {}));
  }

  @override
  Future<HgfastResult<HgfastTraffic, HgfastError>> traffic() async {
    return HgfastResult.success(HgfastTraffic(const {}));
  }

  @override
  Future<HgfastResult<HgfastInvite, HgfastError>> invite() async {
    return HgfastResult.success(HgfastInvite(inviteValues));
  }

  @override
  Future<HgfastResult<HgfastLotteryStatus, HgfastError>> lotteryStatus() async {
    if (lotteryFails) {
      return const HgfastResult.failure(HgfastError.c1('E_NETWORK'));
    }
    return HgfastResult.success(HgfastLotteryStatus(lotteryValues));
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
