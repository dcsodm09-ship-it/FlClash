import 'package:fl_clash/hgfast/models/error.dart';
import 'package:fl_clash/hgfast/models/node.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part '../generated/hgfast/nodes.g.dart';

enum HgfastNodesPhase {
  idle,
  loading,
  loaded,
  accountBlocked,
  notInCanary,
  error,
}

final class HgfastNodesState {
  const HgfastNodesState({
    this.phase = HgfastNodesPhase.idle,
    this.catalog,
    this.error,
  });

  final HgfastNodesPhase phase;
  final NodeCatalog? catalog;
  final HgfastError? error;

  HgfastNodesState withPhase(HgfastNodesPhase phase, {HgfastError? error}) {
    return HgfastNodesState(phase: phase, catalog: catalog, error: error);
  }
}

@Riverpod(keepAlive: true)
class HgfastNodes extends _$HgfastNodes {
  @override
  HgfastNodesState build() {
    return const HgfastNodesState();
  }

  void markLoading() {
    state = state.withPhase(HgfastNodesPhase.loading);
  }

  void markLoaded(NodeCatalog catalog) {
    state = HgfastNodesState(phase: HgfastNodesPhase.loaded, catalog: catalog);
  }

  void markAccountBlocked(HgfastError error) {
    state = state.withPhase(HgfastNodesPhase.accountBlocked, error: error);
  }

  void markNotInCanary(HgfastError error) {
    state = state.withPhase(HgfastNodesPhase.notInCanary, error: error);
  }

  void markError(HgfastError error) {
    state = state.withPhase(HgfastNodesPhase.error, error: error);
  }

  void reset() {
    state = const HgfastNodesState();
  }
}
