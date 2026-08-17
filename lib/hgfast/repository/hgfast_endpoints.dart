import 'package:fl_clash/common/common.dart';

enum HgfastPlatformSegment {
  android('android'),
  windows('win'),
  macos('macos');

  const HgfastPlatformSegment(this.pathSegment);

  final String pathSegment;
}

HgfastPlatformSegment? resolveHgfastPlatformSegment() {
  if (system.isAndroid) {
    return HgfastPlatformSegment.android;
  }
  if (system.isWindows) {
    return HgfastPlatformSegment.windows;
  }
  if (system.isMacOS) {
    return HgfastPlatformSegment.macos;
  }
  return null;
}

const String hgfastSeedEndpointsDefine = String.fromEnvironment(
  'HGFAST_SEED_ENDPOINTS',
);

final class HgfastEndpointPoolConfigurationException implements Exception {
  const HgfastEndpointPoolConfigurationException();

  @override
  String toString() {
    return 'HgfastEndpointPoolConfigurationException: no HGFAST_SEED_ENDPOINTS '
        'dart-define was provided at build time';
  }
}

List<String> parseHgfastSeedEndpoints(String raw) {
  return raw
      .split(',')
      .map((host) => host.trim())
      .where((host) => host.isNotEmpty)
      .toList(growable: false);
}

final class HgfastEndpointPool {
  HgfastEndpointPool({List<String>? seedHosts})
    : _hosts = seedHosts ?? parseHgfastSeedEndpoints(hgfastSeedEndpointsDefine);

  final List<String> _hosts;
  int _index = 0;

  bool get isConfigured => _hosts.isNotEmpty;

  String currentHost() {
    if (_hosts.isEmpty) {
      throw const HgfastEndpointPoolConfigurationException();
    }
    return _hosts[_index % _hosts.length];
  }

  void reportFailure() {
    if (_hosts.length <= 1) {
      return;
    }
    _index = (_index + 1) % _hosts.length;
  }
}
