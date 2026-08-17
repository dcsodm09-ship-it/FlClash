import 'package:fl_clash/hgfast/models/error.dart';
import 'package:fl_clash/hgfast/repository/repository.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part '../generated/hgfast/auth.g.dart';

enum HgfastAuthPhase { unknown, unauthenticated, authenticating, authenticated }

final class HgfastAuthState {
  const HgfastAuthState({
    this.phase = HgfastAuthPhase.unknown,
    this.session,
    this.error,
  });

  final HgfastAuthPhase phase;
  final HgfastSession? session;
  final HgfastError? error;

  bool get isAuthenticated =>
      phase == HgfastAuthPhase.authenticated && session != null;
}

@Riverpod(keepAlive: true)
class HgfastAuth extends _$HgfastAuth {
  @override
  HgfastAuthState build() {
    return const HgfastAuthState();
  }

  void markAuthenticating() {
    state = const HgfastAuthState(phase: HgfastAuthPhase.authenticating);
  }

  void markAuthenticated(HgfastSession session) {
    state = HgfastAuthState(
      phase: HgfastAuthPhase.authenticated,
      session: session,
    );
  }

  void markUnauthenticated({HgfastError? error}) {
    state = HgfastAuthState(
      phase: HgfastAuthPhase.unauthenticated,
      error: error,
    );
  }
}
