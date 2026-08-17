import 'package:fl_clash/common/constant.dart';
import 'package:fl_clash/hgfast/models/error.dart';
import 'package:fl_clash/hgfast/models/node.dart';
import 'package:fl_clash/hgfast/repository/repository.dart';
import 'package:fl_clash/providers/providers.dart';
import 'package:fl_clash/state.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('GlobalState exposes a fallback accent color before plugin startup', () {
    expect(GlobalState().accentColor, const Color(defaultPrimaryColor));
  });

  test('isAuthenticatedProvider starts unresolved until restore completes', () {
    final container = ProviderContainer();
    addTearDown(container.dispose);

    expect(container.read(isAuthenticatedProvider), isNull);
  });

  test('isAuthenticatedProvider follows hgfastAuthProvider phase', () {
    final container = ProviderContainer();
    addTearDown(container.dispose);

    container.read(hgfastAuthProvider.notifier).markAuthenticating();
    expect(container.read(isAuthenticatedProvider), isFalse);

    container
        .read(hgfastAuthProvider.notifier)
        .markAuthenticated(HgfastSession({}));
    expect(container.read(isAuthenticatedProvider), isTrue);

    container.read(hgfastAuthProvider.notifier).markUnauthenticated();
    expect(container.read(isAuthenticatedProvider), isFalse);
  });

  test('launchUrlGuardProvider defaults to allowing every url', () async {
    final container = ProviderContainer();
    addTearDown(container.dispose);

    final guard = container.read(launchUrlGuardProvider);

    expect(await guard('https://hgfastapp.com'), isTrue);
  });

  testWidgets(
    'handleSessionExpired pops to the first route, drops the session and clears auth state',
    (tester) async {
      final repository = _TrackingRepository();
      final container = ProviderContainer(
        overrides: [hgfastRepositoryProvider.overrideWithValue(repository)],
      );
      addTearDown(container.dispose);
      globalState.container = container;
      container
          .read(hgfastAuthProvider.notifier)
          .markAuthenticated(HgfastSession({}));

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: MaterialApp(
            navigatorKey: globalState.navigatorKey,
            home: Builder(
              builder: (context) {
                return TextButton(
                  onPressed: () {
                    Navigator.of(context).push(
                      MaterialPageRoute(builder: (_) => const Text('pushed')),
                    );
                  },
                  child: const Text('push'),
                );
              },
            ),
          ),
        ),
      );
      await tester.pump();

      await tester.tap(find.text('push'));
      await tester.pumpAndSettle();
      expect(find.text('pushed'), findsOneWidget);

      globalState.handleSessionExpired();
      await tester.pumpAndSettle();

      expect(find.text('pushed'), findsNothing);
      expect(find.text('push'), findsOneWidget);
      expect(container.read(isAuthenticatedProvider), isFalse);
      expect(repository.logoutCalled, isTrue);
    },
  );
}

final class _TrackingRepository implements HgfastRepository {
  bool logoutCalled = false;

  @override
  Future<HgfastResult<HgfastSession, HgfastError>> login({
    required String credential,
    required String password,
  }) async {
    return const HgfastResult.failure(HgfastError.authFailed());
  }

  @override
  Future<HgfastResult<void, HgfastError>> logout() async {
    logoutCalled = true;
    return const HgfastResult.success(null);
  }

  @override
  Future<HgfastResult<HgfastSession?, HgfastError>> restoreSession() async {
    return const HgfastResult.success(null);
  }

  @override
  Future<HgfastResult<HgfastBootstrap, HgfastError>> bootstrap() async {
    return HgfastResult.success(HgfastBootstrap({}));
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
}
