final class HgfastPollResourcePolicy {
  const HgfastPollResourcePolicy({
    required this.baseSeconds,
    required this.minSeconds,
    required this.maxSeconds,
    required this.capSeconds,
  });

  factory HgfastPollResourcePolicy.fromJson(Map<String, Object?> json) {
    final baseSeconds = _requiredInt(json, 'base_s');
    final minSeconds = _requiredInt(json, 'min_s');
    final maxSeconds = _requiredInt(json, 'max_s');
    final capSeconds = _requiredInt(json, 'cap_s');
    // min_s >= 1 is load-bearing, not cosmetic: the scheduler's recurrence
    // is min(cap_s, uniform(min_s, prev*3)), and _uniform() returns min_s
    // itself whenever prev*3 collapses below it — so min_s is the actual
    // floor on every draw, forever, not just the first one. min_s: 0 (or a
    // base_s: 0 seed with no other floor) makes 0ms an absorbing state: a
    // hot-poll loop against the entry pool, indistinguishable from a client
    // bug until someone reads the traffic. This is a signed-server-response
    // field, but "operator typo" is as real a threat model here as hostile.
    if (minSeconds < 1 || capSeconds <= 0 || minSeconds > capSeconds) {
      throw const FormatException(
        'Invalid poll resource policy: need 1 <= min_s <= cap_s and cap_s > 0',
      );
    }
    if (baseSeconds < 0 || maxSeconds < 0) {
      throw const FormatException(
        'Invalid poll resource policy: base_s/max_s must be non-negative',
      );
    }
    return HgfastPollResourcePolicy(
      baseSeconds: baseSeconds,
      minSeconds: minSeconds,
      maxSeconds: maxSeconds,
      capSeconds: capSeconds,
    );
  }

  final int baseSeconds;
  final int minSeconds;
  final int maxSeconds;
  final int capSeconds;
}

// Parsed from the backend's `poll_policy` field on /config (app/core/
// client_api/data.js). `order_status`/`announcement` carry the full
// decorrelated-jitter tuple; `default.jitter_ratio` is a fallback for any
// future polled resource the server adds without its own tuple, and is not
// yet consumed by anything in this codebase. `jitter_ratio` is shipped as a
// string on purpose — the JCS signing layer rejects non-integer floats, and
// a prior deployment sent it as a raw float and broke /config on every host
// (see the backend commit's own postmortem note).
final class HgfastPollPolicy {
  const HgfastPollPolicy({
    required this.version,
    required this.mode,
    required this.orderStatus,
    required this.announcement,
    required this.defaultJitterRatio,
    required this.alignToWallClock,
    required this.coalesceWindowSeconds,
    required this.transientOnNonEnvelope,
  });

  factory HgfastPollPolicy.fromJson(Map<String, Object?> json) {
    return HgfastPollPolicy(
      version: _requiredInt(json, 'version'),
      mode: _requiredString(json, 'mode'),
      orderStatus: HgfastPollResourcePolicy.fromJson(
        _requiredMap(json, 'order_status'),
      ),
      announcement: HgfastPollResourcePolicy.fromJson(
        _requiredMap(json, 'announcement'),
      ),
      defaultJitterRatio: _requiredDoubleString(
        _requiredMap(json, 'default'),
        'jitter_ratio',
      ),
      alignToWallClock: _requiredBool(json, 'align_to_wall_clock'),
      coalesceWindowSeconds: _requiredInt(json, 'coalesce_window_s'),
      transientOnNonEnvelope: _requiredBool(
        json,
        'transient_on_non_envelope',
      ),
    );
  }

  final int version;
  final String mode;
  final HgfastPollResourcePolicy orderStatus;
  final HgfastPollResourcePolicy announcement;
  final double defaultJitterRatio;
  final bool alignToWallClock;
  final int coalesceWindowSeconds;
  final bool transientOnNonEnvelope;
}

int _requiredInt(Map<String, Object?> json, String key) {
  final value = json[key];
  if (value is int) {
    return value;
  }
  throw FormatException('Invalid $key');
}

String _requiredString(Map<String, Object?> json, String key) {
  final value = json[key];
  if (value is String) {
    return value;
  }
  throw FormatException('Invalid $key');
}

bool _requiredBool(Map<String, Object?> json, String key) {
  final value = json[key];
  if (value is bool) {
    return value;
  }
  throw FormatException('Invalid $key');
}

Map<String, Object?> _requiredMap(Map<String, Object?> json, String key) {
  final value = json[key];
  if (value is Map) {
    return Map<String, Object?>.from(value);
  }
  throw FormatException('Invalid $key');
}

double _requiredDoubleString(Map<String, Object?> json, String key) {
  final value = json[key];
  if (value is String) {
    final parsed = double.tryParse(value);
    if (parsed != null && parsed.isFinite && parsed >= 0) {
      return parsed;
    }
  }
  throw FormatException('Invalid $key');
}
