import 'package:fl_clash/hgfast/transport/device_identity.dart';
import 'package:fl_clash/hgfast/transport/primitives.dart' as primitives;
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_secure_storage/test/test_flutter_secure_storage_platform.dart';
import 'package:flutter_secure_storage_platform_interface/flutter_secure_storage_platform_interface.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('deriveDeviceId is the first 16 hex chars of sha256(pubkey)', () {
    final publicKey = List<int>.filled(32, 7);
    final expected = primitives
        .toHex(primitives.sha256(publicKey))
        .substring(0, 16);
    expect(deriveDeviceId(publicKey), expected);
    expect(deriveDeviceId(publicKey).length, 16);
  });

  test('loadOrCreate persists the seed and returns a stable identity on reload', () async {
    final platform = TestFlutterSecureStoragePlatform(<String, String>{});
    FlutterSecureStoragePlatform.instance = platform;
    const storage = FlutterSecureStorage();
    final store = HgfastDeviceIdentityStore(storage: storage);

    final first = await store.loadOrCreate();
    final second = await store.loadOrCreate();

    expect(first.deviceId, second.deviceId);
    expect(first.publicKeyRaw, second.publicKeyRaw);
    expect(platform.data.containsKey(deviceSeedStorageKey), isTrue);
  });

  test('a signature from the stored identity verifies against its own public key', () async {
    final platform = TestFlutterSecureStoragePlatform(<String, String>{});
    FlutterSecureStoragePlatform.instance = platform;
    final store = HgfastDeviceIdentityStore(storage: const FlutterSecureStorage());

    final identity = await store.loadOrCreate();
    final message = primitives.sha256(<int>[1, 2, 3]);
    final signature = await identity.sign(message);

    final verified = await primitives.ed25519Verify(
      identity.publicKeyRaw,
      message,
      signature,
    );
    expect(verified, isTrue);
  });

  test('reset clears the stored seed so the next load mints a new identity', () async {
    final platform = TestFlutterSecureStoragePlatform(<String, String>{});
    FlutterSecureStoragePlatform.instance = platform;
    final store = HgfastDeviceIdentityStore(storage: const FlutterSecureStorage());

    final first = await store.loadOrCreate();
    await store.reset();
    final second = await store.loadOrCreate();

    expect(first.deviceId, isNot(second.deviceId));
  });

  test('concurrent loadOrCreate calls share one mint instead of racing', () async {
    final platform = TestFlutterSecureStoragePlatform(<String, String>{});
    FlutterSecureStoragePlatform.instance = platform;
    final store = HgfastDeviceIdentityStore(storage: const FlutterSecureStorage());

    final results = await Future.wait(<Future<HgfastDeviceIdentity>>[
      store.loadOrCreate(),
      store.loadOrCreate(),
      store.loadOrCreate(),
    ]);

    final deviceIds = results.map((identity) => identity.deviceId).toSet();
    expect(deviceIds, hasLength(1));
    // A losing racer that minted-but-never-persisted would still have
    // returned a self-consistent identity to its own test above; the real
    // regression this guards is a *third*, unobserved identity existing in
    // storage that neither caller got back. There is exactly one persisted
    // seed, and reloading afterwards must agree with every racer.
    final reloaded = await store.loadOrCreate();
    expect(reloaded.deviceId, deviceIds.single);
  });

  test('a corrupted stored seed is replaced by a fresh mint instead of failing forever', () async {
    final platform = TestFlutterSecureStoragePlatform(<String, String>{
      deviceSeedStorageKey: 'not-valid-base64!!',
    });
    FlutterSecureStoragePlatform.instance = platform;
    final store = HgfastDeviceIdentityStore(storage: const FlutterSecureStorage());

    final identity = await store.loadOrCreate();

    expect(identity.deviceId.length, 16);
    expect(
      platform.data[deviceSeedStorageKey],
      isNot('not-valid-base64!!'),
    );
  });

  test('a stored seed of the wrong length is replaced by a fresh mint', () async {
    final platform = TestFlutterSecureStoragePlatform(<String, String>{
      deviceSeedStorageKey: primitives.toBase64(<int>[1, 2, 3]),
    });
    FlutterSecureStoragePlatform.instance = platform;
    final store = HgfastDeviceIdentityStore(storage: const FlutterSecureStorage());

    final identity = await store.loadOrCreate();

    expect(identity.deviceId.length, 16);
    expect(
      primitives.fromBase64(platform.data[deviceSeedStorageKey]!).length,
      32,
    );
  });
}
