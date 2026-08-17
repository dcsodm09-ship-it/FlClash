import 'package:fl_clash/hgfast/transport/signing.dart' as signing;
import 'package:fl_clash/hgfast/transport/trust_roots.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('every embedded root public key decodes to exactly 32 raw bytes', () {
    expect(productionRootPublicKeysBase64, isNotEmpty);
    for (final key in productionRootPublicKeys) {
      expect(key.length, 32);
    }
  });

  test('embedded root keys are distinct and match their base64 count', () {
    expect(
      productionRootPublicKeys.length,
      productionRootPublicKeysBase64.length,
    );
    expect(
      productionRootPublicKeysBase64.toSet().length,
      productionRootPublicKeysBase64.length,
    );
  });

  test('productionRootEpoch is a positive integer', () {
    expect(productionRootEpoch, greaterThan(0));
  });

  test('verifyCert fails closed against a fabricated cert, not just an empty root list', () {
    // The consequence that matters: shipping real roots must not accidentally
    // make verification permissive. A cert nobody signed with any of the
    // embedded roots must still be rejected.
    final fabricated = <String, Object?>{
      'v': signing.subkeyCertVersion,
      'key_id': 'not-a-real-key',
      'subkey_pub': 'oJql9HpnWYAv+VX43C0qFKXJnSO+l/hkEn/5ODRVpPA=',
      'usage': 'C_RESPONSE',
      'valid_from_epoch': 1,
      'valid_to_epoch': 10,
      'root_sig':
          '/5FvOQiSLzY5sSMwtSepkUViw71U2oq89qghtWVYk5QwcR6X6oZ9mvVH1aB2sytvQNi+Pv/tUMQ71fjp0UoJBg==',
    };
    expect(
      signing.verifyCert(
        cert: fabricated,
        rootPublicKeys: productionRootPublicKeys,
        rootEpoch: productionRootEpoch,
      ),
      completion(
        isA<signing.SigningVerifyResult>().having(
          (result) => result.error,
          'error',
          'BadSubkeyCert',
        ),
      ),
    );
  });
}
