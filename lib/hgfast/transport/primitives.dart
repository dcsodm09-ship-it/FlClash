import 'dart:convert';
import 'dart:typed_data';

import 'package:crypto/crypto.dart' as crypto;
import 'package:cryptography/cryptography.dart' as cg;

Uint8List sha256(List<int> data) {
  return Uint8List.fromList(crypto.sha256.convert(data).bytes);
}

Uint8List hmacSha256(List<int> key, List<int> message) {
  return Uint8List.fromList(
    crypto.Hmac(crypto.sha256, key).convert(message).bytes,
  );
}

String toHex(List<int> bytes) {
  final buffer = StringBuffer();
  for (final byte in bytes) {
    buffer.write(byte.toRadixString(16).padLeft(2, '0'));
  }
  return buffer.toString();
}

Uint8List fromHex(String value) {
  if (value.length.isOdd) {
    throw const FormatException('Odd-length hex string');
  }
  final result = Uint8List(value.length ~/ 2);
  for (var i = 0; i < result.length; i++) {
    result[i] = int.parse(value.substring(i * 2, i * 2 + 2), radix: 16);
  }
  return result;
}

String toBase64(List<int> bytes) => base64Encode(bytes);

Uint8List fromBase64(String value) => base64Decode(value);

bool timingSafeEqualBytes(List<int> a, List<int> b) {
  if (a.length != b.length) {
    return false;
  }
  var diff = 0;
  for (var i = 0; i < a.length; i++) {
    diff |= a[i] ^ b[i];
  }
  return diff == 0;
}

final cg.Ed25519 ed25519Algorithm = cg.Ed25519();
final cg.X25519 x25519Algorithm = cg.X25519();
final cg.Chacha20 chacha20Poly1305Algorithm = cg.Chacha20.poly1305Aead();

cg.SimplePublicKey importEd25519PublicKey(List<int> raw32) {
  return cg.SimplePublicKey(raw32, type: cg.KeyPairType.ed25519);
}

cg.SimplePublicKey importX25519PublicKey(List<int> raw32) {
  return cg.SimplePublicKey(raw32, type: cg.KeyPairType.x25519);
}

Future<bool> ed25519Verify(
  List<int> publicKeyRaw,
  List<int> message,
  List<int> signatureBytes,
) async {
  final signature = cg.Signature(
    signatureBytes,
    publicKey: importEd25519PublicKey(publicKeyRaw),
  );
  try {
    return await ed25519Algorithm.verify(message, signature: signature);
  } on Object {
    return false;
  }
}

Future<cg.SimpleKeyPair> x25519KeyPairFromSeed(List<int> seed32) {
  return x25519Algorithm.newKeyPairFromSeed(seed32);
}

Future<cg.SimpleKeyPair> x25519NewKeyPair() {
  return x25519Algorithm.newKeyPair();
}

Future<Uint8List> x25519SharedSecret({
  required cg.SimpleKeyPair keyPair,
  required List<int> remotePublicKeyRaw,
}) async {
  final shared = await x25519Algorithm.sharedSecretKey(
    keyPair: keyPair,
    remotePublicKey: importX25519PublicKey(remotePublicKeyRaw),
  );
  return Uint8List.fromList(await shared.extractBytes());
}

Future<Uint8List> hkdfSha256({
  required List<int> inputKeyMaterial,
  required List<int> salt,
  required List<int> info,
  required int length,
}) async {
  final hkdf = cg.Hkdf(hmac: cg.Hmac.sha256(), outputLength: length);
  final derived = await hkdf.deriveKey(
    secretKey: cg.SecretKey(inputKeyMaterial),
    nonce: salt,
    info: info,
  );
  return Uint8List.fromList(await derived.extractBytes());
}

Future<Uint8List> chacha20Poly1305Open({
  required List<int> key32,
  required List<int> nonce12,
  required List<int> aad,
  required List<int> cipherTextAndTag,
}) async {
  if (cipherTextAndTag.length < 16) {
    throw const FormatException('ChaCha20-Poly1305 payload too short');
  }
  final cipherText = cipherTextAndTag.sublist(
    0,
    cipherTextAndTag.length - 16,
  );
  final tag = cipherTextAndTag.sublist(cipherTextAndTag.length - 16);
  final secretBox = cg.SecretBox(cipherText, nonce: nonce12, mac: cg.Mac(tag));
  final clear = await chacha20Poly1305Algorithm.decrypt(
    secretBox,
    secretKey: cg.SecretKey(key32),
    aad: aad,
  );
  return Uint8List.fromList(clear);
}
