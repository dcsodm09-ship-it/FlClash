import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:fl_clash/hgfast/repository/hgfast_endpoints.dart';
import 'package:fl_clash/hgfast/repository/hgfast_repository_impl.dart';
import 'package:fl_clash/hgfast/repository/hgfast_result_x.dart';
import 'package:fl_clash/hgfast/transport/device_identity.dart';
import 'package:fl_clash/hgfast/transport/primitives.dart' as primitives;
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_secure_storage/test/test_flutter_secure_storage_platform.dart';
import 'package:flutter_secure_storage_platform_interface/flutter_secure_storage_platform_interface.dart';
import 'package:flutter_test/flutter_test.dart';

const String _rootPubB64 = '0EqyMnQrtKs6E2i9RhXk5tAiSrcaAWuvhSCjMsl3hzc=';
const int _rootEpoch = 1;

const String _bootstrapRequestHash =
    '291ff242861fb6566db9df886d893286ea9cf2f052a6736a912388c842fb34b4';

final Map<String, Object?> _bootstrapResponseBody = <String, Object?>{
  'envelope': <String, Object?>{
    'purpose': 'HGFAST-C-RESPONSE-/api/client/android/v1/config/bootstrap-v1',
    'user_id': 0,
    'session_id': 'sess-anon',
    'request_hash': _bootstrapRequestHash,
    'nonce': 'aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa',
    'issued_at': 1755300000,
    'expires_at': 1755300090,
    'body_hash':
        'e2bbd56f45788f9c1c83c21c931b8452360c339e9f25d9ba0e5d0a6389bc3f42',
    'schema_version': 1,
    'app_id': 'hgfast',
    'channel': 'stable',
    'platform': 'android',
  },
  'body_jcs':
      '{"enc":"hpke-x25519-chacha20poly1305","pool_version":1,"sealed_pool":"FMqeTTh7zPNXRuBAfaqsxrKKT4RF71pRWIlNuYPiQHBHiv4tUefPNW/i9/d7s1n2yDINOGDIqmIV8j5n+ju6Z+nJHgPgbrfoyY1og3qDMgMpVbjXCO6p24R76O15N6EiTdhthHY2Zm8P0OZxFrYBsrCklmFjK5r4rLcD9XIo1NbOYB7e7enjiWB88GH0Pw8lz3qw2tgEKZPwAFAqzFXBBiTrlWaf4G/jZDRBIXSW9VT7wALwk0VRZQgtyaWOCO4tgOWX93MaqvdlPqLv518Ant59pvNmpu9l8YIsIccQ4lWf5yDOlWc1O6MmTQfjFxihQQN8tUjWVK4dSCvyXwerklqDjQO8PLRr+xi8EcfNGUW+jSS/JLImeloaZqq8OHcyFvf/NAqZrW1qfOOEmfVhRdg/k/WUioy4mKI8o43DmSvyO7ekqa1UfGi7pY2g4dLsuc/LA2QoibcmcRsu2P8yh4lDUa5zH36RFY+iaQgZXCtLNQjjZ6lWsNaKluq2JnfU4uYLp33YQpsQjMgxFgag2k7x27Wig0Z5u7ZnC/FJ45AjUcm8MY56bezX6C3cLONNHMxlsEwaQn2PjjENnZO57Rq5R2xYJj8VYjDoY/w0eLfngdGCxbn5yZt0dhkdywU7ZRczKY7M2a1QolnhyFQbPhCOnYOiE0oRKizuhvq82bmeaxgdL7/LlEfaH9SeK1p5Xu37cGbTD1fKOSeaPsCY0tzf2yseg/UFYrbbZS+Ev60aqrRezmyVbrTpoq43dpsFuSNQn71skREBLXSyO3+ypoGW19TFJ7PZZnxzQe+qmPqUqwThfBC7mdR5LrCyr8YS6DQ8ABLkW4LMGK0IP8cr4NkaMd1i2Bgrex7g+Qr+Js1+WXm8VPiFrbYRGiecQsy6FQ6c6tQAcdE26mYRCzebKLsnwQA+1IUUHBm0wxnXBrec1Mvqb7zP7Y/m2ZytGguagNMdU1328IZ2bQ30xJMB3LMql69iyHyBZpfAhyXnDPhuxMaMzODOvSvSYBYL7lL9zBgziWSe9pma5zqabyhX6irWLo6RGvTvS4USchSeTs/K0Nb31EN0ubBgZQf/eVZudiLoOaEw81QySSoYab0DDuxoIE2dLItEQFCQdS8ZLgE42egXTencPVUdXz+U/hBfs7L5FPr9ML+2mMecPjtuW51X1MtxJ0ZV45GdN1lPKjui2R+lz/SpLV4J5WTeGe28TN/4yrqzoiDCB42NlSqSVCJ/HLC+mVSUtw4EG7KV00sIBO5IMTbRDX5I/KBDXtYIG7yQ6w0bn53ZOwKv4SHtQDpNkkcd"}',
  'sig':
      'TKikUs3TcTicWNdfPkrw01no825v4pIoorfbbjGffQr7jU9hBgGB4SX2Z7+0rMnlkYMk1nlqc9Y0W1NqMBBXDQ==',
  'cert': <String, Object?>{
    'v': 'HGFAST-SUBKEY-CERT-v1',
    'key_id': 'test-cresponse-1',
    'subkey_pub': 'F8t5+ytBIPKx7GXkGY1uCLKOgT/rAeSkAIObheGAgM4=',
    'usage': 'C_RESPONSE',
    'valid_from_epoch': 1,
    'valid_to_epoch': 10,
    'root_sig':
        'ylHe8NeJgHTdS5kE4g5K6zMyDx2RWKr8Orzbz+1uCa4c8+lBjXdwYwO264I6eQ/hE68FuZZnBfXnQxXTFcB+AQ==',
  },
};

