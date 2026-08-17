import 'dart:convert';
import 'dart:typed_data';

import 'package:cryptography/cryptography.dart' as cg;

import 'jcs.dart' as jcs;
import 'primitives.dart' as primitives;

final Uint8List sessionInfo = Uint8List.fromList(
  utf8.encode('HGFAST-E2EE-SESSION-v1'),
);

Future<Uint8List> deriveSessionKeyClient({
  required cg.SimpleKeyPair clientEphemeralKeyPair,
  required List<int> serverEphemeralPublicKeyRaw,
  required List<int> salt,
}) async {
  final shared = await primitives.x25519SharedSecret(
    keyPair: clientEphemeralKeyPair,
    remotePublicKeyRaw: serverEphemeralPublicKeyRaw,
  );
  return primitives.hkdfSha256(
    inputKeyMaterial: shared,
    salt: salt,
    info: sessionInfo,
    length: 32,
  );
}

final class HgfastE2eeOpenException implements Exception {
  const HgfastE2eeOpenException(this.message);

  final String message;

  @override
  String toString() => 'HgfastE2eeOpenException: $message';
}

List<int> _decodeBase64BlobField(Map<String, Object?> blob, String key) {
  final value = blob[key];
  if (value is! String) {
    throw HgfastE2eeOpenException('E2EE blob field $key is missing or not a string');
  }
  try {
    return primitives.fromBase64(value);
  } on FormatException {
    throw HgfastE2eeOpenException('E2EE blob field $key is not valid base64');
  }
}

// expectedAad is required, not optional: the AAD bytes transmitted inside
// the blob are what the AEAD actually authenticates against, so the
// timingSafeEqualBytes comparison below *is* the entire context-binding
// property (matches the backend's own e2ee.js). A caller that could omit
// it would silently accept attacker-chosen context with no error.
Future<Object?> openResponse({
  required List<int> sessionKey,
  required Map<String, Object?> blob,
  required Map<String, Object?> expectedAad,
}) async {
  final aad = _decodeBase64BlobField(blob, 'aad');
  final want = jcs.jcsBytes(expectedAad);
  if (!primitives.timingSafeEqualBytes(want, aad)) {
    throw const HgfastE2eeOpenException('E2EE AAD context mismatch');
  }
  final nonce = _decodeBase64BlobField(blob, 'aead_nonce');
  final cipherText = _decodeBase64BlobField(blob, 'ciphertext');
  final Uint8List plaintext;
  try {
    plaintext = await primitives.chacha20Poly1305Open(
      key32: sessionKey,
      nonce12: nonce,
      aad: aad,
      cipherTextAndTag: cipherText,
    );
  } on FormatException catch (error) {
    throw HgfastE2eeOpenException('E2EE ciphertext malformed: $error');
  }
  return jsonDecode(utf8.decode(plaintext));
}
