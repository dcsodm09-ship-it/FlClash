import 'package:fl_clash/hgfast/models/error.dart';
import 'package:fl_clash/hgfast/repository/hgfast_error_mapping.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('mapHgfastErrorCode', () {
    test('maps a C1_ prefixed code to HgfastC1Error verbatim', () {
      final error = mapHgfastErrorCode('C1_BadSignature', 'bad sig', HgfastResource.nodes);
      expect(error, isA<HgfastC1Error>());
      expect(error.code, 'C1_BadSignature');
    });

    test('maps AUTH_FAILED', () {
      final error = mapHgfastErrorCode('AUTH_FAILED', null, HgfastResource.nodes);
      expect(error, isA<HgfastAuthFailed>());
    });

    test('maps NOT_IN_CANARY to the given resource', () {
      final error = mapHgfastErrorCode('NOT_IN_CANARY', null, HgfastResource.subscription);
      expect(error, isA<HgfastCanaryDenied>());
      expect((error as HgfastCanaryDenied).resource, HgfastResource.subscription);
    });

    test('maps REGISTER_DISABLED', () {
      expect(
        mapHgfastErrorCode('REGISTER_DISABLED', null, HgfastResource.login),
        isA<HgfastRegisterDisabled>(),
      );
    });

    test('maps WRITE_DISABLED and WRITE_NOT_IMPLEMENTED', () {
      expect(
        mapHgfastErrorCode('WRITE_DISABLED', null, HgfastResource.orderStatus),
        isA<HgfastWriteDisabled>(),
      );
      expect(
        mapHgfastErrorCode('WRITE_NOT_IMPLEMENTED', null, HgfastResource.orderStatus),
        isA<HgfastWriteNotImplemented>(),
      );
    });

    test('maps BAD_PLAN_ID', () {
      expect(
        mapHgfastErrorCode('BAD_PLAN_ID', null, HgfastResource.plans),
        isA<HgfastBadPlanId>(),
      );
    });

    test('maps CLIENT_API_STATE_UNAVAILABLE', () {
      expect(
        mapHgfastErrorCode('CLIENT_API_STATE_UNAVAILABLE', null, HgfastResource.config),
        isA<HgfastClientApiStateUnavailable>(),
      );
    });

    test('falls back to CLIENT_API_STATE_UNAVAILABLE for an unknown code', () {
      final error = mapHgfastErrorCode('SOME_NEW_CODE', 'detail', HgfastResource.config);
      expect(error, isA<HgfastClientApiStateUnavailable>());
      expect(error.message, contains('SOME_NEW_CODE'));
      expect(error.message, contains('detail'));
    });

    test('falls back to CLIENT_API_STATE_UNAVAILABLE for a null/empty code', () {
      expect(
        mapHgfastErrorCode(null, null, HgfastResource.config),
        isA<HgfastClientApiStateUnavailable>(),
      );
      expect(
        mapHgfastErrorCode('', null, HgfastResource.config),
        isA<HgfastClientApiStateUnavailable>(),
      );
    });
  });

  group('mapHgfastAccountReason', () {
    test('maps the four known account-state reasons', () {
      expect(mapHgfastAccountReason('banned'), isA<HgfastBanned>());
      expect(mapHgfastAccountReason('expired'), isA<HgfastExpired>());
      expect(mapHgfastAccountReason('quota_exhausted'), isA<HgfastQuotaExhausted>());
      expect(mapHgfastAccountReason('no_group'), isA<HgfastNoGroup>());
    });

    test('returns null for a non-account reason or non-string value', () {
      expect(mapHgfastAccountReason('no_subscription'), isNull);
      expect(mapHgfastAccountReason(null), isNull);
      expect(mapHgfastAccountReason(42), isNull);
    });
  });
}