const String _loginRequestBody =
    '{"client_eph_pub":"OKtmS9hvd9fma92a4HkpE6lP2LM6EmACfktGwfSITGc=",'
    '"prekey_id":"test-prekey-1",'
    '"sealed_credentials":"MNPIZaSPzrPWEYV3zy5fIo1v9phmJkdXeFslPLekgGoG1OWZOmomiU8u'
    'J153ZoyxF4tXYQoaLhStIEfWL8WtTHndC7YcWvBfVfeRbPDIzYdXAQVakOrXqtTrhpKvkLxTl5Fkmokg"}';

const String _loginRequestHash =
    '911d1baef634f87cd6aca363029e4ede23d7a6037acae94bccbbbe479d232dc4';

final Map<String, Object?> _loginResponseBody = <String, Object?>{
  'envelope': <String, Object?>{
    'purpose': 'HGFAST-C-RESPONSE-/api/client/android/v1/auth/login-v1',
    'user_id': 42,
    'session_id': 'sess-test-2222222222222222',
    'request_hash': _loginRequestHash,
    'nonce': 'aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa',
    'issued_at': 1755300000,
    'expires_at': 1755300090,
    'body_hash':
        '5cfc776ce9cf30fd200dc1b6cf52c881d1b1abda7eaceb3b5b4320abf6873850',
    'schema_version': 1,
    'app_id': 'hgfast',
    'channel': 'stable',
    'platform': 'android',
  },
  'body_jcs':
      '{"handshake":{"client_eph_pub_hash":"1128de8a3d96a514f1179e312936eb9e7f7fe0'
      '8e87f2274e908bf9d1bab7a71e","e2ee_salt":"qqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqq'
      'qqqqqqqqo=","kdf_info":"HGFAST-E2EE-SESSION-v1","server_eph_pub":"uhk4Ns/x'
      '9OhmwTlxXTBkCNJqdvdtY4o5r8EAEITSVBE=","session_key_id":"sk-test-1111111111'
      '111111","suite":"x25519-hkdf-sha256-chacha20poly1305"},"secure":{"aad":"ey'
      'JhcHBfaWQiOiJoZ2Zhc3QiLCJjaGFubmVsIjoic3RhYmxlIiwiZXhwaXJlc19hdCI6MTc1NTMwMD'
      'A5MCwiaXNzdWVkX2F0IjoxNzU1MzAwMDAwLCJub25jZSI6ImFhYWFhYWFhYWFhYWFhYWFhYWFhYW'
      'FhYWFhYWFhYWFhIiwicHVycG9zZSI6IkhHRkFTVC1DLVJFU1BPTlNFLS9hcGkvY2xpZW50L2FuZH'
      'JvaWQvdjEvYXV0aC9sb2dpbi12MSIsInJlcXVlc3RfaGFzaCI6IjkxMWQxYmFlZjYzNGY4N2NkNm'
      'FjYTM2MzAyOWU0ZWRlMjNkN2E2MDM3YWNhZTk0YmNjYmJiZTQ3OWQyMzJkYzQiLCJzZXNzaW9uX2'
      'lkIjoic2Vzcy10ZXN0LTIyMjIyMjIyMjIyMjIyMjIiLCJzZXNzaW9uX2tleV9pZCI6InNrLXRlc3'
      'QtMTExMTExMTExMTExMTExMSIsInVzZXJfaWQiOjQyfQ==","aead_nonce":"AAAAAAAAAAAAAA'
      'AB","ciphertext":"xCxuyzkNfaGa+YCQwrnqtlGAjTMBlCobVbaHmCtBTEFL60Vt1aVjQcETtM'
      '4FfrYHUeK49QHOl1pPEkpwSjjKWQbnJnVKignZLVLYkSvOk96PZklwrodx3xYtRvPQmBRNgQ4f/b'
      'NEHW8OZ2mX6FUc+p+3zyYPsEC+CaKfdrxWYHQmQuoxpUJK5l68cZh/z0iZLZyyGScgCGKJY8yU7Y'
      'hSuJnJ8kBQrtSA/rwjPU3XKL4IoxZEC6wKwwmyDai3gCcI6qweydHR6PX1p8c1SVMaCI98jNu9Lk'
      'IJRGxi1/ecuV9KIiPmYHKL4Y52LQ==","session_key_id":"sk-test-1111111111111111"'
      '},"session_id":"sess-test-2222222222222222"}',
  'sig':
      '2Lz0Tyn33B2Zr1MkUCPHJhwU7wybXc8T9ggZtflIQRJ8F+PtRM81l0jysRczFCvS+C5EQFhDQ2L+'
      'REdWPlK3DQ==',
  'cert': <String, Object?>{
    'v': 'HGFAST-SUBKEY-CERT-v1',
    'key_id': 'test-cresponse-1',
    'subkey_pub': 'F8t5+ytBIPKx7GXkGY1uCLKOgT/rAeSkAIObheGAgM4=',
    'usage': 'C_RESPONSE',
    'valid_from_epoch': 1,
    'valid_to_epoch': 10,
    'root_sig':
        'ylHe8NeJgHTdS5kE4g5K6zMyDx2RWKr8Orzbz+1uCa4c8+lBjXdwYwO264I6eQ/hE68FuZZnBfXnQxXTFcB+AQ==',
  },
};

