import '../models/error.dart';

HgfastError mapHgfastErrorCode(
  String? code,
  String? message,
  HgfastResource resource,
) {
  if (code == null || code.isEmpty) {
    return HgfastError.clientApiStateUnavailable(message: message);
  }
  if (code.startsWith('C1_')) {
    return HgfastError.c1(code, message: message);
  }
  switch (code) {
    case 'AUTH_FAILED':
      return HgfastError.authFailed(message: message);
    case 'NOT_IN_CANARY':
      return HgfastError.canaryDenied(resource, message: message);
    case 'REGISTER_DISABLED':
      return HgfastError.registerDisabled(message: message);
    case 'WRITE_DISABLED':
      return HgfastError.writeDisabled(message: message);
    case 'WRITE_NOT_IMPLEMENTED':
      return HgfastError.writeNotImplemented(message: message);
    case 'BAD_PLAN_ID':
      return HgfastError.badPlanId(message: message);
    case 'CLIENT_API_STATE_UNAVAILABLE':
      return HgfastError.clientApiStateUnavailable(message: message);
    default:
      return HgfastError.clientApiStateUnavailable(
        message: message == null ? code : '$code: $message',
      );
  }
}

HgfastError? mapHgfastAccountReason(Object? reason) {
  if (reason is! String) {
    return null;
  }
  switch (reason) {
    case 'banned':
      return const HgfastError.banned();
    case 'expired':
      return const HgfastError.expired();
    case 'quota_exhausted':
      return const HgfastError.quotaExhausted();
    case 'no_group':
      return const HgfastError.noGroup();
    default:
      return null;
  }
}
