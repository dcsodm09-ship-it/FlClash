import 'package:fl_clash/enum/enum.dart';
import 'package:fl_clash/hgfast/models/node.dart';
import 'package:fl_clash/providers/app.dart';
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

  test('fixture catalog only exposes universally-available filters', () {
    final availableFilters = container.read(connectAvailableFiltersProvider);
    expect(
      availableFilters,
      containsAll([
        NodeTypeFilter.all,
        NodeTypeFilter.recommended,
        NodeTypeFilter.regional,
      ]),
    );
    expect(availableFilters, isNot(contains(NodeTypeFilter.vip)));
    expect(availableFilters, isNot(contains(NodeTypeFilter.dedicatedIp)));
    expect(availableFilters, isNot(contains(NodeTypeFilter.residential)));
  });

  test('an unavailable filter reconciles back to all', () {
    final state = container.read(
      filterConnectNodesStateProvider(NodeTypeFilter.vip),
    );
    expect(state.selectedFilter, NodeTypeFilter.all);
    expect(state.nodes, isNotEmpty);
  });

  test(
    'all preserves catalog order, recommended sorts by the server sort field',
    () {
      final overrideContainer = ProviderContainer(
        overrides: [
          connectNodeCatalogProvider.overrideWith(
            (ref) => NodeCatalog(
              automatic: true,
              groups: {
                'test': [
                  _node(name: 'second', sort: 20),
                  _node(name: 'first', sort: 10),
                ],
              },
            ),
          ),
        ],
      );
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
    final overrideContainer = ProviderContainer(
      overrides: [
        connectNodeCatalogProvider.overrideWith(
          (ref) => NodeCatalog(
            automatic: true,
            groups: {
              'test': [
                _node(name: 'us-a', region: 'US', sort: 10),
                _node(name: 'hk-a', region: 'HK', sort: 20),
                _node(name: 'us-b', region: 'US', sort: 30),
                _node(name: 'hk-b', region: 'HK', sort: 40),
              ],
            },
          ),
        ),
      ],
    );
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
    final overrideContainer = ProviderContainer(
      overrides: [
        connectNodeCatalogProvider.overrideWith(
          (ref) => NodeCatalog(
            automatic: true,
            groups: {
              'test': [
                _node(name: 'standard node', sort: 1),
                _node(name: 'vip node', category: NodeCategory.vip, sort: 2),
                _node(
                  name: 'dedicated node',
                  category: NodeCategory.dedicatedIp,
                  sort: 3,
                ),
              ],
            },
          ),
        ),
      ],
    );
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
    final overrideContainer = ProviderContainer(
      overrides: [
        connectNodeCatalogProvider.overrideWith(
          (ref) => NodeCatalog(
            automatic: true,
            groups: {
              'test': [_node(name: 'no region', region: '', sort: 1)],
            },
          ),
        ),
      ],
    );
    addTearDown(overrideContainer.dispose);

    expect(
      overrideContainer.read(connectAvailableFiltersProvider),
      isNot(contains(NodeTypeFilter.regional)),
    );
  });
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
