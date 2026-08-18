import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';

import 'package:cryptography/cryptography.dart' as cg;
import 'package:dio/dio.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import '../models/error.dart';
import '../models/node.dart';
import '../transport/device_identity.dart';
import '../transport/e2ee.dart' as e2ee;
import '../transport/jcs.dart' as jcs;
import '../transport/primitives.dart' as primitives;
import '../transport/reqsign.dart' as reqsign;
import '../transport/respwrap.dart' as respwrap;
import '../transport/signing.dart' as signing;
import '../transport/trust_roots.dart' as trust_roots;
import 'hgfast_endpoints.dart';
import 'hgfast_error_mapping.dart';
import 'hgfast_result_x.dart';
import 'hpke.dart' as hpke;
import 'repository.dart';

const String _tokenStorageKey = 'hgfast_session_token';
const String _sessionIdStorageKey = 'hgfast_session_id';
const String _sessionKeyStorageKey = 'hgfast_session_key';
const String _sessionKeyIdStorageKey = 'hgfast_session_key_id';
const String _userIdStorageKey = 'hgfast_session_user_id';
const String _profileStorageKey = 'hgfast_session_profile';

final class _HgfastActiveSession {
  const _HgfastActiveSession({
    required this.token,
    required this.sessionId,
    required this.sessionKey,
    required this.sessionKeyId,
    required this.userId,
  });

  final String token;
  final String sessionId;
  final Uint8List sessionKey;
  final String sessionKeyId;
  final Object? userId;
}

final class _HgfastMappedError implements Exception {
  const _HgfastMappedError(this.error);

  final HgfastError error;
}

const Object _autoDetectPlatformSegment = Object();

// `server_static_prekey.valid_to_epoch` (from GET /config/bootstrap) is a
// root-key-generation counter — the same small monotonic space cert
// validity windows use (see hgfast/transport/signing.dart's verifyCert:
// `rootEpoch < validFrom || rootEpoch > validTo`) — NOT Unix wall-clock
// seconds. A prior version of the prekey-freshness check in _bootstrap()
// compared it against wall-clock time instead, internally inconsistent
// with how this same client verifies cert epochs a few lines away
// (bConfigCert/cResponseCert, both checked against rootEpoch). That made
// every real prekey — minted with a small counter value, e.g. "valid
// through root epoch 4" — look permanently "expired" against a
// ~1.7-billion-second wall clock, so _ensurePrekey() could never cache
// one and every login failed with "bootstrap prekey unavailable" (first
// reported live as macOS login spinning, then reproduced identically on
// Android — this was a production-wide outage across every platform, not
// a macOS-specific bug). Root epoch only bumps on deliberate root-key
// rotation, so this is the same low-frequency "epoch" this file already
// uses everywhere else for cert validity. Pulled out as a top-level
// function so the exact bug (a mismatched semantics regression) has a
// direct unit test, not just fixture-level coverage.
bool isPrekeyExpired(Object? validToEpoch, int rootEpoch) {
  return validToEpoch is int && validToEpoch < rootEpoch;
}

String _defaultGenerateNonce() {
  final random = Random.secure();
  final bytes = Uint8List.fromList(
    List<int>.generate(16, (_) => random.nextInt(256)),
  );
  return primitives.toHex(bytes);
}

int _defaultClockNowSeconds() {
  return DateTime.now().toUtc().millisecondsSinceEpoch ~/ 1000;
}

Future<cg.SimpleKeyPair> _defaultEphemeralKeyPairGenerator() {
  return primitives.x25519NewKeyPair();
}

List<int>? _defaultNullSeed() => null;

final class HgfastRepositoryImpl implements HgfastRepository {
  HgfastRepositoryImpl({
    Dio? dio,
    HgfastEndpointPool? endpointPool,
    HgfastDeviceIdentityStore? deviceIdentityStore,
    FlutterSecureStorage? sessionStorage,
    List<List<int>>? rootPublicKeys,
    int? rootEpoch,
    Object? platformSegment = _autoDetectPlatformSegment,
    String Function()? nonceGenerator,
    int Function()? clockNowSeconds,
    Future<cg.SimpleKeyPair> Function()? ephemeralKeyPairGenerator,
    List<int>? Function()? hpkeSealEphemeralSeed,
  }) : _dio =
           dio ??
           Dio(
             BaseOptions(
               connectTimeout: const Duration(seconds: 10),
               receiveTimeout: const Duration(seconds: 15),
             ),
           ),
       _endpointPool = endpointPool ?? HgfastEndpointPool(),
       _deviceIdentityStore = deviceIdentityStore ?? HgfastDeviceIdentityStore(),
       _sessionStorage = sessionStorage ?? defaultHgfastSecureStorage,
       _rootPublicKeys = rootPublicKeys ?? trust_roots.productionRootPublicKeys,
       _rootEpoch = rootEpoch ?? trust_roots.productionRootEpoch,
       _platformSegment = identical(platformSegment, _autoDetectPlatformSegment)
           ? resolveHgfastPlatformSegment()
           : platformSegment as HgfastPlatformSegment?,
       _nonceGenerator = nonceGenerator ?? _defaultGenerateNonce,
       _clockNowSeconds = clockNowSeconds ?? _defaultClockNowSeconds,
       _ephemeralKeyPairGenerator =
           ephemeralKeyPairGenerator ?? _defaultEphemeralKeyPairGenerator,
       _hpkeSealEphemeralSeed = hpkeSealEphemeralSeed ?? _defaultNullSeed;

  final Dio _dio;
  final HgfastEndpointPool _endpointPool;
  final HgfastDeviceIdentityStore _deviceIdentityStore;
  final FlutterSecureStorage _sessionStorage;
  final List<List<int>> _rootPublicKeys;
  final int _rootEpoch;
  final HgfastPlatformSegment? _platformSegment;
  final String Function() _nonceGenerator;
  final int Function() _clockNowSeconds;
  final Future<cg.SimpleKeyPair> Function() _ephemeralKeyPairGenerator;
  final List<int>? Function() _hpkeSealEphemeralSeed;

  HgfastDeviceIdentity? _deviceIdentityCache;
  _HgfastActiveSession? _activeSession;
  int _clockOffsetSeconds = 0;
  String? _cachedPrekeyId;
  Uint8List? _cachedPrekeyPubRaw;

  void dispose() {
    _dio.close(force: true);
  }

  @override
  Future<HgfastResult<HgfastSession, HgfastError>> login({
    required String credential,
    required String password,
  }) {
    return _login(
      credential: credential,
      password: password,
      allowClockRetry: true,
      allowPrekeyRetry: true,
    );
  }

