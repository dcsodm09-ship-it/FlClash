import 'dart:math';

import 'package:fl_clash/hgfast/transport/decorrelated_jitter.dart';
import 'package:fl_clash/hgfast/transport/poll_policy.dart';
import 'package:flutter_test/flutter_test.dart';

const HgfastPollResourcePolicy _orderStatusPolicy = HgfastPollResourcePolicy(
  baseSeconds: 3,
  minSeconds: 2,
  maxSeconds: 11,
  capSeconds: 20,
);

void main() {
  test('the first draw is uniform(min_s, base_s * 3), seeded by base_s', () {
    // base_s=3, min_s=2 -> uniform(2, 9), independent of max_s=11.
    for (var i = 0; i < 200; i++) {
      final first = HgfastDecorrelatedJitterSchedule(
        policy: _orderStatusPolicy,
        random: Random(i),
      ).next();
      expect(first.inMilliseconds, greaterThanOrEqualTo(2000));
      expect(first.inMilliseconds, lessThanOrEqualTo(9000));
    }
  });

  test('every subsequent draw stays within [min_s, cap_s]', () {
    final schedule = HgfastDecorrelatedJitterSchedule(
      policy: _orderStatusPolicy,
      random: Random(7),
    );
    schedule.next();
    for (var i = 0; i < 500; i++) {
      final draw = schedule.next();
      expect(draw.inMilliseconds, greaterThanOrEqualTo(2000));
      expect(draw.inMilliseconds, lessThanOrEqualTo(20000));
    }
  });

  test('draws vary across calls instead of settling on a fixed period', () {
    final schedule = HgfastDecorrelatedJitterSchedule(
      policy: _orderStatusPolicy,
      random: Random(42),
    );
    final draws = <int>{
      for (var i = 0; i < 20; i++) schedule.next().inMilliseconds,
    };
    expect(draws.length, greaterThan(1));
  });

  test('a fixed Random seed makes the sequence reproducible', () {
    final a = HgfastDecorrelatedJitterSchedule(
      policy: _orderStatusPolicy,
      random: Random(99),
    );
    final b = HgfastDecorrelatedJitterSchedule(
      policy: _orderStatusPolicy,
      random: Random(99),
    );
    final drawsA = List<int>.generate(10, (_) => a.next().inMilliseconds);
    final drawsB = List<int>.generate(10, (_) => b.next().inMilliseconds);
    expect(drawsA, drawsB);
  });

  test('a degenerate min_s == max_s policy still produces a valid interval', () {
    const policy = HgfastPollResourcePolicy(
      baseSeconds: 5,
      minSeconds: 5,
      maxSeconds: 5,
      capSeconds: 5,
    );
    final schedule = HgfastDecorrelatedJitterSchedule(
      policy: policy,
      random: Random(3),
    );
    expect(schedule.next().inMilliseconds, 5000);
    expect(schedule.next().inMilliseconds, 5000);
  });

  test('min_s is a real floor even with base_s: 0 (defense in depth vs the hot-poll bug)', () {
    // HgfastPollResourcePolicy's const constructor bypasses fromJson's own
    // validation (min_s >= 1), so the scheduler itself must not depend on
    // that guard alone. Regression coverage for a real bug: an earlier
    // version's first-draw special case meant base_s: 0 produced an
    // absorbing 0ms interval forever.
    const policy = HgfastPollResourcePolicy(
      baseSeconds: 0,
      minSeconds: 1,
      maxSeconds: 11,
      capSeconds: 20,
    );
    final schedule = HgfastDecorrelatedJitterSchedule(
      policy: policy,
      random: Random(11),
    );
    for (var i = 0; i < 1000; i++) {
      expect(schedule.next().inMilliseconds, greaterThanOrEqualTo(1000));
    }
  });
}
