import 'dart:convert';
import 'dart:typed_data';

import 'package:fl_clash/hgfast/repository/hpke.dart';
import 'package:fl_clash/hgfast/transport/primitives.dart' as primitives;
import 'package:flutter_test/flutter_test.dart';

void main() {
  test(
    'hpkeSealBase without an ephemeralSeed still picks a fresh random KEM '
    'ephemeral key on every call',
    () async {
      final recipientKeyPair = await primitives.x25519NewKeyPair();
      final recipientPublicKey = await recipientKeyPair.extractPublicKey();
      final recipientPublicKeyRaw = Uint8List.fromList(
        recipientPublicKey.bytes,
      );
      final info = utf8.encode('HGFAST-TEST-INFO-v1');
      final aad = utf8.encode('aad');
      final plaintext = utf8.encode('same plaintext both times');

      final sealedFirst = await hpkeSealBase(
        recipientPublicKeyRaw: recipientPublicKeyRaw,
        info: info,
        aad: aad,
        plaintext: plaintext,
      );
      final sealedSecond = await hpkeSealBase(
        recipientPublicKeyRaw: recipientPublicKeyRaw,
        info: info,
        aad: aad,
        plaintext: plaintext,
      );

      expect(
        sealedFirst.sublist(0, hpkeEncLength),
        isNot(sealedSecond.sublist(0, hpkeEncLength)),
      );
    },
  );

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

  test(
    'hpkeSealBase with a deterministic ephemeral seed produces the exact '
    'bytes the real backend hpke.js produces for the same inputs',
    () async {
      final recipientSeed = primitives.fromHex(
        '6666666666666666666666666666666666666666666666666666666666666666',
      );
      final ephemeralSeed = primitives.fromHex(
        '7777777777777777777777777777777777777777777777777777777777777777',
      );
      final recipientKeyPair = await primitives.x25519KeyPairFromSeed(
        recipientSeed,
      );
      final recipientPublicKey = await recipientKeyPair.extractPublicKey();
      final recipientPublicKeyRaw = Uint8List.fromList(
        recipientPublicKey.bytes,
      );
      final info = utf8.encode('HGFAST-SEAL-VECTOR-v1');
      final aad = primitives.fromBase64('eyJ4Ijoic2VhbC1hYWQifQ==');
      final plaintext = utf8.encode('deterministic seal golden vector');
      const expectedSealedB64 =
          'HPV5q6RaELodHvBtkfyiqp7QoRUFFWUxVUBdCxjLmmcRdVPP7CnirKMySFqD2nHKnlm7'
          'kP7FAGb+Hxl8GfYNAtGO9FR+kmCKN9gTuf3Igt4=';

      final sealed = await hpkeSealBase(
        recipientPublicKeyRaw: recipientPublicKeyRaw,
        info: info,
        aad: aad,
        plaintext: plaintext,
        ephemeralSeed: ephemeralSeed,
      );

      expect(primitives.toBase64(sealed), expectedSealedB64);

      final opened = await hpkeOpenBase(
        recipientKeyPair: recipientKeyPair,
        recipientPublicKeyRaw: recipientPublicKeyRaw,
        sealed: sealed,
        info: info,
        aad: aad,
      );
      expect(utf8.decode(opened), 'deterministic seal golden vector');
    },
  );
}
