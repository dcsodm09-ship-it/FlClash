import 'dart:math';

import 'poll_policy.dart';

// Consumes an HgfastPollResourcePolicy to produce the next poll interval.
// The backend's own recurrence (app/core/client_api/data.js, poll_policy
// comment) is exactly `next = min(cap_s, uniform(min_s, prev * 3))`, with
// `base_s` as the seed for `prev` before the first draw — that part is not
// a guess, and every draw (including the first) follows the same formula.
// `max_s` never appears in that recurrence; it is parsed by
// HgfastPollResourcePolicy but intentionally unused here. Confirm against
// whoever owns `poll_policy` server-side before assuming that's final.
final class HgfastDecorrelatedJitterSchedule {
  HgfastDecorrelatedJitterSchedule({required this.policy, Random? random})
    : _random = random ?? Random.secure(),
      _previousSeconds = policy.baseSeconds.toDouble();

  final HgfastPollResourcePolicy policy;
  final Random _random;
  double _previousSeconds;

  Duration next() {
    final upperBound = _previousSeconds * 3;
    final seconds = min(
      _uniform(policy.minSeconds.toDouble(), upperBound),
      policy.capSeconds.toDouble(),
    );
    _previousSeconds = seconds;
    return Duration(milliseconds: (seconds * 1000).round());
  }

  double _uniform(double low, double high) {
    if (high <= low) {
      return low;
    }
    return low + _random.nextDouble() * (high - low);
  }
}
