import 'package:fl_clash/hgfast/repository/hgfast_endpoints.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('parseHgfastSeedEndpoints', () {
    test('splits, trims and drops empty entries', () {
      expect(
        parseHgfastSeedEndpoints(' a.example.com ,, b.example.com,'),
        <String>['a.example.com', 'b.example.com'],
      );
    });

    test('returns an empty list for an empty string', () {
      expect(parseHgfastSeedEndpoints(''), isEmpty);
    });
  });

  group('HgfastEndpointPool', () {
    test('throws a configuration error when no hosts are seeded', () {
      final pool = HgfastEndpointPool(seedHosts: const <String>[]);
      expect(pool.isConfigured, isFalse);
      expect(
        pool.currentHost,
        throwsA(isA<HgfastEndpointPoolConfigurationException>()),
      );
    });

    test('sticks to the current host until a failure is reported', () {
      final pool = HgfastEndpointPool(
        seedHosts: const <String>['a.example.com', 'b.example.com'],
      );
      expect(pool.currentHost(), 'a.example.com');
      expect(pool.currentHost(), 'a.example.com');
      pool.reportFailure();
      expect(pool.currentHost(), 'b.example.com');
      pool.reportFailure();
      expect(pool.currentHost(), 'a.example.com');
    });

    test('reportFailure is a no-op with a single host', () {
      final pool = HgfastEndpointPool(seedHosts: const <String>['only.example.com']);
      pool.reportFailure();
      expect(pool.currentHost(), 'only.example.com');
    });
  });
}