  Future<HgfastResult<HgfastSession, HgfastError>> _login({
    required String credential,
    required String password,
    required bool allowClockRetry,
    required bool allowPrekeyRetry,
  }) async {
    final segment = _platformSegment;
    if (segment == null) {
      return const HgfastResult.failure(
        HgfastError.clientApiStateUnavailable(
          message: 'HGFAST client_api is not available on this platform yet',
        ),
      );
    }
    final prekeyError = await _ensurePrekey();
    if (prekeyError != null) {
      return HgfastResult.failure(prekeyError);
    }
    final prekeyId = _cachedPrekeyId;
    final prekeyPubRaw = _cachedPrekeyPubRaw;
    if (prekeyId == null || prekeyPubRaw == null) {
      return const HgfastResult.failure(
        HgfastError.clientApiStateUnavailable(
          message: 'bootstrap prekey unavailable',
        ),
      );
    }

    final fullPath = '/api/client/${segment.pathSegment}/v1/auth/login';
    final nonce = _generateNonce();
    final timestamp = _currentTimestamp();
    final deviceId = (await _deviceIdentity()).deviceId;

    final loginEphemeralKeyPair = await _ephemeralKeyPairGenerator();
    final loginEphemeralPublicKey = await loginEphemeralKeyPair
        .extractPublicKey();
    final loginEphemeralPublicKeyRaw = Uint8List.fromList(
      loginEphemeralPublicKey.bytes,
    );
    final loginEphemeralPublicKeyB64 = primitives.toBase64(
      loginEphemeralPublicKeyRaw,
    );

    final sealAad = jcs.jcsBytes(<String, Object?>{
      'api_path': fullPath,
      'client_eph_pub': loginEphemeralPublicKeyB64,
      'device': deviceId,
      'nonce': nonce,
      'platform': segment.pathSegment,
      'prekey_id': prekeyId,
      'ts': timestamp,
    });
    final credentialsPlaintext = utf8.encode(
      jsonEncode(<String, Object?>{
        'credential': credential,
        'password': password,
      }),
    );
    final Uint8List sealedCredentials;
    try {
      sealedCredentials = await hpke.hpkeSealBase(
        recipientPublicKeyRaw: prekeyPubRaw,
        info: utf8.encode('HGFAST-REQ-SEAL-$fullPath-v1'),
        aad: sealAad,
        plaintext: credentialsPlaintext,
        ephemeralSeed: _hpkeSealEphemeralSeed(),
      );
    } on Object catch (error) {
      return HgfastResult.failure(
        HgfastError.clientApiStateUnavailable(
          message: 'credential seal failed: ${error.runtimeType}',
        ),
      );
    }

    final requestBody = <String, Object?>{
      'client_eph_pub': loginEphemeralPublicKeyB64,
      'prekey_id': prekeyId,
      'sealed_credentials': primitives.toBase64(sealedCredentials),
    };
    final bodyJson = jsonEncode(requestBody);
    final bodyBytes = utf8.encode(bodyJson);
    final headers = reqsign.buildRequestHeaders(
      method: 'POST',
      pathname: fullPath,
      body: bodyBytes,
      nonce: nonce,
      timestamp: timestamp,
      deviceId: deviceId,
      token: '',
    );

    final String host;
    try {
      host = _endpointPool.currentHost();
    } on HgfastEndpointPoolConfigurationException catch (error) {
      return HgfastResult.failure(
        HgfastError.clientApiStateUnavailable(message: error.toString()),
      );
    }

    final Response<Object?> response;
    try {
      response = await _dio.requestUri<Object?>(
        Uri.https(host, fullPath),
        data: bodyJson,
        options: Options(
          method: 'POST',
          headers: headers.toHeaders(),
          contentType: Headers.jsonContentType,
          validateStatus: (_) => true,
          responseType: ResponseType.json,
        ),
      );
    } on Object catch (error) {
      _endpointPool.reportFailure();
      return HgfastResult.failure(
        HgfastError.clientApiStateUnavailable(
          message: 'network error: ${error.runtimeType}',
        ),
      );
    }

    final status = response.statusCode ?? 0;
    final data = response.data;
    if (status != 200) {
      _endpointPool.reportFailure();
      final code = _stringOrNull(data, 'code');
      final message = _stringOrNull(data, 'message');
      if (allowClockRetry && code != null && code.startsWith('C1_')) {
        final resynced = await _resyncClock();
        if (resynced) {
          return _login(
            credential: credential,
            password: password,
            allowClockRetry: false,
            allowPrekeyRetry: allowPrekeyRetry,
          );
        }
      }
      if (allowPrekeyRetry && code == 'SEAL_OPEN_FAIL') {
        _cachedPrekeyId = null;
        _cachedPrekeyPubRaw = null;
        return _login(
          credential: credential,
          password: password,
          allowClockRetry: allowClockRetry,
          allowPrekeyRetry: false,
        );
      }
      return HgfastResult.failure(
        mapHgfastErrorCode(code, message, HgfastResource.login),
      );
    }
    if (data is! Map) {
      return const HgfastResult.failure(
        HgfastError.clientApiStateUnavailable(
          message: 'malformed response envelope',
        ),
      );
    }

    final verified = await _verifyFreshEnvelope(
      response: Map<String, Object?>.from(data),
      requestHash: headers.requestHash,
      nonce: nonce,
      now: int.parse(timestamp),
    );
    final verifiedValue = verified.successValue;
    if (verifiedValue == null) {
      return HgfastResult.failure(
        verified.failureError ??
            const HgfastError.clientApiStateUnavailable(),
      );
    }

    final envelope = verifiedValue.envelope;
    final body = verifiedValue.body;
    final userId = envelope['user_id'];
    final sessionId = envelope['session_id'];
    final handshakeRaw = body['handshake'];
    final secureRaw = body['secure'];
    if (sessionId is! String || handshakeRaw is! Map || secureRaw is! Map) {
      return const HgfastResult.failure(
        HgfastError.clientApiStateUnavailable(
          message: 'malformed login response',
        ),
      );
    }
    final handshake = Map<String, Object?>.from(handshakeRaw);
    final serverEphPubB64 = handshake['server_eph_pub'];
    final e2eeSaltB64 = handshake['e2ee_salt'];
    final sessionKeyId = handshake['session_key_id'];
    final clientEphPubHash = handshake['client_eph_pub_hash'];
    if (serverEphPubB64 is! String ||
        e2eeSaltB64 is! String ||
        sessionKeyId is! String ||
        clientEphPubHash is! String) {
      return const HgfastResult.failure(
        HgfastError.clientApiStateUnavailable(
          message: 'malformed login handshake',
        ),
      );
    }
    final expectedClientEphHash = primitives.toHex(
      primitives.sha256(loginEphemeralPublicKeyRaw),
    );
    if (!primitives.timingSafeEqualBytes(
      utf8.encode(expectedClientEphHash),
      utf8.encode(clientEphPubHash),
    )) {
      return const HgfastResult.failure(
        HgfastError.clientApiStateUnavailable(
          message: 'login handshake key mismatch',
        ),
      );
    }

    final Uint8List sessionKey;
    try {
      sessionKey = await e2ee.deriveSessionKeyClient(
        clientEphemeralKeyPair: loginEphemeralKeyPair,
        serverEphemeralPublicKeyRaw: primitives.fromBase64(serverEphPubB64),
        salt: primitives.fromBase64(e2eeSaltB64),
      );
    } on Object catch (error) {
      return HgfastResult.failure(
        HgfastError.clientApiStateUnavailable(
          message: 'session key derivation failed: ${error.runtimeType}',
        ),
      );
    }

    final expectedAad = <String, Object?>{
      'app_id': envelope['app_id'],
      'channel': envelope['channel'],
      'expires_at': envelope['expires_at'],
      'issued_at': envelope['issued_at'],
      'nonce': envelope['nonce'],
      'purpose': envelope['purpose'],
      'request_hash': envelope['request_hash'],
      'session_id': sessionId,
      'session_key_id': sessionKeyId,
      'user_id': userId,
    };
    final Object? opened;
    try {
      opened = await e2ee.openResponse(
        sessionKey: sessionKey,
        blob: Map<String, Object?>.from(secureRaw),
        expectedAad: expectedAad,
      );
    } on Object catch (error) {
      return HgfastResult.failure(
        HgfastError.clientApiStateUnavailable(
          message: 'secure field open failed: ${error.runtimeType}',
        ),
      );
    }
    if (opened is! Map) {
      return const HgfastResult.failure(
        HgfastError.clientApiStateUnavailable(
          message: 'malformed secure field',
        ),
      );
    }
    final openedMap = Map<String, Object?>.from(opened);
    final token = openedMap['token'];
    final profileRaw = openedMap['profile'];
    if (token is! String || profileRaw is! Map) {
      return const HgfastResult.failure(
        HgfastError.clientApiStateUnavailable(
          message: 'malformed secure field',
        ),
      );
    }
    final profile = Map<String, Object?>.from(profileRaw);

    final session = _HgfastActiveSession(
      token: token,
      sessionId: sessionId,
      sessionKey: sessionKey,
      sessionKeyId: sessionKeyId,
      userId: userId,
    );
    final persisted = await _persistSession(session, profile);
    final persistError = persisted.failureError;
    if (persistError != null) {
      return HgfastResult.failure(persistError);
    }

    return HgfastResult.success(
      HgfastSession(<String, Object?>{...profile, 'session_id': sessionId}),
    );
  }

