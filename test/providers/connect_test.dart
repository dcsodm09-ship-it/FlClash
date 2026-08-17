import 'package:fl_clash/enum/enum.dart';
import 'package:fl_clash/hgfast/models/error.dart';
import 'package:fl_clash/hgfast/models/node.dart';
import 'package:fl_clash/providers/app.dart';
import 'package:fl_clash/providers/connect_fixture.dart';
import 'package:fl_clash/providers/hgfast/nodes.dart';
import 'package:fl_clash/providers/state.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:riverpod/riverpod.dart';

void main() {
  late ProviderContainer container;

  setUp(() {
    container = ProviderContainer();
  });

  tearDown(() {
    container.dispose();
  });

  test('connect filter selection defaults to all and can be updated', () {
    expect(container.read(connectFilterProvider), NodeTypeFilter.all);
    container.read(connectFilterProvider.notifier).value =
        NodeTypeFilter.recommended;
    expect(container.read(connectFilterProvider), NodeTypeFilter.recommended);
  });

  test('idle and loading both map to ConnectLoadPhase.loading', () {
    final idle = container.read(
      filterConnectNodesStateProvider(NodeTypeFilter.all),
    );
    expect(idle.phase, ConnectLoadPhase.loading);
    expect(idle.nodes, isEmpty);
  });

  test('loaded catalog exposes only universally-available filters', () {
    final overrideContainer = _withNodes(_fixtureNodes());
    addTearDown(overrideContainer.dispose);

    final state = overrideContainer.read(
      filterConnectNodesStateProvider(NodeTypeFilter.all),
    );
    expect(state.phase, ConnectLoadPhase.loaded);
    expect(
      state.availableFilters,
      containsAll([
        NodeTypeFilter.all,
        NodeTypeFilter.recommended,
        NodeTypeFilter.regional,
      ]),
    );
    expect(state.availableFilters, isNot(contains(NodeTypeFilter.vip)));
    expect(state.availableFilters, isNot(contains(NodeTypeFilter.dedicatedIp)));
    expect(state.availableFilters, isNot(contains(NodeTypeFilter.residential)));
  });

  test('an unavailable filter reconciles back to all', () {
    final overrideContainer = _withNodes(_fixtureNodes());
    addTearDown(overrideContainer.dispose);

    final state = overrideContainer.read(
      filterConnectNodesStateProvider(NodeTypeFilter.vip),
    );
    expect(state.selectedFilter, NodeTypeFilter.all);
    expect(state.nodes, isNotEmpty);
  });

  test(
    'all preserves catalog order, recommended sorts by the server sort field',
    () {
      final overrideContainer = _withNodes([
        _node(name: 'second', sort: 20),
        _node(name: 'first', sort: 10),
      ]);
      addTearDown(overrideContainer.dispose);

      final all = overrideContainer.read(
        filterConnectNodesStateProvider(NodeTypeFilter.all),
      );
      expect(all.nodes.map((node) => node.name), ['second', 'first']);

      final recommended = overrideContainer.read(
        filterConnectNodesStateProvider(NodeTypeFilter.recommended),
      );
      expect(recommended.nodes.map((node) => node.name), ['first', 'second']);
    },
  );

  test('regional groups nodes by region before sort', () {
    final overrideContainer = _withNodes([
      _node(name: 'us-a', region: 'US', sort: 10),
      _node(name: 'hk-a', region: 'HK', sort: 20),
      _node(name: 'us-b', region: 'US', sort: 30),
      _node(name: 'hk-b', region: 'HK', sort: 40),
    ]);
    addTearDown(overrideContainer.dispose);

    final regional = overrideContainer.read(
      filterConnectNodesStateProvider(NodeTypeFilter.regional),
    );
    expect(regional.nodes.map((node) => node.name), [
      'hk-a',
      'hk-b',
      'us-a',
      'us-b',
    ]);
  });

  test('vip and dedicatedIp chips appear only once the catalog has a matching '
      'node, residential stays hidden', () {
    final overrideContainer = _withNodes([
      _node(name: 'standard node', sort: 1),
      _node(name: 'vip node', category: NodeCategory.vip, sort: 2),
      _node(
        name: 'dedicated node',
        category: NodeCategory.dedicatedIp,
        sort: 3,
      ),
    ]);
    addTearDown(overrideContainer.dispose);

    final availableFilters = overrideContainer.read(
      connectAvailableFiltersProvider,
    );
    expect(availableFilters, contains(NodeTypeFilter.vip));
    expect(availableFilters, contains(NodeTypeFilter.dedicatedIp));
    expect(availableFilters, isNot(contains(NodeTypeFilter.residential)));

    final vipNodes = overrideContainer.read(
      filterConnectNodesStateProvider(NodeTypeFilter.vip),
    );
    expect(vipNodes.nodes.single.name, 'vip node');
    expect(vipNodes.selectedFilter, NodeTypeFilter.vip);

    final dedicatedNodes = overrideContainer.read(
      filterConnectNodesStateProvider(NodeTypeFilter.dedicatedIp),
    );
    expect(dedicatedNodes.nodes.single.name, 'dedicated node');
  });

  test('regional chip is hidden when no node has a region', () {
    final overrideContainer = _withNodes([
      _node(name: 'no region', region: '', sort: 1),
    ]);
    addTearDown(overrideContainer.dispose);

    expect(
      overrideContainer.read(connectAvailableFiltersProvider),
      isNot(contains(NodeTypeFilter.regional)),
    );
  });

  test(
    'accountBlocked keeps the last known catalog while flagging the phase',
    () {
      final overrideContainer = ProviderContainer(
        overrides: [
          hgfastNodesProvider.overrideWith(
            () => _TestHgfastNodes(
              HgfastNodesState(
                phase: HgfastNodesPhase.accountBlocked,
                catalog: connectFixtureNodeCatalog(),
                error: const HgfastError.expired(),
              ),
            ),
          ),
        ],
      );
      addTearDown(overrideContainer.dispose);

      final state = overrideContainer.read(
        filterConnectNodesStateProvider(NodeTypeFilter.all),
      );
      expect(state.phase, ConnectLoadPhase.accountBlocked);
      expect(state.error, const HgfastError.expired());
      expect(state.nodes, isNotEmpty);
    },
  );

  test('notInCanary and error map through with no catalog yet', () {
    final notInCanary = ProviderContainer(
      overrides: [
        hgfastNodesProvider.overrideWith(
          () => _TestHgfastNodes(
            const HgfastNodesState(
              phase: HgfastNodesPhase.notInCanary,
              error: HgfastError.canaryDenied(HgfastResource.nodes),
            ),
          ),
        ),
      ],
    );
    addTearDown(notInCanary.dispose);
    final notInCanaryState = notInCanary.read(
      filterConnectNodesStateProvider(NodeTypeFilter.all),
    );
    expect(notInCanaryState.phase, ConnectLoadPhase.notInCanary);
    expect(notInCanaryState.nodes, isEmpty);

    final error = ProviderContainer(
      overrides: [
        hgfastNodesProvider.overrideWith(
          () => _TestHgfastNodes(
            const HgfastNodesState(
              phase: HgfastNodesPhase.error,
              error: HgfastError.c1('E_NETWORK'),
            ),
          ),
        ),
      ],
    );
    addTearDown(error.dispose);
    final errorState = error.read(
      filterConnectNodesStateProvider(NodeTypeFilter.all),
    );
    expect(errorState.phase, ConnectLoadPhase.error);
    expect(errorState.nodes, isEmpty);
  });
}

ProviderContainer _withNodes(List<NodeSpec> nodes) {
  return ProviderContainer(
    overrides: [
      hgfastNodesProvider.overrideWith(
        () => _TestHgfastNodes(
          HgfastNodesState(
            phase: HgfastNodesPhase.loaded,
            catalog: NodeCatalog(automatic: true, groups: {'test': nodes}),
          ),
        ),
      ),
    ],
  );
}

List<NodeSpec> _fixtureNodes() => connectFixtureNodeCatalog().nodes;

class _TestHgfastNodes extends HgfastNodes {
  _TestHgfastNodes(this.initial);

  final HgfastNodesState initial;

  @override
  HgfastNodesState build() => initial;
}

NodeSpec _node({
  required String name,
  String region = 'HK',
  int sort = 0,
  NodeCategory category = NodeCategory.standard,
}) {
  return NodeSpec(
    name: name,
    server: 'server.test',
    serverPort: 20025,
    password: 'fixture-password',
    serverName: 'server.test',
    insecure: false,
    protocol: 'anytls',
    region: region,
    routeLabel: region,
    rate: '1',
    sort: sort,
    groupId: 'test',
    category: category,
  );
}
