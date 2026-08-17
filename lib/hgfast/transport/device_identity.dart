import 'dart:math';
import 'dart:typed_data';

import 'package:cryptography/cryptography.dart' as cg;
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import 'primitives.dart' as primitives;

const String deviceSeedStorageKey = 'hgfast_device_ed25519_seed_v1';

// aOptions is left at AndroidOptions.defaultOptions: this package version
// deprecated `encryptedSharedPreferences` (silently ignored, migrating
// automatically to its own cipher on first access), so there is nothing
// left to configure there.
const FlutterSecureStorage defaultHgfastSecureStorage = FlutterSecureStorage(
  iOptions: IOSOptions(
    accessibility: KeychainAccessibility.first_unlock_this_device,
  ),
  mOptions: MacOsOptions(
    accessibility: KeychainAccessibility.first_unlock_this_device,
  ),
);

String deriveDeviceId(List<int> publicKeyRaw) {
  final digestHex = primitives.toHex(primitives.sha256(publicKeyRaw));
  return digestHex.substring(0, 16);
}

final class HgfastDeviceIdentity {
  const HgfastDeviceIdentity({
    required this.deviceId,
    required this.publicKeyRaw,
    required this.keyPair,
  });

  final String deviceId;
  final Uint8List publicKeyRaw;
  final cg.SimpleKeyPair keyPair;

  Future<Uint8List> sign(List<int> message) async {
    final signature = await primitives.ed25519Algorithm.sign(
      message,
      keyPair: keyPair,
    );
    return Uint8List.fromList(signature.bytes);
  }
}

final class HgfastDeviceIdentityStore {
  HgfastDeviceIdentityStore({FlutterSecureStorage? storage})
    : _storage = storage ?? defaultHgfastSecureStorage;

  final FlutterSecureStorage _storage;
  Future<HgfastDeviceIdentity>? _inflight;

  // Two concurrent first calls (e.g. two providers racing at app start)
  // must not both miss the stored seed and each mint + persist their own —
  // the loser's identity would be handed to its caller but never survive
  // restart, since `write` isn't atomic-with-`read` here. Route every call
  // through the same in-flight Future so only one mint/persist ever runs.
  Future<HgfastDeviceIdentity> loadOrCreate() {
    return _inflight ??= _loadOrCreate().whenComplete(() {
      _inflight = null;
    });
  }

  Future<HgfastDeviceIdentity> _loadOrCreate() async {
    final existingSeedB64 = await _storage.read(key: deviceSeedStorageKey);
    final cg.SimpleKeyPair keyPair;
    if (existingSeedB64 != null) {
      List<int>? seed;
      try {
        seed = primitives.fromBase64(existingSeedB64);
      } on FormatException {
        seed = null;
      }
      if (seed != null && seed.length == 32) {
        keyPair = await primitives.ed25519Algorithm.newKeyPairFromSeed(seed);
      } else {
        keyPair = await _mintAndPersist();
      }
    } else {
      keyPair = await _mintAndPersist();
    }
    final publicKey = await keyPair.extractPublicKey();
    final publicKeyRaw = Uint8List.fromList(publicKey.bytes);
    return HgfastDeviceIdentity(
      deviceId: deriveDeviceId(publicKeyRaw),
      publicKeyRaw: publicKeyRaw,
      keyPair: keyPair,
    );
  }

  Future<cg.SimpleKeyPair> _mintAndPersist() async {
    final seed = _randomSeed();
    final keyPair = await primitives.ed25519Algorithm.newKeyPairFromSeed(
      seed,
    );
    await _storage.write(
      key: deviceSeedStorageKey,
      value: primitives.toBase64(seed),
    );
    return keyPair;
  }

  Future<void> reset() => _storage.delete(key: deviceSeedStorageKey);
}

Uint8List _randomSeed() {
  final random = Random.secure();
  return Uint8List.fromList(
    List<int>.generate(32, (_) => random.nextInt(256)),
  );
}