  Future<
    HgfastResult<
      ({Map<String, Object?> envelope, Map<String, Object?> body}),
      HgfastError
    >
  >
  _verifyFreshEnvelope({
    required Map<String, Object?> response,
    required String requestHash,
    required String nonce,
    required int now,
  }) async {
    final envelopeRaw = response['envelope'];
    final certRaw = response['cert'];
    final bodyJcs = response['body_jcs'];
    final sig = response['sig'];
    if (envelopeRaw is! Map ||
        certRaw is! Map ||
        bodyJcs is! String ||
        sig is! String) {
      return const HgfastResult.failure(
        HgfastError.clientApiStateUnavailable(
          message: 'malformed signed response',
        ),
      );
    }
    final envelope = Map<String, Object?>.from(envelopeRaw);
    final cert = Map<String, Object?>.from(certRaw);
    if (envelope['request_hash'] != requestHash) {
      return const HgfastResult.failure(
        HgfastError.clientApiStateUnavailable(message: 'RequestMismatch'),
      );
    }
    if (envelope['nonce'] != nonce) {
      return const HgfastResult.failure(
        HgfastError.clientApiStateUnavailable(message: 'NonceMismatch'),
      );
    }
    final issuedAt = envelope['issued_at'];
    final expiresAt = envelope['expires_at'];
    if (issuedAt is! int || expiresAt is! int) {
      return const HgfastResult.failure(
        HgfastError.clientApiStateUnavailable(
          message: 'malformed signed response',
        ),
      );
    }
    if (now < issuedAt || now > expiresAt) {
      return const HgfastResult.failure(
        HgfastError.clientApiStateUnavailable(
          message: 'response outside validity window',
        ),
      );
    }
    final bodyHash = primitives.toHex(primitives.sha256(utf8.encode(bodyJcs)));
    if (bodyHash != envelope['body_hash']) {
      return const HgfastResult.failure(
        HgfastError.clientApiStateUnavailable(message: 'BodyHashMismatch'),
      );
    }
    final verifyResult = await signing.verifyEnvelope(
      envelope: envelope,
      signatureBase64: sig,
      cert: cert,
      rootPublicKeys: _rootPublicKeys,
      rootEpoch: _rootEpoch,
    );
    if (!verifyResult.isOk) {
      return HgfastResult.failure(
        HgfastError.clientApiStateUnavailable(message: verifyResult.error),
      );
    }
    final Object? decodedBody;
    try {
      decodedBody = jsonDecode(bodyJcs);
    } on FormatException {
      return const HgfastResult.failure(
        HgfastError.clientApiStateUnavailable(
          message: 'malformed signed response',
        ),
      );
    }
    if (decodedBody is! Map) {
      return const HgfastResult.failure(
        HgfastError.clientApiStateUnavailable(
          message: 'malformed signed response',
        ),
      );
    }
    return HgfastResult.success((
      envelope: envelope,
      body: Map<String, Object?>.from(decodedBody),
    ));
  }

  @override
  Future<HgfastResult<HgfastBootstrap, HgfastError>> bootstrap() {
    return _bootstrap(allowClockRetry: true);
  }

