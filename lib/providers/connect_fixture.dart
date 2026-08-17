import 'package:fl_clash/hgfast/models/node.dart';

NodeSpec _fixtureNode({
  required String name,
  required String server,
  required String region,
  required String routeLabel,
  required String rate,
  required int sort,
  required String groupId,
  NodeCategory category = NodeCategory.standard,
}) {
  return NodeSpec(
    name: name,
    server: server,
    serverPort: 20025,
    password: 'fixture-password',
    serverName: server,
    insecure: false,
    protocol: 'anytls',
    region: region,
    routeLabel: routeLabel,
    rate: rate,
    sort: sort,
    groupId: groupId,
    category: category,
  );
}

NodeCatalog connectFixtureNodeCatalog() {
  return NodeCatalog(
    automatic: true,
    groups: {
      'asia': [
        _fixtureNode(
          name: '🇭🇰 香港 01',
          server: 'hk01.fixture.hgfast.internal',
          region: 'HK',
          routeLabel: '香港',
          rate: '1',
          sort: 10,
          groupId: 'asia',
        ),
        _fixtureNode(
          name: '🇯🇵 东京 01',
          server: 'jp01.fixture.hgfast.internal',
          region: 'JP',
          routeLabel: '日本',
          rate: '1',
          sort: 20,
          groupId: 'asia',
        ),
        _fixtureNode(
          name: '🇸🇬 新加坡 01',
          server: 'sg01.fixture.hgfast.internal',
          region: 'SG',
          routeLabel: '新加坡',
          rate: '1.5',
          sort: 30,
          groupId: 'asia',
        ),
      ],
      'na': [
        _fixtureNode(
          name: '🇺🇸 洛杉矶 01',
          server: 'us01.fixture.hgfast.internal',
          region: 'US',
          routeLabel: '美国',
          rate: '1',
          sort: 40,
          groupId: 'na',
        ),
      ],
      'eu': [
        _fixtureNode(
          name: '🇩🇪 法兰克福 01',
          server: 'de01.fixture.hgfast.internal',
          region: 'DE',
          routeLabel: '德国',
          rate: '1.5',
          sort: 50,
          groupId: 'eu',
        ),
      ],
    },
  );
}
