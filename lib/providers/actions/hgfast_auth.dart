part of '../action.dart';

@Riverpod(keepAlive: true)
class HgfastAuthAction extends _$HgfastAuthAction {
  @override
  void build() {}

  Future<void> restoreSession() async {
    final result = await ref.read(hgfastRepositoryProvider).restoreSession();
    final error = result.failureError;
    if (error != null) {
      ref.read(hgfastAuthProvider.notifier).markUnauthenticated(error: error);
      return;
    }
    final session = result.successValue;
    if (session == null) {
      ref.read(hgfastAuthProvider.notifier).markUnauthenticated();
      return;
    }
    ref.read(hgfastAuthProvider.notifier).markAuthenticated(session);
    unawaited(ref.read(hgfastSyncActionProvider.notifier).syncAfterLogin());
  }

  Future<bool> login({
    required String credential,
    required String password,
  }) async {
    ref.read(hgfastAuthProvider.notifier).markAuthenticating();
    final result = await ref
        .read(hgfastRepositoryProvider)
        .login(credential: credential, password: password);
    final session = result.successValue;
    if (session == null) {
      ref
          .read(hgfastAuthProvider.notifier)
          .markUnauthenticated(error: result.failureError);
      return false;
    }
    ref.read(hgfastAuthProvider.notifier).markAuthenticated(session);
    await ref.read(hgfastSyncActionProvider.notifier).syncAfterLogin();
    return true;
  }

  Future<void> logout() async {
    ref.read(hgfastSyncActionProvider.notifier).stopPolling();
    await ref.read(hgfastRepositoryProvider).logout();
    ref.read(hgfastNodesProvider.notifier).reset();
    ref.read(hgfastAuthProvider.notifier).markUnauthenticated();
  }
}