  Future<HgfastResult<HgfastBootstrap, HgfastError>> _bootstrap({
    required bool allowClockRetry,
  }) async {
    final segment = _platformSegment;
    if (segment == null) {
      return const HgfastResult.failure(
        HgfastError.clientApiStateUnavailable(
          message: 'HGFAST client_api is not available on this platform yet',
        ),
      );
    }
    final fullPath = '/api/client/${segment.pathSegment}/v1/config/bootstrap';
    final nonce = _generateNonce();
    final timestamp = _currentTimestamp();
    final deviceId = (await _deviceIdentity()).deviceId;

    final ephemeralKeyPair = await _ephemeralKeyPairGenerator();
    final ephemeralPublicKey = await ephemeralKeyPair.extractPublicKey();
    final ephemeralPublicKeyRaw = Uint8List.fromList(
      ephemeralPublicKey.bytes,
    );
    final ephemeralPublicKeyB64 = primitives.toBase64(ephemeralPublicKeyRaw);

    final headers = reqsign.buildRequestHeaders(
      method: 'GET',
      pathname: fullPath,
      body: const <int>[],
      nonce: nonce,
      timestamp: timestamp,
      deviceId: deviceId,
      token: '',
    );
    final requestHeaders = <String, String>{
      ...headers.toHeaders(),
      'X-HG-Eph': ephemeralPublicKeyB64,
    };

    final String host;
    try {
      host = _endpointPool.currentHost();
    } on HgfastEndpointPoolConfigurationException catch (error) {
      return HgfastResult.failure(
        HgfastError.clientApiStateUnavailable(message: error.toString()),
      );
    }

    final Response<Object?> response;
    try {
      response = await _dio.requestUri<Object?>(
        Uri.https(host, fullPath),
        options: Options(
          method: 'GET',
          headers: requestHeaders,
          validateStatus: (_) => true,
          responseType: ResponseType.json,
        ),
      );
    } on Object catch (error) {
      _endpointPool.reportFailure();
      return HgfastResult.failure(
        HgfastError.clientApiStateUnavailable(
          message: 'network error: ${error.runtimeType}',
        ),
      );
    }

    final status = response.statusCode ?? 0;
    final data = response.data;
    if (status != 200) {
      _endpointPool.reportFailure();
      final code = _stringOrNull(data, 'code');
      final message = _stringOrNull(data, 'message');
      if (allowClockRetry && code != null && code.startsWith('C1_')) {
        final resynced = await _resyncClock();
        if (resynced) {
          return _bootstrap(allowClockRetry: false);
        }
      }
      return HgfastResult.failure(
        mapHgfastErrorCode(code, message, HgfastResource.bootstrap),
      );
    }
    if (data is! Map) {
      return const HgfastResult.failure(
        HgfastError.clientApiStateUnavailable(
          message: 'malformed response envelope',
        ),
      );
    }

    final verified = await respwrap.verifySignedResponse(
      response: Map<String, Object?>.from(data),
      rootPublicKeys: _rootPublicKeys,
      rootEpoch: _rootEpoch,
      expect: respwrap.SignedResponseExpectation(
        userId: 0,
        sessionId: 'sess-anon',
        requestHash: headers.requestHash,
        nonce: nonce,
        now: int.parse(timestamp),
      ),
    );
    if (verified is respwrap.SignedResponseFailed) {
      return HgfastResult.failure(
        HgfastError.clientApiStateUnavailable(message: verified.error),
      );
    }
    final outerBody = (verified as respwrap.SignedResponseOk).body;
    if (outerBody is! Map) {
      return const HgfastResult.failure(
        HgfastError.clientApiStateUnavailable(
          message: 'malformed bootstrap envelope',
        ),
      );
    }
    final sealedPoolB64 = outerBody['sealed_pool'];
    if (sealedPoolB64 is! String) {
      return const HgfastResult.failure(
        HgfastError.clientApiStateUnavailable(
          message: 'malformed bootstrap envelope',
        ),
      );
    }

    final sealAad = jcs.jcsBytes(<String, Object?>{
      'api_path': fullPath,
      'client_eph_pub': ephemeralPublicKeyB64,
      'nonce': nonce,
      'platform': segment.pathSegment,
      'ts': timestamp,
    });
    final Uint8List openedBytes;
    try {
      openedBytes = await hpke.hpkeOpenBase(
        recipientKeyPair: ephemeralKeyPair,
        recipientPublicKeyRaw: ephemeralPublicKeyRaw,
        sealed: primitives.fromBase64(sealedPoolB64),
        info: utf8.encode('HGFAST-ENDPOINTPOOL-v1'),
        aad: sealAad,
      );
    } on Object catch (error) {
      return HgfastResult.failure(
        HgfastError.clientApiStateUnavailable(
          message: 'bootstrap open failed: ${error.runtimeType}',
        ),
      );
    }

    final Object? decoded;
    try {
      decoded = jsonDecode(utf8.decode(openedBytes));
    } on Object catch (error) {
      return HgfastResult.failure(
        HgfastError.clientApiStateUnavailable(
          message: 'malformed bootstrap payload: ${error.runtimeType}',
        ),
      );
    }
    if (decoded is! Map) {
      return const HgfastResult.failure(
        HgfastError.clientApiStateUnavailable(
          message: 'malformed bootstrap payload',
        ),
      );
    }
    final decodedMap = Map<String, Object?>.from(decoded);
    final bConfigCertRaw = decodedMap['b_config_cert'];
    final bConfigObjectRaw = decodedMap['b_config_object'];
    if (bConfigCertRaw is! Map || bConfigObjectRaw is! Map) {
      return const HgfastResult.failure(
        HgfastError.clientApiStateUnavailable(
          message: 'malformed bootstrap payload',
        ),
      );
    }
    final bConfigCert = Map<String, Object?>.from(bConfigCertRaw);
    final bConfigObject = Map<String, Object?>.from(bConfigObjectRaw);
    final innerVerify = await signing.verifyObject(
      obj: bConfigObject,
      cert: bConfigCert,
      rootPublicKeys: _rootPublicKeys,
      rootEpoch: _rootEpoch,
      expectedUsage: 'B_CONFIG',
    );
    if (!innerVerify.isOk) {
      return HgfastResult.failure(
        HgfastError.clientApiStateUnavailable(message: innerVerify.error),
      );
    }
    final poolBodyRaw = bConfigObject['body'];
    if (poolBodyRaw is! Map) {
      return const HgfastResult.failure(
        HgfastError.clientApiStateUnavailable(
          message: 'malformed bootstrap payload',
        ),
      );
    }
    final poolBody = Map<String, Object?>.from(poolBodyRaw);

    final prekeyRaw = poolBody['server_static_prekey'];
    if (prekeyRaw is Map) {
      final prekeyMap = Map<String, Object?>.from(prekeyRaw);
      final prekeyId = prekeyMap['prekey_id'];
      final prekeyPubB64 = prekeyMap['prekey_pub'];
      final validToEpoch = prekeyMap['valid_to_epoch'];
      final isExpired = isPrekeyExpired(validToEpoch, _rootEpoch);
      if (prekeyId is String && prekeyPubB64 is String && !isExpired) {
        try {
          _cachedPrekeyId = prekeyId;
          _cachedPrekeyPubRaw = primitives.fromBase64(prekeyPubB64);
        } on FormatException {
          _cachedPrekeyId = null;
          _cachedPrekeyPubRaw = null;
        }
      }
    }

    return HgfastResult.success(HgfastBootstrap(poolBody));
  }

