import 'jcs.dart' as jcs;
import 'primitives.dart' as primitives;

const String subkeyCertVersion = 'HGFAST-SUBKEY-CERT-v1';

String domainSeparator(String usage, String kind) {
  switch (usage) {
    case 'B_CONFIG':
      return 'HGFAST-B-$kind-v1';
    case 'C_RESPONSE':
      return 'HGFAST-C-RESPONSE-$kind-v1';
    default:
      throw FormatException('Unknown signing usage $usage');
  }
}

final class SigningVerifyResult {
  const SigningVerifyResult.ok() : error = null;

  const SigningVerifyResult.fail(String failureCode) : error = failureCode;

  final String? error;

  bool get isOk => error == null;
}

Map<String, Object?> _certSigningObject(Map<String, Object?> cert) {
  return <String, Object?>{
    'v': cert['v'],
    'key_id': cert['key_id'],
    'subkey_pub': cert['subkey_pub'],
    'usage': cert['usage'],
    'valid_from_epoch': cert['valid_from_epoch'],
    'valid_to_epoch': cert['valid_to_epoch'],
  };
}

Map<String, Object?> _objectSigningObject(Map<String, Object?> obj) {
  final copy = Map<String, Object?>.from(obj);
  copy.remove('subkey_sig');
  return copy;
}

// Every accessor below is guarded rather than an `as` cast, and every
// function body is wrapped in a catch-all: a hostile or merely malformed
// cert/object/envelope (any entry-pool host, a MITM on a skip-cert-verify
// node) must come back as a SigningVerifyResult.fail, never an uncaught
// TypeError/FormatException a caller isn't written to expect.
List<int>? _decodeBase64Field(Map<String, Object?> json, String key) {
  final value = json[key];
  if (value is! String) {
    return null;
  }
  try {
    return primitives.fromBase64(value);
  } on FormatException {
    return null;
  }
}

Future<SigningVerifyResult> verifyCert({
  required Map<String, Object?> cert,
  required List<List<int>> rootPublicKeys,
  required int rootEpoch,
}) async {
  try {
    if (cert['v'] != subkeyCertVersion) {
      return const SigningVerifyResult.fail('BadCertVersion');
    }
    final validFrom = cert['valid_from_epoch'];
    final validTo = cert['valid_to_epoch'];
    if (validFrom is! int || validTo is! int) {
      return const SigningVerifyResult.fail('MalformedCert');
    }
    if (rootEpoch < validFrom || rootEpoch > validTo) {
      return const SigningVerifyResult.fail('CertEpochInvalid');
    }
    final signature = _decodeBase64Field(cert, 'root_sig');
    if (signature == null) {
      return const SigningVerifyResult.fail('MalformedCert');
    }
    final message = jcs.jcsBytes(_certSigningObject(cert));
    for (final rootKey in rootPublicKeys) {
      if (await primitives.ed25519Verify(rootKey, message, signature)) {
        return const SigningVerifyResult.ok();
      }
    }
    return const SigningVerifyResult.fail('BadSubkeyCert');
  } on Object {
    return const SigningVerifyResult.fail('MalformedCert');
  }
}

Future<SigningVerifyResult> verifyObject({
  required Map<String, Object?> obj,
  required Map<String, Object?> cert,
  required List<List<int>> rootPublicKeys,
  required int rootEpoch,
  required String expectedUsage,
  int? minAcceptedVersion,
}) async {
  try {
    if (cert['usage'] != expectedUsage) {
      return const SigningVerifyResult.fail('KeyUsageMismatch');
    }
    final certResult = await verifyCert(
      cert: cert,
      rootPublicKeys: rootPublicKeys,
      rootEpoch: rootEpoch,
    );
    if (!certResult.isOk) {
      return certResult;
    }
    if (minAcceptedVersion != null) {
      final objectVersion = obj['object_version'];
      if (objectVersion is! int || objectVersion < minAcceptedVersion) {
        return const SigningVerifyResult.fail('VersionRollback');
      }
    }
    final subkeyPub = _decodeBase64Field(cert, 'subkey_pub');
    final signature = _decodeBase64Field(obj, 'subkey_sig');
    if (subkeyPub == null || signature == null) {
      return const SigningVerifyResult.fail('MalformedObject');
    }
    final message = jcs.jcsBytes(_objectSigningObject(obj));
    if (!await primitives.ed25519Verify(subkeyPub, message, signature)) {
      return const SigningVerifyResult.fail('BadObjectSignature');
    }
    return const SigningVerifyResult.ok();
  } on Object {
    return const SigningVerifyResult.fail('MalformedObject');
  }
}

Future<SigningVerifyResult> verifyEnvelope({
  required Map<String, Object?> envelope,
  required String signatureBase64,
  required Map<String, Object?> cert,
  required List<List<int>> rootPublicKeys,
  required int rootEpoch,
}) async {
  try {
    if (cert['usage'] != 'C_RESPONSE') {
      return const SigningVerifyResult.fail('KeyUsageMismatch');
    }
    final certResult = await verifyCert(
      cert: cert,
      rootPublicKeys: rootPublicKeys,
      rootEpoch: rootEpoch,
    );
    if (!certResult.isOk) {
      return certResult;
    }
    final subkeyPub = _decodeBase64Field(cert, 'subkey_pub');
    List<int>? signature;
    try {
      signature = primitives.fromBase64(signatureBase64);
    } on FormatException {
      signature = null;
    }
    if (subkeyPub == null || signature == null) {
      return const SigningVerifyResult.fail('MalformedSignature');
    }
    final message = jcs.jcsBytes(envelope);
    if (!await primitives.ed25519Verify(subkeyPub, message, signature)) {
      return const SigningVerifyResult.fail('BadSignature');
    }
    return const SigningVerifyResult.ok();
  } on Object {
    return const SigningVerifyResult.fail('MalformedSignature');
  }
}
