import '../models/node.dart';

const String hgfastAutoGroupName = 'HG-AUTO';
const String hgfastVipGroupName = 'HG-VIP';
const String hgfastDefaultTestUrl = 'https://www.gstatic.com/generate_204';
const String hgfastControlPlaneDomainSuffix = 'hgfastapp.com';

String hgfastRegionGroupName(String region) => 'HG-$region';

final class HgfastEmptyNodeCatalogException implements Exception {
  const HgfastEmptyNodeCatalogException();

  @override
  String toString() {
    return 'HgfastEmptyNodeCatalogException: refusing to generate a config '
        'with zero nodes';
  }
}

final class HgfastConfigGenerator {
  const HgfastConfigGenerator();

  // catalog.dedicated is never turned into a proxy: dedicated-IP is out of
  // v1 scope (feature_flags.dedicated_ip: false server-side) and the
  // backend always sends it null today. Revisit this the day that flag
  // flips.
  Map<String, Object?> generate({
    required NodeCatalog catalog,
    required int mixedPort,
    String testUrl = hgfastDefaultTestUrl,
  }) {
    final nodes = catalog.nodes;
    if (nodes.isEmpty) {
      throw const HgfastEmptyNodeCatalogException();
    }

    final regionCodes = nodes.map((node) => node.region).toSet().toList()
      ..sort();

    // Reserve every group name before dedup runs, so a server-controlled
    // node `name` (or a `region` code) that happens to collide with a
    // synthetic group name gets suffixed instead of shadowing that group in
    // the proxy-groups' `proxies:` lists below.
    final usedNames = <String>{
      hgfastAutoGroupName,
      hgfastVipGroupName,
      for (final region in regionCodes) hgfastRegionGroupName(region),
    };
    final proxies = <Map<String, Object?>>[];
    final proxyNameByNode = <NodeSpec, String>{};
    for (final node in nodes) {
      final proxyName = _dedupeName(node.name, usedNames);
      proxyNameByNode[node] = proxyName;
      proxies.add(_toProxyOption(node, proxyName));
    }

    final proxyGroups = <Map<String, Object?>>[
      <String, Object?>{
        'name': hgfastAutoGroupName,
        'type': 'url-test',
        'proxies': [for (final node in nodes) proxyNameByNode[node]],
        'url': testUrl,
        'interval': 300,
      },
      for (final region in regionCodes)
        <String, Object?>{
          'name': hgfastRegionGroupName(region),
          'type': 'select',
          'proxies': [
            for (final node in nodes)
              if (node.region == region) proxyNameByNode[node],
          ],
        },
    ];

    final vipProxyNames = [
      for (final node in nodes)
        if (node.category == NodeCategory.vip) proxyNameByNode[node],
    ];
    if (vipProxyNames.isNotEmpty) {
      proxyGroups.add(<String, Object?>{
        'name': hgfastVipGroupName,
        'type': 'select',
        'proxies': vipProxyNames,
      });
    }

    return <String, Object?>{
      'mixed-port': mixedPort,
      'mode': 'rule',
      'proxies': proxies,
      'proxy-groups': proxyGroups,
      'rules': <String>[
        'DOMAIN-SUFFIX,$hgfastControlPlaneDomainSuffix,DIRECT',
        'MATCH,$hgfastAutoGroupName',
      ],
    };
  }

  Map<String, Object?> _toProxyOption(NodeSpec node, String proxyName) {
    final option = <String, Object?>{
      'name': proxyName,
      'server': node.server,
      'port': node.serverPort,
      'password': node.password,
      'type': node.protocol,
      'udp': true,
      'client-fingerprint': 'chrome',
    };
    if (node.serverName.isNotEmpty) {
      option['sni'] = node.serverName;
    }
    final certCn = node.certCn;
    if (certCn != null && certCn.isNotEmpty) {
      option['name-cert-verify'] = certCn;
    } else {
      option['skip-cert-verify'] = node.insecure;
    }
    return option;
  }

  String _dedupeName(String name, Set<String> usedNames) {
    if (usedNames.add(name)) {
      return name;
    }
    var suffix = 2;
    while (!usedNames.add('$name ($suffix)')) {
      suffix++;
    }
    return '$name ($suffix)';
  }
}