  Future<HgfastError?> _ensurePrekey() async {
    if (_cachedPrekeyId != null && _cachedPrekeyPubRaw != null) {
      return null;
    }
    final result = await bootstrap();
    return result.failureError;
  }

  @override
  Future<HgfastResult<HgfastSession?, HgfastError>> restoreSession() async {
    try {
      final token = await _sessionStorage.read(key: _tokenStorageKey);
      final sessionId = await _sessionStorage.read(key: _sessionIdStorageKey);
      final sessionKeyB64 = await _sessionStorage.read(
        key: _sessionKeyStorageKey,
      );
      final sessionKeyId = await _sessionStorage.read(
        key: _sessionKeyIdStorageKey,
      );
      final userIdJson = await _sessionStorage.read(key: _userIdStorageKey);
      final profileJson = await _sessionStorage.read(
        key: _profileStorageKey,
      );
      if (token == null ||
          sessionId == null ||
          sessionKeyB64 == null ||
          sessionKeyId == null ||
          userIdJson == null) {
        await logout();
        return const HgfastResult.success(null);
      }
      final sessionKey = primitives.fromBase64(sessionKeyB64);
      final userId = jsonDecode(userIdJson);
      _activeSession = _HgfastActiveSession(
        token: token,
        sessionId: sessionId,
        sessionKey: sessionKey,
        sessionKeyId: sessionKeyId,
        userId: userId,
      );
      final profileValues = profileJson == null
          ? <String, Object?>{}
          : Map<String, Object?>.from(jsonDecode(profileJson) as Map);
      return HgfastResult.success(
        HgfastSession(<String, Object?>{
          ...profileValues,
          'session_id': sessionId,
        }),
      );
    } on Object catch (error) {
      return HgfastResult.failure(
        HgfastError.clientApiStateUnavailable(
          message: 'session restore failed: ${error.runtimeType}',
        ),
      );
    }
  }

  @override
  Future<HgfastResult<void, HgfastError>> logout() async {
    final previous = _activeSession;
    _activeSession = null;
    if (previous != null) {
      previous.sessionKey.fillRange(0, previous.sessionKey.length, 0);
    }
    try {
      await _sessionStorage.delete(key: _tokenStorageKey);
      await _sessionStorage.delete(key: _sessionIdStorageKey);
      await _sessionStorage.delete(key: _sessionKeyStorageKey);
      await _sessionStorage.delete(key: _sessionKeyIdStorageKey);
      await _sessionStorage.delete(key: _userIdStorageKey);
      await _sessionStorage.delete(key: _profileStorageKey);
    } on Object {
      return const HgfastResult.failure(
        HgfastError.clientApiStateUnavailable(
          message: 'session storage clear failed',
        ),
      );
    }
    return const HgfastResult.success(null);
  }

  Future<HgfastResult<void, HgfastError>> _persistSession(
    _HgfastActiveSession session,
    Map<String, Object?> profile,
  ) async {
    try {
      await _sessionStorage.write(key: _tokenStorageKey, value: session.token);
      await _sessionStorage.write(
        key: _sessionIdStorageKey,
        value: session.sessionId,
      );
      await _sessionStorage.write(
        key: _sessionKeyStorageKey,
        value: primitives.toBase64(session.sessionKey),
      );
      await _sessionStorage.write(
        key: _sessionKeyIdStorageKey,
        value: session.sessionKeyId,
      );
      await _sessionStorage.write(
        key: _userIdStorageKey,
        value: jsonEncode(session.userId),
      );
      await _sessionStorage.write(
        key: _profileStorageKey,
        value: jsonEncode(profile),
      );
    } on Object catch (error) {
      await logout();
      return HgfastResult.failure(
        HgfastError.clientApiStateUnavailable(
          message: 'session persist failed: ${error.runtimeType}',
        ),
      );
    }
    _activeSession = session;
    return const HgfastResult.success(null);
  }

  Future<bool> _resyncClock() async {
    final segment = _platformSegment;
    if (segment == null) {
      return false;
    }
    final fullPath = '/api/client/${segment.pathSegment}/v1/time';
    final nonce = _generateNonce();
    final timestamp = _currentTimestamp();
    final deviceId = (await _deviceIdentity()).deviceId;
    final headers = reqsign.buildRequestHeaders(
      method: 'GET',
      pathname: fullPath,
      body: const <int>[],
      nonce: nonce,
      timestamp: timestamp,
      deviceId: deviceId,
      token: '',
    );
    final String host;
    try {
      host = _endpointPool.currentHost();
    } on HgfastEndpointPoolConfigurationException {
      return false;
    }
    try {
      final response = await _dio.requestUri<Object?>(
        Uri.https(host, fullPath),
        options: Options(
          method: 'GET',
          headers: headers.toHeaders(),
          validateStatus: (_) => true,
          responseType: ResponseType.json,
        ),
      );
      if (response.statusCode != 200) {
        return false;
      }
      final data = response.data;
      if (data is! Map) {
        return false;
      }
      final verified = await respwrap.verifySignedResponse(
        response: Map<String, Object?>.from(data),
        rootPublicKeys: _rootPublicKeys,
        rootEpoch: _rootEpoch,
        expect: respwrap.SignedResponseExpectation(
          userId: 0,
          sessionId: 'sess-anon',
          requestHash: headers.requestHash,
          nonce: nonce,
          now: int.parse(timestamp),
          skipTime: true,
        ),
      );
      if (verified is! respwrap.SignedResponseOk) {
        return false;
      }
      final body = verified.body;
      if (body is! Map) {
        return false;
      }
      final serverTime = body['server_time'];
      if (serverTime is! int) {
        return false;
      }
      final localNow = _clockNowSeconds();
      _clockOffsetSeconds = serverTime - localNow;
      return true;
    } on Object {
      return false;
    }
  }

  String _generateNonce() => _nonceGenerator();

  String _currentTimestamp() {
    return (_clockNowSeconds() + _clockOffsetSeconds).toString();
  }

  Future<HgfastDeviceIdentity> _deviceIdentity() async {
    final cached = _deviceIdentityCache;
    if (cached != null) {
      return cached;
    }
    final identity = await _deviceIdentityStore.loadOrCreate();
    _deviceIdentityCache = identity;
    return identity;
  }

  Map<String, Object?> _asMap(Object? value) {
    if (value is Map) {
      return Map<String, Object?>.from(value);
    }
    throw const FormatException('expected a JSON object');
  }

  String? _stringOrNull(Object? data, String key) {
    if (data is! Map) {
      return null;
    }
    final value = data[key];
    return value is String ? value : null;
  }

