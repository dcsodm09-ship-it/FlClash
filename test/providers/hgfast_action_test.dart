import 'dart:async';

import 'package:fl_clash/hgfast/models/error.dart';
import 'package:fl_clash/hgfast/models/node.dart';
import 'package:fl_clash/hgfast/repository/repository.dart';
import 'package:fl_clash/providers/action.dart';
import 'package:fl_clash/providers/app.dart';
import 'package:fl_clash/providers/hgfast/auth.dart';
import 'package:fl_clash/providers/hgfast/nodes.dart';
import 'package:fl_clash/providers/hgfast/repository.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:riverpod/riverpod.dart';

class _FakeHgfastRepository implements HgfastRepository {
  HgfastResult<HgfastSession, HgfastError> loginResult =
      const HgfastResult.failure(HgfastError.authFailed());
  HgfastResult<NodeCatalog, HgfastError> nodesResult =
      const HgfastResult.failure(HgfastError.clientApiStateUnavailable());
  Future<HgfastResult<NodeCatalog, HgfastError>> Function()? nodesCall;
  int logoutCalls = 0;
  int nodesCalls = 0;

  @override
  Future<HgfastResult<HgfastSession, HgfastError>> login({
    required String credential,
    required String password,
  }) async {
    return loginResult;
  }

  @override
  Future<HgfastResult<void, HgfastError>> logout() async {
    logoutCalls++;
    return const HgfastResult.success(null);
  }

  @override
  Future<HgfastResult<HgfastSession?, HgfastError>> restoreSession() async {
    return const HgfastResult.success(null);
  }

  @override
  Future<HgfastResult<NodeCatalog, HgfastError>> nodes() async {
    nodesCalls++;
    final call = nodesCall;
    if (call != null) {
      return call();
    }
    return nodesResult;
  }

  @override
  Future<HgfastResult<HgfastBootstrap, HgfastError>> bootstrap() {
    throw UnimplementedError();
  }

  @override
  Future<HgfastResult<HgfastConfig, HgfastError>> config() {
    throw UnimplementedError();
  }

  @override
  Future<HgfastResult<HgfastAnnouncementCatalog, HgfastError>>
  announcements() {
    throw UnimplementedError();
  }

  @override
  Future<HgfastResult<HgfastPlanCatalog, HgfastError>> plans() {
    throw UnimplementedError();
  }

  @override
  Future<HgfastResult<HgfastSubscription, HgfastError>> subscription() {
    throw UnimplementedError();
  }

  @override
  Future<HgfastResult<HgfastTraffic, HgfastError>> traffic() {
    throw UnimplementedError();
  }

  @override
  Future<HgfastResult<HgfastInvite, HgfastError>> invite() {
    throw UnimplementedError();
  }

  @override
  Future<HgfastResult<HgfastLotteryStatus, HgfastError>> lotteryStatus() {
    throw UnimplementedError();
  }

  @override
  Future<HgfastResult<HgfastAiResponse, HgfastError>> aiChat({
    required String message,
    String? model,
    HgfastJson? context,
  }) {
    throw UnimplementedError();
  }

  @override
  Future<HgfastResult<HgfastOrderStatus, HgfastError>> orderStatus(
    String orderId,
  ) {
    throw UnimplementedError();
  }

  @override
  Future<HgfastResult<HgfastOrderStatus, HgfastError>> createOrder({
    required String planId,
    required String period,
    String? couponCode,
  }) {
    throw UnimplementedError();
  }
}

