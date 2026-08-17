import 'package:fl_clash/common/yaml.dart';
import 'package:fl_clash/hgfast/config_gen/config_gen.dart';
import 'package:fl_clash/hgfast/models/node.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:yaml/yaml.dart';

void main() {
  test('the generated map round-trips through the house YAML writer and parser', () {
    const generator = HgfastConfigGenerator();
    const node = NodeSpec(
      name: 'HK-01',
      server: 'hk01.example.com',
      serverPort: 443,
      password: 'uuid-hk-01',
      serverName: 'hk01.example.com',
      insecure: false,
      protocol: 'anytls',
      region: 'hk',
      routeLabel: 'IEPL',
      rate: '1',
      sort: 10,
      groupId: '1',
      category: NodeCategory.standard,
    );
    final catalog = NodeCatalog(
      automatic: true,
      groups: <String, List<NodeSpec>>{
        'all': <NodeSpec>[node],
      },
    );
    final config = generator.generate(catalog: catalog, mixedPort: 7890);

    final text = yaml.encode(config);
    final parsed = loadYaml(text) as YamlMap;

    expect(parsed['mixed-port'], 7890);
    expect(parsed['mode'], 'rule');
    final proxies = parsed['proxies'] as YamlList;
    expect(proxies, hasLength(1));
    final proxy = proxies.single as YamlMap;
    expect(proxy['type'], 'anytls');
    expect(proxy['udp'], isTrue);
    expect(proxy['client-fingerprint'], 'chrome');
    final rules = parsed['rules'] as YamlList;
    expect(rules.last, 'MATCH,HG-AUTO');
  });
}
