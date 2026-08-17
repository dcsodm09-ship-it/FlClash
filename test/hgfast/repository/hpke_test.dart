import 'dart:convert';
import 'dart:typed_data';

import 'package:fl_clash/hgfast/repository/hpke.dart';
import 'package:fl_clash/hgfast/transport/primitives.dart' as primitives;
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('hpkeSealBase then hpkeOpenBase round-trips arbitrary plaintext', () async {
    final recipientKeyPair = await primitives.x25519NewKeyPair();
    final recipientPublicKey = await recipientKeyPair.extractPublicKey();
    final recipientPublicKeyRaw = Uint8List.fromList(recipientPublicKey.bytes);
    final info = utf8.encode('HGFAST-TEST-INFO-v1');
    final aad = utf8.encode(jsonEncode(<String, Object?>{'k': 'v'}));
    final plaintext = utf8.encode('round trip payload');

    final sealed = await hpkeSealBase(
      recipientPublicKeyRaw: recipientPublicKeyRaw,
      info: info,
      aad: aad,
      plaintext: plaintext,
    );

    final opened = await hpkeOpenBase(
      recipientKeyPair: recipientKeyPair,
      recipientPublicKeyRaw: recipientPublicKeyRaw,
      sealed: sealed,
      info: info,
      aad: aad,
    );

    expect(opened, plaintext);
  });

  test('hpkeOpenBase rejects a tampered ciphertext', () async {
    final recipientKeyPair = await primitives.x25519NewKeyPair();
    final recipientPublicKey = await recipientKeyPair.extractPublicKey();
    final recipientPublicKeyRaw = Uint8List.fromList(recipientPublicKey.bytes);
    final info = utf8.encode('HGFAST-TEST-INFO-v1');
    final aad = utf8.encode('aad');
    final plaintext = utf8.encode('secret');

    final sealed = await hpkeSealBase(
      recipientPublicKeyRaw: recipientPublicKeyRaw,
      info: info,
      aad: aad,
      plaintext: plaintext,
    );
    final tampered = Uint8List.fromList(sealed);
    tampered[tampered.length - 1] ^= 0x01;

    expect(
      () => hpkeOpenBase(
        recipientKeyPair: recipientKeyPair,
        recipientPublicKeyRaw: recipientPublicKeyRaw,
        sealed: tampered,
        info: info,
        aad: aad,
      ),
      throwsA(isA<HgfastHpkeException>()),
    );
  });

  test('hpkeOpenBase rejects a mismatched aad', () async {
    final recipientKeyPair = await primitives.x25519NewKeyPair();
    final recipientPublicKey = await recipientKeyPair.extractPublicKey();
    final recipientPublicKeyRaw = Uint8List.fromList(recipientPublicKey.bytes);
    final info = utf8.encode('HGFAST-TEST-INFO-v1');
    final plaintext = utf8.encode('secret');

    final sealed = await hpkeSealBase(
      recipientPublicKeyRaw: recipientPublicKeyRaw,
      info: info,
      aad: utf8.encode('aad-a'),
      plaintext: plaintext,
    );

    expect(
      () => hpkeOpenBase(
        recipientKeyPair: recipientKeyPair,
        recipientPublicKeyRaw: recipientPublicKeyRaw,
        sealed: sealed,
        info: info,
        aad: utf8.encode('aad-b'),
      ),
      throwsA(isA<HgfastHpkeException>()),
    );
  });

  test(
    'hpkeOpenBase decrypts a vector produced by the real backend hpke.js',
    () async {
      final recipientSeed = primitives.fromHex(
        '1111111111111111111111111111111111111111111111111111111111111111',
      );
      final recipientKeyPair = await primitives.x25519KeyPairFromSeed(
        recipientSeed,
      );
      final info = utf8.encode('HGFAST-TEST-VECTOR-v1');
      final aad = primitives.fromBase64('eyJhIjoxLCJiIjoidHdvIn0=');
      final sealed = primitives.fromBase64(
        'D6poTtKIZ7l/Smot7l34zpdOdrcBjj8iocTPJnhXDyDYNx2pyRL7c7VxLRwYlobtR1qX'
        'vT9niCq4DtYjq0OtjIIXlShk57sf',
      );
      final recipientPublicKey = await recipientKeyPair.extractPublicKey();
      final recipientPublicKeyRaw = Uint8List.fromList(
        recipientPublicKey.bytes,
      );

      final opened = await hpkeOpenBase(
        recipientKeyPair: recipientKeyPair,
        recipientPublicKeyRaw: recipientPublicKeyRaw,
        sealed: sealed,
        info: info,
        aad: aad,
      );

      expect(utf8.decode(opened), 'hello hpke golden vector');
    },
  );
}
