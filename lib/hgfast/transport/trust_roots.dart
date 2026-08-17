import 'primitives.dart' as primitives;

// Pulled from the live hgcloud vault's CLIENT_API_ROOT_PUBS_B64 /
// CLIENT_API_ROOT_EPOCH (2026-08-17) — the backend's own keyctx.js documents
// these as public, non-secret (only the matching *_PRIV_* vault entries are
// secret, and those never leave the server). Rotation = ship a new value
// here in an app update, same as the doc's own §3.4 decision.
const List<String> productionRootPublicKeysBase64 = <String>[
  '9InaNUXF3V3WJbcgAgTJ8bbsZ6lE0YBMT8wBb25ShEg=',
  'dRZep1j9etsC22H7PAHKo+lRna+ljCpJNZMiKNHRlbM=',
  '8tJ6+kyf8bv60GODSycdosIpEXKoR7S40QB2YvObYyY=',
];

const int productionRootEpoch = 1;

List<List<int>> get productionRootPublicKeys {
  return productionRootPublicKeysBase64
      .map(primitives.fromBase64)
      .toList(growable: false);
}