  Future<HgfastResult<T, HgfastError>> _call<T>({
    required String method,
    required String pathname,
    required bool authed,
    required bool sealed,
    required HgfastResource resource,
    Object? jsonBody,
    required T Function(Map<String, Object?> body) parse,
    bool allowClockRetry = true,
  }) async {
    final segment = _platformSegment;
    if (segment == null) {
      return const HgfastResult.failure(
        HgfastError.clientApiStateUnavailable(
          message: 'HGFAST client_api is not available on this platform yet',
        ),
      );
    }

    _HgfastActiveSession? session;
    if (authed) {
      session = _activeSession;
      if (session == null) {
        final restored = await restoreSession();
        final restoreError = restored.failureError;
        if (restoreError != null) {
          return HgfastResult.failure(restoreError);
        }
        session = _activeSession;
      }
      if (session == null) {
        return const HgfastResult.failure(HgfastError.authFailed());
      }
    }

    final fullPath = '/api/client/${segment.pathSegment}/v1$pathname';
    final bodyJson = jsonBody == null ? null : jsonEncode(jsonBody);
    final bodyBytes = bodyJson == null ? const <int>[] : utf8.encode(bodyJson);
    final nonce = _generateNonce();
    final timestamp = _currentTimestamp();
    final deviceId = (await _deviceIdentity()).deviceId;
    final token = session?.token ?? '';
    final headers = reqsign.buildRequestHeaders(
      method: method,
      pathname: fullPath,
      body: bodyBytes,
      nonce: nonce,
      timestamp: timestamp,
      deviceId: deviceId,
      token: token,
    );
    final requestHeaders = <String, String>{...headers.toHeaders()};
    if (session != null) {
      requestHeaders['Authorization'] = 'Bearer ${session.token}';
      requestHeaders['X-HG-Session'] = session.sessionId;
    }

    final String host;
    try {
      host = _endpointPool.currentHost();
    } on HgfastEndpointPoolConfigurationException catch (error) {
      return HgfastResult.failure(
        HgfastError.clientApiStateUnavailable(message: error.toString()),
      );
    }

    final Response<Object?> response;
    try {
      response = await _dio.requestUri<Object?>(
        Uri.https(host, fullPath),
        data: bodyJson,
        options: Options(
          method: method,
          headers: requestHeaders,
          contentType: bodyJson == null ? null : Headers.jsonContentType,
          validateStatus: (_) => true,
          responseType: ResponseType.json,
        ),
      );
    } on Object catch (error) {
      _endpointPool.reportFailure();
      return HgfastResult.failure(
        HgfastError.clientApiStateUnavailable(
          message: 'network error: ${error.runtimeType}',
        ),
      );
    }

    final status = response.statusCode ?? 0;
    final data = response.data;
    if (status != 200) {
      _endpointPool.reportFailure();
      final code = _stringOrNull(data, 'code');
      final message = _stringOrNull(data, 'message');
      if (allowClockRetry && code != null && code.startsWith('C1_')) {
        final resynced = await _resyncClock();
        if (resynced) {
          return _call<T>(
            method: method,
            pathname: pathname,
            authed: authed,
            sealed: sealed,
            resource: resource,
            jsonBody: jsonBody,
            parse: parse,
            allowClockRetry: false,
          );
        }
      }
      return HgfastResult.failure(mapHgfastErrorCode(code, message, resource));
    }

    if (data is! Map) {
      return const HgfastResult.failure(
        HgfastError.clientApiStateUnavailable(
          message: 'malformed response envelope',
        ),
      );
    }

    final expectUserId = session?.userId ?? 0;
    final expectSessionId = session?.sessionId ?? 'sess-anon';
    final verified = await respwrap.verifySignedResponse(
      response: Map<String, Object?>.from(data),
      rootPublicKeys: _rootPublicKeys,
      rootEpoch: _rootEpoch,
      expect: respwrap.SignedResponseExpectation(
        userId: expectUserId,
        sessionId: expectSessionId,
        requestHash: headers.requestHash,
        nonce: nonce,
        now: int.parse(timestamp),
      ),
      sessionKey: sealed ? session?.sessionKey : null,
    );
    if (verified is respwrap.SignedResponseFailed) {
      return HgfastResult.failure(
        HgfastError.clientApiStateUnavailable(message: verified.error),
      );
    }
    final rawBody = (verified as respwrap.SignedResponseOk).body;
    final Map<String, Object?> bodyMap;
    try {
      bodyMap = _asMap(rawBody);
    } on Object catch (error) {
      return HgfastResult.failure(
        HgfastError.clientApiStateUnavailable(
          message: 'malformed body: ${error.runtimeType}',
        ),
      );
    }
    try {
      return HgfastResult.success(parse(bodyMap));
    } on _HgfastMappedError catch (mapped) {
      return HgfastResult.failure(mapped.error);
    } on Object catch (error) {
      return HgfastResult.failure(
        HgfastError.clientApiStateUnavailable(
          message: 'malformed body: ${error.runtimeType}',
        ),
      );
    }
  }

  @override
  Future<HgfastResult<HgfastConfig, HgfastError>> config() {
    return _call<HgfastConfig>(
      method: 'GET',
      pathname: '/config',
      authed: false,
      sealed: false,
      resource: HgfastResource.config,
      parse: (body) => HgfastConfig(body),
    );
  }

  @override
  Future<HgfastResult<HgfastAnnouncementCatalog, HgfastError>>
  announcements() {
    return _call<HgfastAnnouncementCatalog>(
      method: 'GET',
      pathname: '/announcement',
      authed: false,
      sealed: false,
      resource: HgfastResource.announcements,
      parse: (body) => HgfastAnnouncementCatalog(body),
    );
  }

  @override
  Future<HgfastResult<HgfastPlanCatalog, HgfastError>> plans() {
    return _call<HgfastPlanCatalog>(
      method: 'GET',
      pathname: '/plans',
      authed: false,
      sealed: false,
      resource: HgfastResource.plans,
      parse: (body) => HgfastPlanCatalog(body),
    );
  }

  @override
  Future<HgfastResult<NodeCatalog, HgfastError>> nodes() {
    return _call<NodeCatalog>(
      method: 'GET',
      pathname: '/nodes',
      authed: true,
      sealed: true,
      resource: HgfastResource.nodes,
      parse: (body) {
        final reasonError = mapHgfastAccountReason(body['reason']);
        if (reasonError != null) {
          throw _HgfastMappedError(reasonError);
        }
        return NodeCatalog.fromJson(body);
      },
    );
  }

  @override
  Future<HgfastResult<HgfastSubscription, HgfastError>> subscription() {
    return _call<HgfastSubscription>(
      method: 'GET',
      pathname: '/subscription',
      authed: true,
      sealed: true,
      resource: HgfastResource.subscription,
      parse: (body) {
        final reasonError = mapHgfastAccountReason(body['reason']);
        if (reasonError != null) {
          throw _HgfastMappedError(reasonError);
        }
        return HgfastSubscription(body);
      },
    );
  }