class _RoutedHttpClientAdapter implements HttpClientAdapter {
  _RoutedHttpClientAdapter();

  String? capturedLoginRequestBody;

  @override
  void close({bool force = false}) {}

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    final path = options.uri.path;
    if (path.endsWith('/config/bootstrap')) {
      return ResponseBody.fromString(
        jsonEncode(_bootstrapResponseBody),
        200,
        headers: <String, List<String>>{
          'content-type': <String>['application/json'],
        },
      );
    }
    if (path.endsWith('/auth/login')) {
      final builder = BytesBuilder();
      if (requestStream != null) {
        await for (final chunk in requestStream) {
          builder.add(chunk);
        }
      }
      capturedLoginRequestBody = utf8.decode(builder.toBytes());
      return ResponseBody.fromString(
        jsonEncode(_loginResponseBody),
        200,
        headers: <String, List<String>>{
          'content-type': <String>['application/json'],
        },
      );
    }
    throw StateError('unexpected request path: $path');
  }
}

Future<HgfastRepositoryImpl> _buildSignedRepository(
  HttpClientAdapter adapter,
) async {
  final platform = TestFlutterSecureStoragePlatform(<String, String>{
    deviceSeedStorageKey: primitives.toBase64(
      List<int>.filled(32, 0x44),
    ),
  });
  FlutterSecureStoragePlatform.instance = platform;
  const storage = FlutterSecureStorage();
  final dio = Dio(BaseOptions())..httpClientAdapter = adapter;
  return HgfastRepositoryImpl(
    dio: dio,
    endpointPool: HgfastEndpointPool(seedHosts: const <String>['test.example.com']),
    platformSegment: HgfastPlatformSegment.android,
    deviceIdentityStore: HgfastDeviceIdentityStore(storage: storage),
    sessionStorage: storage,
    rootPublicKeys: <List<int>>[primitives.fromBase64(_rootPubB64)],
    rootEpoch: _rootEpoch,
    nonceGenerator: () => 'aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa',
    clockNowSeconds: () => 1755300000,
    ephemeralKeyPairGenerator: () => primitives.x25519KeyPairFromSeed(
      List<int>.filled(32, 0x55),
    ),
    hpkeSealEphemeralSeed: () => List<int>.filled(32, 0x88),
  );
}

