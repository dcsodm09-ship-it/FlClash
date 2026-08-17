import '../models/error.dart';
import '../models/node.dart';

typedef HgfastJson = Map<String, Object?>;

sealed class HgfastPayload {
  HgfastPayload(HgfastJson values) : values = Map.unmodifiable(values);

  final HgfastJson values;
}

final class HgfastSession extends HgfastPayload {
  HgfastSession(super.values);
}

final class HgfastBootstrap extends HgfastPayload {
  HgfastBootstrap(super.values);
}

final class HgfastConfig extends HgfastPayload {
  HgfastConfig(super.values);
}

final class HgfastAnnouncementCatalog extends HgfastPayload {
  HgfastAnnouncementCatalog(super.values);
}

final class HgfastPlanCatalog extends HgfastPayload {
  HgfastPlanCatalog(super.values);
}

final class HgfastSubscription extends HgfastPayload {
  HgfastSubscription(super.values);
}

final class HgfastTraffic extends HgfastPayload {
  HgfastTraffic(super.values);
}

final class HgfastInvite extends HgfastPayload {
  HgfastInvite(super.values);
}

final class HgfastLotteryStatus extends HgfastPayload {
  HgfastLotteryStatus(super.values);
}

final class HgfastAiResponse extends HgfastPayload {
  HgfastAiResponse(super.values);
}

final class HgfastOrderStatus extends HgfastPayload {
  HgfastOrderStatus(super.values);
}

sealed class HgfastResult<T, E> {
  const HgfastResult();

  const factory HgfastResult.success(T value) = HgfastResultSuccess<T, E>;
  const factory HgfastResult.failure(E error) = HgfastResultFailure<T, E>;

  bool get isSuccess => this is HgfastResultSuccess<T, E>;
  bool get isFailure => this is HgfastResultFailure<T, E>;
}

final class HgfastResultSuccess<T, E> extends HgfastResult<T, E> {
  const HgfastResultSuccess(this.value);

  final T value;
}

final class HgfastResultFailure<T, E> extends HgfastResult<T, E> {
  const HgfastResultFailure(this.error);

  final E error;
}

abstract interface class HgfastRepository {
  Future<HgfastResult<HgfastSession, HgfastError>> login({
    required String credential,
    required String password,
  });

  Future<HgfastResult<void, HgfastError>> logout();

  Future<HgfastResult<HgfastSession?, HgfastError>> restoreSession();

  Future<HgfastResult<HgfastBootstrap, HgfastError>> bootstrap();

  Future<HgfastResult<HgfastConfig, HgfastError>> config();

  Future<HgfastResult<HgfastAnnouncementCatalog, HgfastError>> announcements();

  Future<HgfastResult<HgfastPlanCatalog, HgfastError>> plans();

  Future<HgfastResult<NodeCatalog, HgfastError>> nodes();

  Future<HgfastResult<HgfastSubscription, HgfastError>> subscription();

  Future<HgfastResult<HgfastTraffic, HgfastError>> traffic();

  Future<HgfastResult<HgfastInvite, HgfastError>> invite();

  Future<HgfastResult<HgfastLotteryStatus, HgfastError>> lotteryStatus();

  Future<HgfastResult<HgfastAiResponse, HgfastError>> aiChat({
    required String message,
    String? model,
    HgfastJson? context,
  });

  Future<HgfastResult<HgfastOrderStatus, HgfastError>> orderStatus(String orderId);

  // Real write path: POST /order. Server-side this is currently permanently
  // gated (403 WRITE_DISABLED, or 501 WRITE_NOT_IMPLEMENTED once the write
  // gate itself is on) until it is routed through the panel's authed
  // req.user order/save flow — see v2board-adapter.js's `orderCreateSpec()`.
  // This method still performs the real signed call; it is expected to fail
  // against the live backend today, callers must handle that honestly.
  Future<HgfastResult<HgfastOrderStatus, HgfastError>> createOrder({
    required String planId,
    required String period,
    String? couponCode,
  });
}