  @override
  Future<HgfastResult<HgfastTraffic, HgfastError>> traffic() {
    return _call<HgfastTraffic>(
      method: 'GET',
      pathname: '/traffic',
      authed: true,
      sealed: true,
      resource: HgfastResource.traffic,
      parse: (body) {
        final reasonError = mapHgfastAccountReason(body['reason']);
        if (reasonError != null) {
          throw _HgfastMappedError(reasonError);
        }
        return HgfastTraffic(body);
      },
    );
  }

  @override
  Future<HgfastResult<HgfastInvite, HgfastError>> invite() {
    return _call<HgfastInvite>(
      method: 'GET',
      pathname: '/invite',
      authed: true,
      sealed: true,
      resource: HgfastResource.invite,
      parse: (body) => HgfastInvite(body),
    );
  }

  @override
  Future<HgfastResult<HgfastLotteryStatus, HgfastError>> lotteryStatus() {
    return _call<HgfastLotteryStatus>(
      method: 'GET',
      pathname: '/lottery/status',
      authed: true,
      sealed: false,
      resource: HgfastResource.lotteryStatus,
      parse: (body) => HgfastLotteryStatus(body),
    );
  }

  @override
  Future<HgfastResult<HgfastAiResponse, HgfastError>> aiChat({
    required String message,
    String? model,
    HgfastJson? context,
  }) {
    return _call<HgfastAiResponse>(
      method: 'POST',
      pathname: '/ai/chat',
      authed: true,
      sealed: false,
      resource: HgfastResource.aiChat,
      jsonBody: <String, Object?>{
        'message': message,
        'model': ?model,
        'context': ?context,
      },
      parse: (body) => HgfastAiResponse(body),
    );
  }

  @override
  Future<HgfastResult<HgfastOrderStatus, HgfastError>> orderStatus(
    String orderId,
  ) {
    return _call<HgfastOrderStatus>(
      method: 'GET',
      pathname: '/order/$orderId/status',
      authed: false,
      sealed: false,
      resource: HgfastResource.orderStatus,
      parse: (body) => HgfastOrderStatus(body),
    );
  }

  // Real write path: POST /order — see repository.dart's doc comment on
  // this method for why this is expected to fail (403/501) against the
  // live backend today. `plan_id`/`period`/`coupon_code` are a proposed,
  // NOT backend-confirmed wire format loosely informed by
  // v2board-adapter.js's `orderCreateSpec()` — that function's actual
  // input shape is camelCase (`planId`) and its actual output shape (the
  // upstream v2board body it documents building) wants a bare numeric
  // `plan_id` and a v2board column name like `month_price` for `period`,
  // neither of which this client sends. `plan_id` here is sent as-is with
  // the `plan:` prefix `/plans` returns, and `period` as the client-facing
  // key (`month`/`quarter`/`half_year`/`year`/`onetime`, same keys as
  // `/plans`' `prices_cents`) — whatever server-side proxy eventually
  // fronts the real order/save call is what owns translating both, along
  // with setting `action` itself (deliberately NOT sent by the client: once
  // this becomes a pass-through proxy, a client-controlled `action` could
  // select purchase vs. renewal vs. reset on the real endpoint).
  @override
  Future<HgfastResult<HgfastOrderStatus, HgfastError>> createOrder({
    required String planId,
    required String period,
    String? couponCode,
  }) {
    return _call<HgfastOrderStatus>(
      method: 'POST',
      pathname: '/order',
      authed: true,
      sealed: false,
      resource: HgfastResource.createOrder,
      jsonBody: <String, Object?>{
        'plan_id': planId,
        'period': period,
        'coupon_code': ?couponCode,
      },
      parse: (body) => HgfastOrderStatus(body),
    );
  }

  // Real write path: POST /auth/reset/request. Unauthenticated by design —
  // the whole point of password reset is recovering an account the caller
  // cannot currently log into. `sealed: false` for the same reason
  // createOrder() is unsealed today (an email address is not as sensitive
  // as a password; this can be revisited alongside createOrder's `sealed`
  // question once the write path actually opens). Currently gated
  // (403/501) server-side — see repository.dart's doc comment.
  @override
  Future<HgfastResult<HgfastJson, HgfastError>> requestPasswordReset({
    required String email,
  }) {
    return _call<HgfastJson>(
      method: 'POST',
      pathname: '/auth/reset/request',
      authed: false,
      sealed: false,
      resource: HgfastResource.requestPasswordReset,
      jsonBody: <String, Object?>{'email': email},
      parse: (body) => body,
    );
  }

  // Real write path: POST /auth/reset/confirm. Unauthenticated, same reason
  // as requestPasswordReset(). Unlike that method this carries a real new
  // password, so the whole {email, code, new_password} object is sealed
  // against the bootstrap prekey with hpkeSealBase — the same primitive and
  // the same "seal the whole credential object" shape login's
  // sealed_credentials uses for {credential, password} — instead of riding
  // along as plaintext JSON. Two earlier versions of this method fell short
  // of that: the first left new_password entirely in plaintext (flagged as a
  // P1 by an Opus review: "the body is genuinely on the wire on every tap
  // regardless of what the server does with it, and nothing here should fail
  // open the moment the gate is lifted"); the fix for that sealed only
  // new_password and bound the still-plaintext email into the AAD instead, on
  // the theory that email+code+password isn't attacker-useful without the
  // password. A follow-up Opus review pointed out that theory doesn't hold —
  // email+code+chosen-password is a full account takeover on its own, so the
  // same "nothing should fail open" argument applies to code just as much as
  // to new_password — and separately caught a real bug in the AAD-binding
  // approach: jcs.jcsBytes (unlike jsonEncode) throws HgfastJcsException on
  // control characters or lone surrogates in the AAD, so a stray control
  // character pasted into the email field left the "获取验证码"/"重置密码"
  // button permanently stuck spinning (an uncaught async rethrow). Sealing
  // the whole object — like login always did — closes both: nothing sensitive
  // stays in plaintext, and email now goes through jsonEncode (which escapes
  // rather than rejects control characters) instead of jcs.jcsBytes. See
  // _confirmPasswordReset below.
  @override
  Future<HgfastResult<HgfastJson, HgfastError>> confirmPasswordReset({
    required String email,
    required String code,
    required String newPassword,
  }) {
    return _confirmPasswordReset(
      email: email,
      code: code,
      newPassword: newPassword,
      allowClockRetry: true,
      allowPrekeyRetry: true,
    );
  }

