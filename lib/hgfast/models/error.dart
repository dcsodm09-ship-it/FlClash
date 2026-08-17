enum HgfastResource {
  login,
  logout,
  restoreSession,
  bootstrap,
  config,
  announcements,
  plans,
  nodes,
  subscription,
  traffic,
  invite,
  lotteryStatus,
  aiChat,
  orderStatus,
  createOrder,
}

sealed class HgfastError {
  const HgfastError({this.message});

  const factory HgfastError.c1(String code, {String? message}) = HgfastC1Error;
  const factory HgfastError.authFailed({String? message}) = HgfastAuthFailed;
  const factory HgfastError.canaryDenied(
    HgfastResource resource, {
    String? message,
  }) = HgfastCanaryDenied;
  const factory HgfastError.registerDisabled({String? message}) =
      HgfastRegisterDisabled;
  const factory HgfastError.writeDisabled({String? message}) =
      HgfastWriteDisabled;
  const factory HgfastError.writeNotImplemented({String? message}) =
      HgfastWriteNotImplemented;
  const factory HgfastError.badPlanId({String? message}) = HgfastBadPlanId;
  const factory HgfastError.lotteryDisabled({String? message}) =
      HgfastLotteryDisabled;
  const factory HgfastError.clientApiStateUnavailable({String? message}) =
      HgfastClientApiStateUnavailable;
  const factory HgfastError.pinMismatch({String? message}) = HgfastPinMismatch;
  const factory HgfastError.banned({String? message}) = HgfastBanned;
  const factory HgfastError.expired({String? message}) = HgfastExpired;
  const factory HgfastError.quotaExhausted({String? message}) =
      HgfastQuotaExhausted;
  const factory HgfastError.noGroup({String? message}) = HgfastNoGroup;

  final String? message;

  String get code;
}

final class HgfastC1Error extends HgfastError {
  const HgfastC1Error(this.c1Code, {super.message});

  final String c1Code;

  @override
  String get code => c1Code;
}

final class HgfastAuthFailed extends HgfastError {
  const HgfastAuthFailed({super.message});

  @override
  String get code => 'AUTH_FAILED';
}

final class HgfastCanaryDenied extends HgfastError {
  const HgfastCanaryDenied(this.resource, {super.message});

  final HgfastResource resource;

  @override
  String get code => 'NOT_IN_CANARY';
}

final class HgfastRegisterDisabled extends HgfastError {
  const HgfastRegisterDisabled({super.message});

  @override
  String get code => 'REGISTER_DISABLED';
}

final class HgfastWriteDisabled extends HgfastError {
  const HgfastWriteDisabled({super.message});

  @override
  String get code => 'WRITE_DISABLED';
}

final class HgfastWriteNotImplemented extends HgfastError {
  const HgfastWriteNotImplemented({super.message});

  @override
  String get code => 'WRITE_NOT_IMPLEMENTED';
}

final class HgfastBadPlanId extends HgfastError {
  const HgfastBadPlanId({super.message});

  @override
  String get code => 'BAD_PLAN_ID';
}

final class HgfastLotteryDisabled extends HgfastError {
  const HgfastLotteryDisabled({super.message});

  @override
  String get code => 'LOTTERY_DISABLED';
}

final class HgfastClientApiStateUnavailable extends HgfastError {
  const HgfastClientApiStateUnavailable({super.message});

  @override
  String get code => 'CLIENT_API_STATE_UNAVAILABLE';
}

final class HgfastPinMismatch extends HgfastError {
  const HgfastPinMismatch({super.message});

  @override
  String get code => 'PIN_MISMATCH';
}

final class HgfastBanned extends HgfastError {
  const HgfastBanned({super.message});

  @override
  String get code => 'banned';
}

final class HgfastExpired extends HgfastError {
  const HgfastExpired({super.message});

  @override
  String get code => 'expired';
}

final class HgfastQuotaExhausted extends HgfastError {
  const HgfastQuotaExhausted({super.message});

  @override
  String get code => 'quota_exhausted';
}

final class HgfastNoGroup extends HgfastError {
  const HgfastNoGroup({super.message});

  @override
  String get code => 'no_group';
}
