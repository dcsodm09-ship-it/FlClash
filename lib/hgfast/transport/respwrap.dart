import 'dart:convert';

import 'e2ee.dart' as e2ee;
import 'primitives.dart' as primitives;
import 'signing.dart' as signing;

final class SignedResponseExpectation {
  const SignedResponseExpectation({
    required this.userId,
    required this.sessionId,
    required this.requestHash,
    required this.nonce,
    required this.now,
    this.skipTime = false,
  });

  final Object? userId;
  final String sessionId;
  final String requestHash;
  final String nonce;
  final int now;
  final bool skipTime;
}

sealed class SignedResponseResult {
  const SignedResponseResult();
}

final class SignedResponseOk extends SignedResponseResult {
  const SignedResponseOk(this.body, {required this.isSealed});

  final Object? body;
  final bool isSealed;
}

final class SignedResponseFailed extends SignedResponseResult {
  const SignedResponseFailed(this.error);

  final String error;
}

Map<String, Object?> _asStringKeyedMap(Object? value, String field) {
  if (value is! Map) {
    throw FormatException('Invalid signed response field: $field');
  }
  return Map<String, Object?>.from(value);
}

// A pool host, a MITM on a skip-cert-verify node, or a plain server bug can
// hand this an arbitrarily-shaped body. Every field access below is
// guarded, and the whole function is wrapped in a catch-all, so the worst
// a malformed response can do is a SignedResponseFailed('MalformedResponse')
// — never an uncaught TypeError/FormatException a caller isn't written to
// expect (see day0_contract_test.dart's own FormatException-vs-TypeError
// convention for why that distinction matters here).
Future<SignedResponseResult> verifySignedResponse({
  required Map<String, Object?> response,
  required List<List<int>> rootPublicKeys,
  required int rootEpoch,
  required SignedResponseExpectation expect,
  List<int>? sessionKey,
}) async {
  final Map<String, Object?> envelope;
  final String bodyJcs;
  final String sig;
  final Map<String, Object?> cert;
  try {
    envelope = _asStringKeyedMap(response['envelope'], 'envelope');
    cert = _asStringKeyedMap(response['cert'], 'cert');
    final bodyJcsField = response['body_jcs'];
    final sigField = response['sig'];
    if (bodyJcsField is! String || sigField is! String) {
      return const SignedResponseFailed('MalformedResponse');
    }
    bodyJcs = bodyJcsField;
    sig = sigField;
  } on Object {
    return const SignedResponseFailed('MalformedResponse');
  }

  if (envelope['user_id'] != expect.userId) {
    return const SignedResponseFailed('UserMismatch');
  }
  if (envelope['session_id'] != expect.sessionId) {
    return const SignedResponseFailed('SessionMismatch');
  }
  if (envelope['request_hash'] != expect.requestHash) {
    return const SignedResponseFailed('RequestMismatch');
  }
  if (envelope['nonce'] != expect.nonce) {
    return const SignedResponseFailed('NonceMismatch');
  }

  if (!expect.skipTime) {
    final issuedAt = envelope['issued_at'];
    final expiresAt = envelope['expires_at'];
    if (issuedAt is! int || expiresAt is! int) {
      return const SignedResponseFailed('MalformedResponse');
    }
    if (expect.now < issuedAt) {
      return const SignedResponseFailed('NotYetValid');
    }
    if (expect.now > expiresAt) {
      return const SignedResponseFailed('Expired');
    }
  }

  final bodyHash = primitives.toHex(
    primitives.sha256(utf8.encode(bodyJcs)),
  );
  if (bodyHash != envelope['body_hash']) {
    return const SignedResponseFailed('BodyHashMismatch');
  }

  final envelopeResult = await signing.verifyEnvelope(
    envelope: envelope,
    signatureBase64: sig,
    cert: cert,
    rootPublicKeys: rootPublicKeys,
    rootEpoch: rootEpoch,
  );
  if (!envelopeResult.isOk) {
    return SignedResponseFailed(envelopeResult.error!);
  }

  final Object? parsed;
  try {
    parsed = jsonDecode(bodyJcs);
  } on FormatException {
    return const SignedResponseFailed('MalformedResponse');
  }
  if (parsed is Map &&
      parsed['ciphertext'] != null &&
      parsed['session_key_id'] != null) {
    if (sessionKey == null) {
      return const SignedResponseFailed('E2EEKeyMissing');
    }
    final sealedBlob = Map<String, Object?>.from(parsed);
    final expectedAad = <String, Object?>{
      'app_id': envelope['app_id'],
      'channel': envelope['channel'],
      'expires_at': envelope['expires_at'],
      'issued_at': envelope['issued_at'],
      'nonce': envelope['nonce'],
      'purpose': envelope['purpose'],
      'request_hash': envelope['request_hash'],
      'session_id': envelope['session_id'],
      'session_key_id': sealedBlob['session_key_id'],
      'user_id': envelope['user_id'],
    };
    try {
      final body = await e2ee.openResponse(
        sessionKey: sessionKey,
        blob: sealedBlob,
        expectedAad: expectedAad,
      );
      return SignedResponseOk(body, isSealed: true);
    } on e2ee.HgfastE2eeOpenException catch (error) {
      return SignedResponseFailed('E2EEOpenFail:${error.message}');
    } on Object catch (error) {
      return SignedResponseFailed('E2EEOpenFail:$error');
    }
  }
  return SignedResponseOk(parsed, isSealed: false);
}