  Future<HgfastResult<HgfastJson, HgfastError>> _confirmPasswordReset({
    required String email,
    required String code,
    required String newPassword,
    required bool allowClockRetry,
    required bool allowPrekeyRetry,
  }) async {
    final segment = _platformSegment;
    if (segment == null) {
      return const HgfastResult.failure(
        HgfastError.clientApiStateUnavailable(
          message: 'HGFAST client_api is not available on this platform yet',
        ),
      );
    }
    final prekeyError = await _ensurePrekey();
    if (prekeyError != null) {
      return HgfastResult.failure(prekeyError);
    }
    final prekeyId = _cachedPrekeyId;
    final prekeyPubRaw = _cachedPrekeyPubRaw;
    if (prekeyId == null || prekeyPubRaw == null) {
      return const HgfastResult.failure(
        HgfastError.clientApiStateUnavailable(
          message: 'bootstrap prekey unavailable',
        ),
      );
    }

    final fullPath =
        '/api/client/${segment.pathSegment}/v1/auth/reset/confirm';
    final nonce = _generateNonce();
    final timestamp = _currentTimestamp();
    final deviceId = (await _deviceIdentity()).deviceId;

    // No separate client_eph_pub field is needed here the way login sends
    // one: hpkeSealBase embeds its own single-use sender ephemeral pubkey
    // (`enc`) as the first 32 bytes of the sealed blob it returns, and this
    // call — unlike login — doesn't go on to derive a follow-on E2EE session
    // key that would need a second, separately-agreed ephemeral key. The AAD
    // (like login's) contains only values the server can already reconstruct
    // byte-exactly from the request itself (URL, headers, prekey_id) —
    // nothing user-controlled — so there's no risk of a future server-side
    // normalization (e.g. lowercasing email) breaking seal verification the
    // way binding a raw user string into the AAD would.
    final sealAad = jcs.jcsBytes(<String, Object?>{
      'api_path': fullPath,
      'device': deviceId,
      'nonce': nonce,
      'platform': segment.pathSegment,
      'prekey_id': prekeyId,
      'ts': timestamp,
    });
    // email/code/new_password travel together inside the seal, exactly the
    // way login seals {credential, password} together — not just
    // new_password alone — since email+code+an-attacker-chosen-password is
    // already a complete account takeover on its own.
    final resetPlaintext = utf8.encode(
      jsonEncode(<String, Object?>{
        'email': email,
        'code': code,
        'new_password': newPassword,
      }),
    );
    final Uint8List sealedReset;
    try {
      sealedReset = await hpke.hpkeSealBase(
        recipientPublicKeyRaw: prekeyPubRaw,
        info: utf8.encode('HGFAST-REQ-SEAL-$fullPath-v1'),
        aad: sealAad,
        plaintext: resetPlaintext,
        ephemeralSeed: _hpkeSealEphemeralSeed(),
      );
    } on Object catch (error) {
      return HgfastResult.failure(
        HgfastError.clientApiStateUnavailable(
          message: 'reset payload seal failed: ${error.runtimeType}',
        ),
      );
    }

    final requestBody = <String, Object?>{
      'prekey_id': prekeyId,
      'sealed_reset': primitives.toBase64(sealedReset),
    };
    final bodyJson = jsonEncode(requestBody);
    final bodyBytes = utf8.encode(bodyJson);
    final headers = reqsign.buildRequestHeaders(
      method: 'POST',
      pathname: fullPath,
      body: bodyBytes,
      nonce: nonce,
      timestamp: timestamp,
      deviceId: deviceId,
      token: '',
    );

    final String host;
    try {
      host = _endpointPool.currentHost();
    } on HgfastEndpointPoolConfigurationException catch (error) {
      return HgfastResult.failure(
        HgfastError.clientApiStateUnavailable(message: error.toString()),
      );
    }

    final Response<Object?> response;
    try {
      response = await _dio.requestUri<Object?>(
        Uri.https(host, fullPath),
        data: bodyJson,
        options: Options(
          method: 'POST',
          headers: headers.toHeaders(),
          contentType: Headers.jsonContentType,
          validateStatus: (_) => true,
          responseType: ResponseType.json,
        ),
      );
    } on Object catch (error) {
      _endpointPool.reportFailure();
      return HgfastResult.failure(
        HgfastError.clientApiStateUnavailable(
          message: 'network error: ${error.runtimeType}',
        ),
      );
    }

    final status = response.statusCode ?? 0;
    final data = response.data;
    if (status != 200) {
      _endpointPool.reportFailure();
      final respCode = _stringOrNull(data, 'code');
      final respMessage = _stringOrNull(data, 'message');
      if (allowClockRetry && respCode != null && respCode.startsWith('C1_')) {
        final resynced = await _resyncClock();
        if (resynced) {
          return _confirmPasswordReset(
            email: email,
            code: code,
            newPassword: newPassword,
            allowClockRetry: false,
            allowPrekeyRetry: allowPrekeyRetry,
          );
        }
      }
      if (allowPrekeyRetry && respCode == 'SEAL_OPEN_FAIL') {
        _cachedPrekeyId = null;
        _cachedPrekeyPubRaw = null;
        return _confirmPasswordReset(
          email: email,
          code: code,
          newPassword: newPassword,
          allowClockRetry: allowClockRetry,
          allowPrekeyRetry: false,
        );
      }
      return HgfastResult.failure(
        mapHgfastErrorCode(
          respCode,
          respMessage,
          HgfastResource.confirmPasswordReset,
        ),
      );
    }
    if (data is! Map) {
      return const HgfastResult.failure(
        HgfastError.clientApiStateUnavailable(
          message: 'malformed response envelope',
        ),
      );
    }

    final verified = await respwrap.verifySignedResponse(
      response: Map<String, Object?>.from(data),
      rootPublicKeys: _rootPublicKeys,
      rootEpoch: _rootEpoch,
      expect: respwrap.SignedResponseExpectation(
        userId: 0,
        sessionId: 'sess-anon',
        requestHash: headers.requestHash,
        nonce: nonce,
        now: int.parse(timestamp),
      ),
    );
    if (verified is respwrap.SignedResponseFailed) {
      return HgfastResult.failure(
        HgfastError.clientApiStateUnavailable(message: verified.error),
      );
    }
    final rawBody = (verified as respwrap.SignedResponseOk).body;
    final Map<String, Object?> bodyMap;
    try {
      bodyMap = _asMap(rawBody);
    } on Object catch (error) {
      return HgfastResult.failure(
        HgfastError.clientApiStateUnavailable(
          message: 'malformed body: ${error.runtimeType}',
        ),
      );
    }
    return HgfastResult.success(bodyMap);
  }
}
