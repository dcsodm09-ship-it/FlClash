enum NodeCategory {
  standard('standard'),
  vip('vip'),
  dedicatedIp('dedicated_ip'),
  residential('residential');

  const NodeCategory(this.value);

  final String value;

  static NodeCategory fromJson(Object? value) {
    return NodeCategory.values.firstWhere(
      (category) => category.value == value,
      orElse: () => throw FormatException('Invalid node category: $value'),
    );
  }
}

final class NodeSpec {
  const NodeSpec({
    required this.name,
    required this.server,
    required this.serverPort,
    required this.password,
    required this.serverName,
    required this.insecure,
    required this.protocol,
    required this.region,
    required this.routeLabel,
    required this.rate,
    required this.sort,
    required this.groupId,
    required this.category,
    this.certCn,
  });

  factory NodeSpec.fromJson(Map<String, Object?> json) {
    return NodeSpec(
      name: _requiredString(json, 'name'),
      server: _requiredString(json, 'server'),
      serverPort: _requiredInt(json, 'server_port'),
      password: _requiredString(json, 'password'),
      serverName: _requiredString(json, 'server_name'),
      insecure: _requiredBool(json, 'insecure'),
      protocol: _requiredString(json, 'protocol'),
      region: _requiredString(json, 'region'),
      routeLabel: _requiredString(json, 'route_label'),
      rate: _requiredScalarString(json, 'rate'),
      sort: _requiredInt(json, 'sort'),
      groupId: _requiredScalarString(json, 'group_id'),
      category: NodeCategory.fromJson(json['category']),
      certCn: _optionalString(json, 'cert_cn'),
    );
  }

  final String name;
  final String server;
  final int serverPort;
  final String password;
  final String serverName;
  final bool insecure;
  final String protocol;
  final String region;
  final String routeLabel;
  final String rate;
  final int sort;
  final String groupId;
  final NodeCategory category;
  final String? certCn;

  Map<String, Object?> toJson() {
    return {
      'name': name,
      'server': server,
      'server_port': serverPort,
      'password': password,
      'server_name': serverName,
      'insecure': insecure,
      'protocol': protocol,
      'region': region,
      'route_label': routeLabel,
      'rate': rate,
      'sort': sort,
      'group_id': groupId,
      'category': category.value,
      if (certCn != null) 'cert_cn': certCn,
    };
  }
}

final class NodeCatalog {
  NodeCatalog({
    required this.automatic,
    required Map<String, List<NodeSpec>> groups,
    this.dedicated,
  }) : groups = Map<String, List<NodeSpec>>.unmodifiable({
         for (final entry in groups.entries)
           entry.key: List<NodeSpec>.unmodifiable(entry.value),
       });

  factory NodeCatalog.fromJson(Map<String, Object?> json) {
    final rawGroups = json['groups'];
    if (rawGroups is! List<Object?>) {
      throw const FormatException('Invalid node groups');
    }
    final groups = <String, List<NodeSpec>>{};
    for (final rawGroup in rawGroups) {
      final group = _requiredMap(rawGroup, 'node group');
      final label = _requiredString(group, 'label');
      final rawNodes = group['nodes'];
      if (rawNodes is! List<Object?>) {
        throw const FormatException('Invalid node list');
      }
      groups[label] = rawNodes
          .map(
            (node) => NodeSpec.fromJson(_requiredMap(node, 'node')),
          )
          .toList(growable: false);
    }
    final rawDedicated = json['dedicated'];
    return NodeCatalog(
      automatic: _optionalBool(json, 'auto') ?? true,
      groups: groups,
      dedicated: rawDedicated == null
          ? null
          : NodeSpec.fromJson(_requiredMap(rawDedicated, 'dedicated')),
    );
  }

  final bool automatic;
  final Map<String, List<NodeSpec>> groups;
  final NodeSpec? dedicated;

  List<NodeSpec> get nodes {
    return List.unmodifiable(groups.values.expand((nodes) => nodes));
  }

  Map<String, Object?> toJson() {
    return {
      'auto': automatic,
      'groups': groups.entries
          .map(
            (entry) => {
              'label': entry.key,
              'nodes': entry.value.map((node) => node.toJson()).toList(),
            },
          )
          .toList(),
      'dedicated': dedicated?.toJson(),
    };
  }
}

String _requiredString(Map<String, Object?> json, String key) {
  final value = json[key];
  if (value is String) {
    return value;
  }
  throw FormatException('Invalid $key');
}

String _requiredScalarString(Map<String, Object?> json, String key) {
  final value = json[key];
  if (value is String || value is num) {
    return value.toString();
  }
  throw FormatException('Invalid $key');
}

int _requiredInt(Map<String, Object?> json, String key) {
  final value = json[key];
  if (value is int) {
    return value;
  }
  throw FormatException('Invalid $key');
}

bool _requiredBool(Map<String, Object?> json, String key) {
  final value = json[key];
  if (value is bool) {
    return value;
  }
  throw FormatException('Invalid $key');
}

// Optional-field variants of the _required* helpers above. A raw `as bool?` /
// `as String?` cast throws TypeError (not FormatException) when the key is
// present but holds the wrong type, silently breaking the contract every
// caller of NodeSpec.fromJson/NodeCatalog.fromJson relies on: catch on
// FormatException to distinguish "malformed server payload" from a real bug.
bool? _optionalBool(Map<String, Object?> json, String key) {
  final value = json[key];
  if (value == null) {
    return null;
  }
  if (value is bool) {
    return value;
  }
  throw FormatException('Invalid $key');
}

String? _optionalString(Map<String, Object?> json, String key) {
  final value = json[key];
  if (value == null) {
    return null;
  }
  if (value is String) {
    return value;
  }
  throw FormatException('Invalid $key');
}

// Guards the structural `as Map<Object?, Object?>` casts in
// NodeCatalog.fromJson the same way: a JSON list element that is null or not
// a map must raise FormatException, not a null-check-operator error or a
// TypeError from an unguarded cast. Also guards each key individually
// rather than delegating to `Map<String, Object?>.from(value)` — that
// factory's own implementation does an unguarded `k as String` per entry
// (see dart:collection's LinkedHashMap.from), so a non-String key would
// still surface as an uncaught TypeError instead of FormatException. Only
// jsonDecode-sourced maps reach this today (always String-keyed), but the
// `Map<Object?, Object?>` type check above exists specifically to also
// accept platform-channel (StandardMessageCodec) payloads, which CAN carry
// non-String keys — this closes that path before it's ever wired up.
Map<String, Object?> _requiredMap(Object? value, String key) {
  if (value is! Map<Object?, Object?>) {
    throw FormatException('Invalid $key');
  }
  final result = <String, Object?>{};
  for (final entry in value.entries) {
    final entryKey = entry.key;
    if (entryKey is! String) {
      throw FormatException('Invalid $key');
    }
    result[entryKey] = entry.value;
  }
  return result;
}
