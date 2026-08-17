import 'package:fl_clash/hgfast/transport/poll_policy.dart';
import 'package:flutter_test/flutter_test.dart';

// Fixture is copied verbatim from the live backend's poll_policy shape
// (app/core/client_api/data.js getClientConfig()), not invented.
final Map<String, Object?> _fixture = <String, Object?>{
  'version': 1,
  'mode': 'decorrelated_jitter',
  'order_status': <String, Object?>{
    'base_s': 3,
    'min_s': 2,
    'max_s': 11,
    'cap_s': 20,
  },
  'announcement': <String, Object?>{
    'base_s': 3600,
    'min_s': 2700,
    'max_s': 5400,
    'cap_s': 7200,
  },
  'default': <String, Object?>{'jitter_ratio': '0.3'},
  'align_to_wall_clock': false,
  'coalesce_window_s': 2,
  'transient_on_non_envelope': true,
};

void main() {
  test('fromJson parses the live poll_policy shape', () {
    final policy = HgfastPollPolicy.fromJson(_fixture);

    expect(policy.version, 1);
    expect(policy.mode, 'decorrelated_jitter');
    expect(policy.orderStatus.baseSeconds, 3);
    expect(policy.orderStatus.minSeconds, 2);
    expect(policy.orderStatus.maxSeconds, 11);
    expect(policy.orderStatus.capSeconds, 20);
    expect(policy.announcement.baseSeconds, 3600);
    expect(policy.announcement.capSeconds, 7200);
    expect(policy.defaultJitterRatio, closeTo(0.3, 1e-9));
    expect(policy.alignToWallClock, isFalse);
    expect(policy.coalesceWindowSeconds, 2);
    expect(policy.transientOnNonEnvelope, isTrue);
  });

  test('fromJson parses jitter_ratio as a string, not a signable float', () {
    // The backend ships jitter_ratio as a JSON string on purpose: the JCS
    // signing layer used elsewhere in this contract rejects non-integer
    // floats inside a signed object. This test locks that the client reads
    // the wire shape (string) rather than assuming a JSON number.
    final defaultMap = _fixture['default'] as Map<String, Object?>;
    expect(defaultMap['jitter_ratio'], isA<String>());
  });

  test('fromJson raises FormatException on a missing field', () {
    final broken = Map<String, Object?>.from(_fixture)..remove('mode');
    expect(() => HgfastPollPolicy.fromJson(broken), throwsFormatException);
  });

  test('fromJson raises FormatException on a non-numeric jitter_ratio', () {
    final broken = Map<String, Object?>.from(_fixture);
    broken['default'] = <String, Object?>{'jitter_ratio': 'not-a-number'};
    expect(() => HgfastPollPolicy.fromJson(broken), throwsFormatException);
  });

  test('fromJson raises FormatException on a wrong-typed resource block', () {
    final broken = Map<String, Object?>.from(_fixture);
    broken['order_status'] = 'not-a-map';
    expect(() => HgfastPollPolicy.fromJson(broken), throwsFormatException);
  });

  test('HgfastPollResourcePolicy.fromJson rejects cap_s <= 0', () {
    expect(
      () => HgfastPollResourcePolicy.fromJson(<String, Object?>{
        'base_s': 3,
        'min_s': 2,
        'max_s': 11,
        'cap_s': 0,
      }),
      throwsFormatException,
    );
  });

  test('HgfastPollResourcePolicy.fromJson rejects min_s > cap_s', () {
    expect(
      () => HgfastPollResourcePolicy.fromJson(<String, Object?>{
        'base_s': 3,
        'min_s': 30,
        'max_s': 11,
        'cap_s': 20,
      }),
      throwsFormatException,
    );
  });

  test('HgfastPollResourcePolicy.fromJson rejects a negative min_s', () {
    expect(
      () => HgfastPollResourcePolicy.fromJson(<String, Object?>{
        'base_s': 3,
        'min_s': -1,
        'max_s': 11,
        'cap_s': 20,
      }),
      throwsFormatException,
    );
  });

  test('HgfastPollResourcePolicy.fromJson rejects min_s: 0 (hot-poll floor)', () {
    // min_s is the scheduler's actual floor on every draw, not just the
    // first one — min_s: 0 (with base_s: 0) is a reproducible 0ms poll
    // loop, not a cosmetic edge case. See decorrelated_jitter_test.dart.
    expect(
      () => HgfastPollResourcePolicy.fromJson(<String, Object?>{
        'base_s': 0,
        'min_s': 0,
        'max_s': 11,
        'cap_s': 20,
      }),
      throwsFormatException,
    );
  });

  test('fromJson rejects a negative jitter_ratio', () {
    final broken = Map<String, Object?>.from(_fixture);
    broken['default'] = <String, Object?>{'jitter_ratio': '-0.1'};
    expect(() => HgfastPollPolicy.fromJson(broken), throwsFormatException);
  });

  test('fromJson rejects a non-finite jitter_ratio', () {
    final broken = Map<String, Object?>.from(_fixture);
    broken['default'] = <String, Object?>{'jitter_ratio': 'NaN'};
    expect(() => HgfastPollPolicy.fromJson(broken), throwsFormatException);
  });
}
