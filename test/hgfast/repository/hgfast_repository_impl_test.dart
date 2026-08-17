import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:fl_clash/hgfast/models/error.dart';
import 'package:fl_clash/hgfast/repository/hgfast_endpoints.dart';
import 'package:fl_clash/hgfast/repository/hgfast_repository_impl.dart';
import 'package:fl_clash/hgfast/repository/hgfast_result_x.dart';
import 'package:fl_clash/hgfast/transport/device_identity.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_secure_storage/test/test_flutter_secure_storage_platform.dart';
import 'package:flutter_secure_storage_platform_interface/flutter_secure_storage_platform_interface.dart';
import 'package:flutter_test/flutter_test.dart';

class _FakeHttpClientAdapter implements HttpClientAdapter {
  _FakeHttpClientAdapter(this.responder);

  final ResponseBody Function(RequestOptions options) responder;

  @override
  void close({bool force = false}) {}

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    return responder(options);
  }
}

HgfastRepositoryImpl _buildRepository(
  ResponseBody Function(RequestOptions options) responder,
) {
  final platform = TestFlutterSecureStoragePlatform(<String, String>{});
  FlutterSecureStoragePlatform.instance = platform;
  const storage = FlutterSecureStorage();
  final dio = Dio(BaseOptions())..httpClientAdapter = _FakeHttpClientAdapter(responder);
  return HgfastRepositoryImpl(
    dio: dio,
    endpointPool: HgfastEndpointPool(seedHosts: const <String>['test.example.com']),
    platformSegment: HgfastPlatformSegment.android,
    deviceIdentityStore: HgfastDeviceIdentityStore(storage: storage),
    sessionStorage: storage,
  );
}

ResponseBody _jsonResponse(Object? body, int status) {
  return ResponseBody.fromString(
    jsonEncode(body),
    status,
    headers: <String, List<String>>{
      'content-type': <String>['application/json'],
    },
  );
}

void main() {
  test(
    'a non-string server error code does not throw and maps to '
    'clientApiStateUnavailable',
    () async {
      final repository = _buildRepository(
        (options) => _jsonResponse(<String, Object?>{
          'code': 503,
          'maintenance': true,
        }, 503),
      );

      final result = await repository.config();

      expect(result.failureError, isA<HgfastClientApiStateUnavailable>());
    },
  );

  test(
    'a non-string server error code during the pre-login bootstrap fetch '
    'does not throw and is not misreported as a wrong password',
    () async {
      final repository = _buildRepository(
        (options) => _jsonResponse(<String, Object?>{'code': 503}, 503),
      );

      final result = await repository.login(
        credential: 'a@b.com',
        password: 'x',
      );

      expect(result.failureError, isNotNull);
      expect(result.failureError, isNot(isA<HgfastAuthFailed>()));
    },
  );

  test('a non-JSON-map 200 body does not throw and fails closed', () async {
    final repository = _buildRepository(
      (options) => ResponseBody.fromString('"just a string"', 200),
    );

    final result = await repository.plans();

    expect(result.failureError, isA<HgfastClientApiStateUnavailable>());
  });

  test(
    'an authed call with no stored session fails without ever touching '
    'the network',
    () async {
      var called = false;
      final repository = _buildRepository((options) {
        called = true;
        return _jsonResponse(<String, Object?>{'code': 'AUTH_FAILED'}, 401);
      });

      final result = await repository.nodes();

      expect(result.failureError, isA<HgfastAuthFailed>());
      expect(called, isFalse);
    },
  );

  test('an unknown platform fails closed without touching the network', () async {
    var called = false;
    final platform = TestFlutterSecureStoragePlatform(<String, String>{});
    FlutterSecureStoragePlatform.instance = platform;
    const storage = FlutterSecureStorage();
    final dio = Dio(BaseOptions())
      ..httpClientAdapter = _FakeHttpClientAdapter((options) {
        called = true;
        return _jsonResponse(<String, Object?>{}, 200);
      });
    final repository = HgfastRepositoryImpl(
      dio: dio,
      endpointPool: HgfastEndpointPool(seedHosts: const <String>['test.example.com']),
      platformSegment: null,
      deviceIdentityStore: HgfastDeviceIdentityStore(storage: storage),
      sessionStorage: storage,
    );

    final result = await repository.config();

    expect(result.failureError, isA<HgfastClientApiStateUnavailable>());
    expect(called, isFalse);
  });
}