void main() {
  late _FakeHgfastRepository repository;
  late ProviderContainer container;

  setUp(() {
    repository = _FakeHgfastRepository();
    container = ProviderContainer(
      overrides: [
        initProvider.overrideWithBuild((_, _) => true),
        hgfastRepositoryProvider.overrideWithValue(repository),
      ],
    );
    addTearDown(container.dispose);
  });

  test('login failure marks auth state unauthenticated with the error', () async {
    repository.loginResult = const HgfastResult.failure(
      HgfastError.authFailed(message: 'bad creds'),
    );

    final ok = await container
        .read(hgfastAuthActionProvider.notifier)
        .login(credential: 'a@b.com', password: 'x');

    expect(ok, isFalse);
    final state = container.read(hgfastAuthProvider);
    expect(state.phase, HgfastAuthPhase.unauthenticated);
    expect(state.error, isA<HgfastAuthFailed>());
  });

  test(
    'login success then a banned nodes reason marks the account blocked, '
    'not a plain empty node list',
    () async {
      repository.loginResult = HgfastResult.success(
        HgfastSession(const {'user_id': 1, 'session_id': 'sess-1'}),
      );
      repository.nodesResult = const HgfastResult.failure(
        HgfastError.banned(),
      );

      final ok = await container
          .read(hgfastAuthActionProvider.notifier)
          .login(credential: 'a@b.com', password: 'x');

      expect(ok, isTrue);
      expect(
        container.read(hgfastAuthProvider).phase,
        HgfastAuthPhase.authenticated,
      );
      final nodesState = container.read(hgfastNodesProvider);
      expect(nodesState.phase, HgfastNodesPhase.accountBlocked);
      expect(nodesState.error, isA<HgfastBanned>());
      expect(nodesState.catalog, isNull);

      container.read(hgfastSyncActionProvider.notifier).stopPolling();
    },
  );

  test('a NOT_IN_CANARY nodes response is a distinct phase from account state', () async {
    repository.loginResult = HgfastResult.success(
      HgfastSession(const {'user_id': 1, 'session_id': 'sess-1'}),
    );
    repository.nodesResult = const HgfastResult.failure(
      HgfastError.canaryDenied(HgfastResource.nodes),
    );

    await container
        .read(hgfastAuthActionProvider.notifier)
        .login(credential: 'a@b.com', password: 'x');

    final nodesState = container.read(hgfastNodesProvider);
    expect(nodesState.phase, HgfastNodesPhase.notInCanary);
    expect(nodesState.error, isA<HgfastCanaryDenied>());

    container.read(hgfastSyncActionProvider.notifier).stopPolling();
  });

  test('an AUTH_FAILED nodes response drops the session via logout', () async {
    repository.loginResult = HgfastResult.success(
      HgfastSession(const {'user_id': 1, 'session_id': 'sess-1'}),
    );
    repository.nodesResult = const HgfastResult.failure(
      HgfastError.authFailed(),
    );

    await container
        .read(hgfastAuthActionProvider.notifier)
        .login(credential: 'a@b.com', password: 'x');

    expect(repository.logoutCalls, 1);
    expect(
      container.read(hgfastAuthProvider).phase,
      HgfastAuthPhase.unauthenticated,
    );
    expect(
      container.read(hgfastNodesProvider).phase,
      HgfastNodesPhase.idle,
    );
  });

  test(
    'two concurrent syncAfterLogin calls share a single in-flight nodes() '
    'request instead of racing two writes',
    () async {
      final completer = Completer<HgfastResult<NodeCatalog, HgfastError>>();
      repository.nodesCall = () => completer.future;

      final syncNotifier = container.read(hgfastSyncActionProvider.notifier);
      final first = syncNotifier.syncAfterLogin();
      final second = syncNotifier.syncAfterLogin();
      await Future<void>.delayed(Duration.zero);

      expect(repository.nodesCalls, 1);

      completer.complete(
        const HgfastResult.failure(HgfastError.clientApiStateUnavailable()),
      );
      await first;
      await second;

      expect(repository.nodesCalls, 1);
      syncNotifier.stopPolling();
    },
  );

  test(
    'the poll loop stops on its own once the auth state turns '
    'unauthenticated, even without an explicit stopPolling call',
    () async {
      repository.loginResult = HgfastResult.success(
        HgfastSession(const {'user_id': 1, 'session_id': 'sess-1'}),
      );
      repository.nodesResult = const HgfastResult.failure(
        HgfastError.clientApiStateUnavailable(),
      );

      await container
          .read(hgfastAuthActionProvider.notifier)
          .login(credential: 'a@b.com', password: 'x');
      final callsAfterLogin = repository.nodesCalls;
      expect(callsAfterLogin, greaterThan(0));

      container.read(hgfastAuthProvider.notifier).markUnauthenticated();

      await Future<void>.delayed(const Duration(milliseconds: 50));
      expect(repository.nodesCalls, callsAfterLogin);
    },
  );
}
