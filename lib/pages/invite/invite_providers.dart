import 'package:fl_clash/hgfast/repository/hgfast_result_x.dart';
import 'package:fl_clash/providers/providers.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

// TODO: replace with a real `feature_flags` provider once the backend
// exposes one generically (e.g. on bootstrap()/config()). No such provider
// exists in this codebase yet. Until then this derives a best-effort
// "should the 抽奖 (prize draw) entry be visible" signal from the existing
// `lotteryStatus()` endpoint (the closest real thing to a `feature_flags`
// read this repository currently has) and *always* defaults to hidden/false
// on any ambiguity, parse failure, or request error — including the
// backend's current `feature_flags.lottery: false`. It must never default
// to visible.
//
// Note for whoever wires the real flag: `HgfastError.lotteryDisabled()` /
// `HgfastLotteryDisabled` exist in lib/hgfast/models/error.dart, but
// lib/hgfast/repository/hgfast_error_mapping.dart's `mapHgfastErrorCode`
// switch never actually constructs that case for a `LOTTERY_DISABLED` code
// (falls through to the generic `clientApiStateUnavailable` default) — so a
// disabled-lottery response cannot currently be distinguished from any other
// transport/API error by type. That's a pre-existing gap outside this
// screen's scope; this provider works around it by defaulting to hidden on
// every failure path rather than depending on that distinction.
final hgfastLotteryEnabledProvider = FutureProvider.autoDispose<bool>((
  ref,
) async {
  final repository = ref.watch(hgfastRepositoryProvider);
  final result = await repository.lotteryStatus();
  final status = result.successValue;
  if (status == null) {
    return false;
  }
  final values = status.values;
  for (final key in const ['enabled', 'open', 'available', 'is_open']) {
    final candidate = values[key];
    if (candidate is bool) {
      return candidate;
    }
  }
  final flags = values['feature_flags'];
  if (flags is Map) {
    final lottery = flags['lottery'];
    if (lottery is bool) {
      return lottery;
    }
  }
  return false;
});