void main() {
  test(
    'bootstrap() verifies a genuinely signed+HPKE-sealed response from the '
    'real backend crypto libraries and extracts the server prekey',
    () async {
      final repository = await _buildSignedRepository(_RoutedHttpClientAdapter());

      final result = await repository.bootstrap();

      final bootstrap = result.successValue;
      expect(result.failureError, isNull);
      expect(bootstrap, isNotNull);
      final prekey = bootstrap!.values['server_static_prekey'];
      expect(prekey, isA<Map>());
      expect((prekey! as Map)['prekey_id'], 'test-prekey-1');
      expect(bootstrap.values['pool_version'], 1);
    },
  );

  test(
    'login() drives the full bootstrap-for-prekey + HPKE-sealed credential '
    'request + signed/E2EE-sealed response verification against fixtures '
    'produced by the real backend crypto libraries',
    () async {
      final adapter = _RoutedHttpClientAdapter();
      final repository = await _buildSignedRepository(adapter);

      final result = await repository.login(
        credential: 'test@example.com',
        password: 'hunter2',
      );

      expect(
        adapter.capturedLoginRequestBody,
        _loginRequestBody,
        reason:
            'the client must send byte-identical HPKE-sealed request bytes '
            'to what the real backend crypto libraries produced for the '
            'same deterministic inputs',
      );

      final session = result.successValue;
      expect(result.failureError, isNull);
      expect(session, isNotNull);
      expect(session!.values['session_id'], 'sess-test-2222222222222222');
      expect(session.values['email'], 'test@example.com');
      expect(session.values['user_id'], 42);
      expect(session.values['plan_id'], 1);
    },
  );

  test(
    'login() rejects the fixture response if the envelope signature is '
    'tampered with, instead of trusting an unsigned field',
    () async {
      final tamperedLoginResponse = <String, Object?>{
        ..._loginResponseBody,
        'envelope': <String, Object?>{
          ...(_loginResponseBody['envelope']! as Map<String, Object?>),
          'user_id': 999,
        },
      };
      final tamperedAdapter = _TamperedLoginAdapter(tamperedLoginResponse);
      final repository = await _buildSignedRepository(tamperedAdapter);

      final result = await repository.login(
        credential: 'test@example.com',
        password: 'hunter2',
      );

      expect(result.successValue, isNull);
      expect(result.failureError?.message, contains('BadSignature'));
    },
  );
}

class _TamperedLoginAdapter implements HttpClientAdapter {
  _TamperedLoginAdapter(this.tamperedLoginResponse);

  final Map<String, Object?> tamperedLoginResponse;

  @override
  void close({bool force = false}) {}

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    final path = options.uri.path;
    if (path.endsWith('/config/bootstrap')) {
      return ResponseBody.fromString(
        jsonEncode(_bootstrapResponseBody),
        200,
        headers: <String, List<String>>{
          'content-type': <String>['application/json'],
        },
      );
    }
    if (path.endsWith('/auth/login')) {
      return ResponseBody.fromString(
        jsonEncode(tamperedLoginResponse),
        200,
        headers: <String, List<String>>{
          'content-type': <String>['application/json'],
        },
      );
    }
    throw StateError('unexpected request path: $path');
  }
}
