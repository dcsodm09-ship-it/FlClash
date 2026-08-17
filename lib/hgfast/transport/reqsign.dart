import 'dart:convert';

import 'primitives.dart' as primitives;

const String hmacKeyString = 'HGFAST_SIGN_2026';

String canonicalUri(String pathname, [Map<String, String>? query]) {
  if (query == null || query.isEmpty) {
    return pathname;
  }
  final keys = query.keys.toList()..sort();
  final parts = keys.map(
    (key) =>
        '${Uri.encodeComponent(key)}=${Uri.encodeComponent(query[key]!)}',
  );
  return '$pathname?${parts.join('&')}';
}

String buildCanonicalString({
  required String method,
  required String canonUri,
  required String nonce,
  required String timestamp,
  required List<int> body,
}) {
  final bodyHash = primitives.toHex(primitives.sha256(body));
  return '${method.toUpperCase()}\n$canonUri\n$nonce\n$timestamp\n$bodyHash';
}

String sign({
  required String method,
  required String canonUri,
  required String nonce,
  required String timestamp,
  required List<int> body,
}) {
  final canonical = buildCanonicalString(
    method: method,
    canonUri: canonUri,
    nonce: nonce,
    timestamp: timestamp,
    body: body,
  );
  return primitives.toHex(
    primitives.hmacSha256(
      utf8.encode(hmacKeyString),
      utf8.encode(canonical),
    ),
  );
}

String requestHash({
  required String method,
  required String canonUri,
  required String nonce,
  required String timestamp,
  required List<int> body,
  required String deviceId,
  required String token,
}) {
  final canonical = buildCanonicalString(
    method: method,
    canonUri: canonUri,
    nonce: nonce,
    timestamp: timestamp,
    body: body,
  );
  final tokenHash = primitives.toHex(primitives.sha256(utf8.encode(token)));
  return primitives.toHex(
    primitives.sha256(utf8.encode('$canonical\n$deviceId\n$tokenHash')),
  );
}

final class C1RequestHeaders {
  const C1RequestHeaders({
    required this.nonce,
    required this.timestamp,
    required this.signature,
    required this.deviceId,
    required this.requestHash,
  });

  final String nonce;
  final String timestamp;
  final String signature;
  final String deviceId;
  final String requestHash;

  Map<String, String> toHeaders() {
    return <String, String>{
      'X-HG-Nonce': nonce,
      'X-HG-Ts': timestamp,
      'X-HG-Sign': signature,
      'X-HG-Device': deviceId,
    };
  }
}

C1RequestHeaders buildRequestHeaders({
  required String method,
  required String pathname,
  Map<String, String>? query,
  required List<int> body,
  required String nonce,
  required String timestamp,
  required String deviceId,
  required String token,
}) {
  final canonUri = canonicalUri(pathname, query);
  final signature = sign(
    method: method,
    canonUri: canonUri,
    nonce: nonce,
    timestamp: timestamp,
    body: body,
  );
  final hash = requestHash(
    method: method,
    canonUri: canonUri,
    nonce: nonce,
    timestamp: timestamp,
    body: body,
    deviceId: deviceId,
    token: token,
  );
  return C1RequestHeaders(
    nonce: nonce,
    timestamp: timestamp,
    signature: signature,
    deviceId: deviceId,
    requestHash: hash,
  );
}
