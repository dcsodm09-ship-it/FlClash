import 'package:fl_clash/hgfast/config_gen/config_gen.dart';
import 'package:fl_clash/hgfast/models/node.dart';
import 'package:flutter_test/flutter_test.dart';

NodeSpec _node({
  String name = 'HK-01',
  String server = 'hk01.example.com',
  int serverPort = 443,
  String password = 'uuid-hk-01',
  String serverName = 'hk01.example.com',
  bool insecure = false,
  String protocol = 'anytls',
  String region = 'hk',
  String routeLabel = 'IEPL',
  String rate = '1',
  int sort = 10,
  String groupId = '1',
  NodeCategory category = NodeCategory.standard,
  String? certCn,
}) {
  return NodeSpec(
    name: name,
    server: server,
    serverPort: serverPort,
    password: password,
    serverName: serverName,
    insecure: insecure,
    protocol: protocol,
    region: region,
    routeLabel: routeLabel,
    rate: rate,
    sort: sort,
    groupId: groupId,
    category: category,
    certCn: certCn,
  );
}

NodeCatalog _catalog(List<NodeSpec> nodes) {
  return NodeCatalog(automatic: true, groups: <String, List<NodeSpec>>{
    'all': nodes,
  });
}

void main() {
  const generator = HgfastConfigGenerator();

  test('generate maps NodeSpec fields to the mihomo anytls proxy option', () {
    final config = generator.generate(
      catalog: _catalog(<NodeSpec>[_node()]),
      mixedPort: 7890,
    );
    final proxies = config['proxies'] as List<Object?>;
    expect(proxies, hasLength(1));
    expect(proxies.single, <String, Object?>{
      'name': 'HK-01',
      'server': 'hk01.example.com',
      'port': 443,
      'password': 'uuid-hk-01',
      'type': 'anytls',
      'udp': true,
      'client-fingerprint': 'chrome',
      'sni': 'hk01.example.com',
      'skip-cert-verify': false,
    });
  });

  test('generate omits sni when server_name is empty', () {
    final config = generator.generate(
      catalog: _catalog(<NodeSpec>[_node(serverName: '')]),
      mixedPort: 7890,
    );
    final proxy = (config['proxies'] as List<Object?>).single as Map<Object?, Object?>;
    expect(proxy.containsKey('sni'), isFalse);
  });

  test('generate prefers name-cert-verify over skip-cert-verify when cert_cn is known', () {
    final config = generator.generate(
      catalog: _catalog(<NodeSpec>[
        _node(insecure: true, certCn: 'hk01.example.com'),
      ]),
      mixedPort: 7890,
    );
    final proxy = (config['proxies'] as List<Object?>).single as Map<Object?, Object?>;
    expect(proxy['name-cert-verify'], 'hk01.example.com');
    expect(proxy.containsKey('skip-cert-verify'), isFalse);
  });

  test('generate falls back to skip-cert-verify when no cert_cn is known', () {
    final config = generator.generate(
      catalog: _catalog(<NodeSpec>[_node(insecure: true)]),
      mixedPort: 7890,
    );
    final proxy = (config['proxies'] as List<Object?>).single as Map<Object?, Object?>;
    expect(proxy['skip-cert-verify'], isTrue);
    expect(proxy.containsKey('name-cert-verify'), isFalse);
  });

  test('generate dedupes duplicate proxy names with a numeric suffix', () {
    final config = generator.generate(
      catalog: _catalog(<NodeSpec>[
        _node(server: 'a.example.com'),
        _node(server: 'b.example.com'),
        _node(server: 'c.example.com'),
      ]),
      mixedPort: 7890,
    );
    final names = (config['proxies'] as List<Object?>)
        .map((proxy) => (proxy as Map<Object?, Object?>)['name'])
        .toList();
    expect(names, <String>['HK-01', 'HK-01 (2)', 'HK-01 (3)']);
  });

  test('generate builds a url-test HG-AUTO group over every proxy', () {
    final config = generator.generate(
      catalog: _catalog(<NodeSpec>[
        _node(server: 'a.example.com'),
        _node(server: 'b.example.com', region: 'jp'),
      ]),
      mixedPort: 7890,
      testUrl: 'https://example.com/generate_204',
    );
    final groups = config['proxy-groups'] as List<Object?>;
    final auto = groups.first as Map<Object?, Object?>;
    expect(auto['name'], 'HG-AUTO');
    expect(auto['type'], 'url-test');
    expect(auto['proxies'], <String>['HK-01', 'HK-01 (2)']);
    expect(auto['url'], 'https://example.com/generate_204');
    expect(auto['interval'], 300);
  });

  test('generate builds one select group per distinct region, sorted', () {
    final config = generator.generate(
      catalog: _catalog(<NodeSpec>[
        _node(server: 'a.example.com', region: 'sg'),
        _node(server: 'b.example.com', region: 'hk'),
        _node(server: 'c.example.com', region: 'hk'),
      ]),
      mixedPort: 7890,
    );
    final groups = (config['proxy-groups'] as List<Object?>)
        .cast<Map<Object?, Object?>>();
    final regionGroups = groups.where(
      (group) => group['name'] != 'HG-AUTO' && group['name'] != 'HG-VIP',
    );
    expect(
      regionGroups.map((group) => group['name']),
      <String>['HG-hk', 'HG-sg'],
    );
    final hkGroup = regionGroups.firstWhere(
      (group) => group['name'] == 'HG-hk',
    );
    expect(hkGroup['type'], 'select');
    expect(hkGroup['proxies'], <String>['HK-01 (2)', 'HK-01 (3)']);
  });

  test('generate only adds HG-VIP when a vip-category node is present', () {
    final withoutVip = generator.generate(
      catalog: _catalog(<NodeSpec>[_node()]),
      mixedPort: 7890,
    );
    final withVip = generator.generate(
      catalog: _catalog(<NodeSpec>[
        _node(server: 'a.example.com'),
        _node(server: 'b.example.com', category: NodeCategory.vip),
      ]),
      mixedPort: 7890,
    );

    final withoutVipNames = (withoutVip['proxy-groups'] as List<Object?>)
        .cast<Map<Object?, Object?>>()
        .map((group) => group['name']);
    expect(withoutVipNames, isNot(contains('HG-VIP')));

    final vipGroup = (withVip['proxy-groups'] as List<Object?>)
        .cast<Map<Object?, Object?>>()
        .firstWhere((group) => group['name'] == 'HG-VIP');
    expect(vipGroup['type'], 'select');
    expect(vipGroup['proxies'], <String>['HK-01 (2)']);
  });

  test('generate emits the control-plane bypass rule before MATCH,HG-AUTO', () {
    final config = generator.generate(
      catalog: _catalog(<NodeSpec>[_node()]),
      mixedPort: 7890,
    );
    expect(config['rules'], <String>[
      'DOMAIN-SUFFIX,hgfastapp.com,DIRECT',
      'MATCH,HG-AUTO',
    ]);
  });

  test('generate throws on an empty node catalog instead of writing proxies: []', () {
    expect(
      () => generator.generate(catalog: _catalog(<NodeSpec>[]), mixedPort: 7890),
      throwsA(isA<HgfastEmptyNodeCatalogException>()),
    );
  });

  test('generate uses node.protocol as the proxy type instead of hardcoding anytls', () {
    final config = generator.generate(
      catalog: _catalog(<NodeSpec>[_node(protocol: 'something-else')]),
      mixedPort: 7890,
    );
    final proxy = (config['proxies'] as List<Object?>).single as Map<Object?, Object?>;
    expect(proxy['type'], 'something-else');
  });

  test('generate suffixes a node name that collides with a reserved group name', () {
    final config = generator.generate(
      catalog: _catalog(<NodeSpec>[
        _node(server: 'a.example.com', name: 'HG-AUTO', region: 'hk'),
        _node(server: 'b.example.com', name: 'HG-hk', region: 'hk'),
      ]),
      mixedPort: 7890,
    );
    final proxyNames = (config['proxies'] as List<Object?>)
        .map((proxy) => (proxy as Map<Object?, Object?>)['name'])
        .toSet();
    // Neither node keeps the literal group-name string; both proxies still
    // exist (nothing silently dropped).
    expect(proxyNames, isNot(contains('HG-AUTO')));
    expect(proxyNames, isNot(contains('HG-hk')));
    expect(proxyNames, hasLength(2));

    final groups = (config['proxy-groups'] as List<Object?>)
        .cast<Map<Object?, Object?>>();
    final autoGroup = groups.firstWhere((g) => g['name'] == 'HG-AUTO');
    final hkGroup = groups.firstWhere((g) => g['name'] == 'HG-hk');
    expect((autoGroup['proxies'] as List<Object?>).toSet(), proxyNames);
    expect((hkGroup['proxies'] as List<Object?>).toSet(), proxyNames);
  });
}
