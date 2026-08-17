import 'dart:convert';
import 'dart:typed_data';

import 'package:cryptography/cryptography.dart' as cg;

import '../transport/primitives.dart' as primitives;

const int hpkeKemId = 0x0020;
const int hpkeKdfId = 0x0001;
const int hpkeAeadId = 0x0003;
const int hpkeNSecret = 32;
const int hpkeNK = 32;
const int hpkeNN = 12;
const int hpkeEncLength = 32;

Uint8List _i2osp(int value, int length) {
  final bytes = Uint8List(length);
  var remaining = value;
  for (var i = length - 1; i >= 0; i--) {
    bytes[i] = remaining & 0xff;
    remaining >>= 8;
  }
  return bytes;
}

final Uint8List _kemSuite = Uint8List.fromList(<int>[
  ...utf8.encode('KEM'),
  ..._i2osp(hpkeKemId, 2),
]);

final Uint8List _hpkeSuite = Uint8List.fromList(<int>[
  ...utf8.encode('HPKE'),
  ..._i2osp(hpkeKemId, 2),
  ..._i2osp(hpkeKdfId, 2),
  ..._i2osp(hpkeAeadId, 2),
]);

final Uint8List _hpkeV1 = Uint8List.fromList(utf8.encode('HPKE-v1'));

Uint8List _hkdfExtract(List<int> salt, List<int> ikm) {
  return primitives.hmacSha256(salt, ikm);
}

Uint8List _hkdfExpand(List<int> prk, List<int> info, int length) {
  final output = BytesBuilder();
  var previousBlock = const <int>[];
  var blockIndex = 1;
  while (output.length < length) {
    final input = <int>[...previousBlock, ...info, blockIndex];
    final block = primitives.hmacSha256(prk, input);
    output.add(block);
    previousBlock = block;
    blockIndex++;
  }
  return Uint8List.fromList(output.toBytes().sublist(0, length));
}

Uint8List _labeledExtract(
  List<int> salt,
  String label,
  List<int> ikm,
  List<int> suiteId,
) {
  final labeledIkm = <int>[
    ..._hpkeV1,
    ...suiteId,
    ...utf8.encode(label),
    ...ikm,
  ];
  return _hkdfExtract(salt, labeledIkm);
}

Uint8List _labeledExpand(
  List<int> prk,
  String label,
  List<int> info,
  int length,
  List<int> suiteId,
) {
  final labeledInfo = <int>[
    ..._i2osp(length, 2),
    ..._hpkeV1,
    ...suiteId,
    ...utf8.encode(label),
    ...info,
  ];
  return _hkdfExpand(prk, labeledInfo, length);
}

Uint8List _extractAndExpand(List<int> dh, List<int> kemContext) {
  final eaePrk = _labeledExtract(const [], 'eae_prk', dh, _kemSuite);
  return _labeledExpand(
    eaePrk,
    'shared_secret',
    kemContext,
    hpkeNSecret,
    _kemSuite,
  );
}

final class HpkeKeySchedule {
  const HpkeKeySchedule(this.key, this.baseNonce);

  final Uint8List key;
  final Uint8List baseNonce;
}

HpkeKeySchedule _keyScheduleBase(List<int> sharedSecret, List<int> info) {
  const mode = <int>[0x00];
  final pskIdHash = _labeledExtract(const [], 'psk_id_hash', const [], _hpkeSuite);
  final infoHash = _labeledExtract(const [], 'info_hash', info, _hpkeSuite);
  final ksContext = <int>[...mode, ...pskIdHash, ...infoHash];
  final secret = _labeledExtract(sharedSecret, 'secret', const [], _hpkeSuite);
  final key = _labeledExpand(secret, 'key', ksContext, hpkeNK, _hpkeSuite);
  final baseNonce = _labeledExpand(
    secret,
    'base_nonce',
    ksContext,
    hpkeNN,
    _hpkeSuite,
  );
  return HpkeKeySchedule(key, baseNonce);
}

Future<Uint8List> _chacha20Poly1305Seal({
  required List<int> key32,
  required List<int> nonce12,
  required List<int> aad,
  required List<int> plaintext,
}) async {
  final secretBox = await primitives.chacha20Poly1305Algorithm.encrypt(
    plaintext,
    secretKey: cg.SecretKey(key32),
    nonce: nonce12,
    aad: aad,
  );
  return Uint8List.fromList(<int>[
    ...secretBox.cipherText,
    ...secretBox.mac.bytes,
  ]);
}

final class HgfastHpkeException implements Exception {
  const HgfastHpkeException(this.message);

  final String message;

  @override
  String toString() => 'HgfastHpkeException: $message';
}

Future<Uint8List> hpkeSealBase({
  required List<int> recipientPublicKeyRaw,
  required List<int> info,
  required List<int> aad,
  required List<int> plaintext,
  List<int>? ephemeralSeed,
}) async {
  final ephemeralKeyPair = ephemeralSeed == null
      ? await primitives.x25519NewKeyPair()
      : await primitives.x25519KeyPairFromSeed(ephemeralSeed);
  final dh = await primitives.x25519SharedSecret(
    keyPair: ephemeralKeyPair,
    remotePublicKeyRaw: recipientPublicKeyRaw,
  );
  final ephemeralPublicKey = await ephemeralKeyPair.extractPublicKey();
  final enc = Uint8List.fromList(ephemeralPublicKey.bytes);
  final kemContext = <int>[...enc, ...recipientPublicKeyRaw];
  final sharedSecret = _extractAndExpand(dh, kemContext);
  final schedule = _keyScheduleBase(sharedSecret, info);
  final cipherText = await _chacha20Poly1305Seal(
    key32: schedule.key,
    nonce12: schedule.baseNonce,
    aad: aad,
    plaintext: plaintext,
  );
  return Uint8List.fromList(<int>[...enc, ...cipherText]);
}

Future<Uint8List> hpkeOpenBase({
  required cg.SimpleKeyPair recipientKeyPair,
  required List<int> recipientPublicKeyRaw,
  required List<int> sealed,
  required List<int> info,
  required List<int> aad,
}) async {
  if (sealed.length < hpkeEncLength) {
    throw const HgfastHpkeException('sealed payload shorter than enc length');
  }
  final enc = sealed.sublist(0, hpkeEncLength);
  final cipherText = sealed.sublist(hpkeEncLength);
  final dh = await primitives.x25519SharedSecret(
    keyPair: recipientKeyPair,
    remotePublicKeyRaw: enc,
  );
  final kemContext = <int>[...enc, ...recipientPublicKeyRaw];
  final sharedSecret = _extractAndExpand(dh, kemContext);
  final schedule = _keyScheduleBase(sharedSecret, info);
  try {
    return await primitives.chacha20Poly1305Open(
      key32: schedule.key,
      nonce12: schedule.baseNonce,
      aad: aad,
      cipherTextAndTag: cipherText,
    );
  } on Object catch (error) {
    throw HgfastHpkeException('open failed: $error');
  }
}
