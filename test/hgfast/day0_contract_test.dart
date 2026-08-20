import 'dart:convert';
import 'dart:io';

import 'package:fl_clash/common/hg_webview/api.dart';
import 'package:fl_clash/common/navigation.dart';
import 'package:fl_clash/enum/enum.dart';
import 'package:fl_clash/hgfast/models/error.dart';
import 'package:fl_clash/hgfast/models/node.dart';
import 'package:fl_clash/hgfast/repository/repository.dart';
import 'package:fl_clash/hgfast/telemetry/api.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('node contract round-trips locked fields and drops dead keys', () {
    final json = <String, Object?>{
      'name': 'Hong Kong 01',
      'server': 'node.example.com',
      'server_port': 443,
      'password': 'uuid',
      'server_name': 'node.example.com',
      'insecure': false,
      'protocol': 'anytls',
      'region': 'hk',
      'route_label': 'IEPL',
      'rate': 1.5,
      'sort': 10,
      'group_id': 48,
      'category': 'vip',
      'cert_cn': 'node.example.com',
      'route_type': 'direct',
      'padding_scheme': 'ignored',
    };

    final node = NodeSpec.fromJson(json);
    final encoded = node.toJson();

    expect(node.category, NodeCategory.vip);
    expect(node.groupId, '48');
    expect(node.rate, '1.5');
    expect(encoded['route_label'], 'IEPL');
    expect(encoded['cert_cn'], 'node.example.com');
    expect(encoded, isNot(contains('route_type')));
    expect(encoded, isNot(contains('padding_scheme')));
  });

  test('node catalog preserves groups and flattens nodes', () {
    final node = <String, Object?>{
      'name': 'Tokyo 01',
      'server': 'node.example.com',
      'server_port': 443,
      'password': 'uuid',
      'server_name': '',
      'insecure': true,
      'protocol': 'anytls',
      'region': 'jp',
      'route_label': 'BGP',
      'rate': 5,
      'sort': 20,
      'group_id': '48',
      'category': 'standard',
    };
    final catalog = NodeCatalog.fromJson({
      'auto': true,
      'groups': [
        {
          'label': 'Nodes',
          'nodes': [node],
        },
      ],
      'dedicated': null,
    });

    expect(catalog.automatic, isTrue);
    expect(catalog.groups.keys, ['Nodes']);
    expect(catalog.nodes.single.region, 'jp');
    expect(catalog.toJson()['dedicated'], isNull);
  });

  test(
    'malformed node/catalog payloads raise FormatException, not TypeError',
    () {
      final validNode = <String, Object?>{
        'name': 'Tokyo 01',
        'server': 'node.example.com',
        'server_port': 443,
        'password': 'uuid',
        'server_name': '',
        'insecure': true,
        'protocol': 'anytls',
        'region': 'jp',
        'route_label': 'BGP',
        'rate': 5,
        'sort': 20,
        'group_id': '48',
        'category': 'standard',
      };

      // A caller that only catches FormatException must be able to rely on
      // every one of these malformed inputs raising it — a bare `as` cast
      // would instead surface a TypeError or a null-check-operator error,
      // an invisible crash the FormatException contract is meant to rule
      // out. See lib/hgfast/models/node.dart's _optionalBool/_optionalString/
      // _requiredMap helpers.
      expect(
        () => NodeSpec.fromJson({...validNode, 'cert_cn': 42}),
        throwsFormatException,
      );
      expect(
        () => NodeCatalog.fromJson({'auto': 'yes', 'groups': []}),
        throwsFormatException,
      );
      expect(
        () => NodeCatalog.fromJson({
          'auto': true,
          'groups': [
            {
              'label': 'Nodes',
              'nodes': [null],
            },
          ],
        }),
        throwsFormatException,
      );
      expect(
        () => NodeCatalog.fromJson({
          'auto': true,
          'groups': [
            {
              'label': 'Nodes',
              'nodes': ['not a map'],
            },
          ],
        }),
        throwsFormatException,
      );
      expect(
        () => NodeCatalog.fromJson({
          'auto': true,
          'groups': [],
          'dedicated': 'not a map',
        }),
        throwsFormatException,
      );
      // Non-String key in an otherwise well-typed Map<Object?, Object?> —
      // unreachable from jsonDecode (always String-keyed) but reachable
      // from a platform-channel StandardMessageCodec payload, which this
      // same `is Map<Object?, Object?>` check is written to also accept.
      expect(
        () => NodeCatalog.fromJson({
          'auto': true,
          'groups': [
            {
              'label': 'Nodes',
              'nodes': [
                <Object?, Object?>{...validNode, 1: 'bad key'},
              ],
            },
          ],
        }),
        throwsFormatException,
      );
    },
  );

  test('error taxonomy keeps canary resource and access reasons distinct', () {
    const c1 = HgfastError.c1('C1_TimeWindow');
    const canary = HgfastError.canaryDenied(HgfastResource.nodes);
    const errors = <HgfastError>[
      HgfastError.authFailed(),
      HgfastError.registerDisabled(),
      HgfastError.writeDisabled(),
      HgfastError.writeNotImplemented(),
      HgfastError.badPlanId(),
      HgfastError.lotteryDisabled(),
      HgfastError.clientApiStateUnavailable(),
      HgfastError.pinMismatch(),
      HgfastError.banned(),
      HgfastError.expired(),
      HgfastError.quotaExhausted(),
      HgfastError.noGroup(),
    ];

    expect(c1.code, 'C1_TimeWindow');
    expect(canary, isA<HgfastCanaryDenied>());
    expect((canary as HgfastCanaryDenied).resource, HgfastResource.nodes);
    expect(errors.map((error) => error.code).toSet(), {
      'AUTH_FAILED',
      'REGISTER_DISABLED',
      'WRITE_DISABLED',
      'WRITE_NOT_IMPLEMENTED',
      'BAD_PLAN_ID',
      'LOTTERY_DISABLED',
      'CLIENT_API_STATE_UNAVAILABLE',
      'PIN_MISMATCH',
      'banned',
      'expired',
      'quota_exhausted',
      'no_group',
    });
  });

  test(
    'result, webview, and telemetry APIs expose locked signatures',
    () async {
      const result = HgfastResult<int, HgfastError>.success(1);
      final webview = _Webview();
      final policy = _Policy();
      final spec = HgWebviewSpec(
        initialUri: Uri.parse('https://hgfastapp.com'),
        dataStoreId: 'support',
        navigationPolicy: policy,
        bridgePayload: const BridgePayload(
          token: 'bridge-token',
          data: {'connected': true},
        ),
      );
      final telemetry = _Telemetry();

      await webview.open(spec);
      await webview.postMessage(spec.bridgePayload!);
      hgTelemetry = telemetry;
      hgTelemetry.log('session_start', {'platform': 'test'});

      expect(result.isSuccess, isTrue);
      expect(webview.opened, same(spec));
      expect(webview.posted, same(spec.bridgePayload));
      expect(
        policy.evaluate(
          NavigationRequest(
            uri: spec.initialUri,
            isMainFrame: true,
            isFirstNavigation: true,
          ),
        ),
        NavigationDecision.allow,
      );
      expect(telemetry.events.single.$1, 'session_start');
    },
  );

  test('repository exposes concrete results for all locked methods', () async {
    final repository = _Repository();

    expect(
      (await repository.login(
        credential: 'user',
        password: 'password',
      )).isSuccess,
      isTrue,
    );
    expect((await repository.logout()).isSuccess, isTrue);
    expect((await repository.restoreSession()).isSuccess, isTrue);
    expect((await repository.bootstrap()).isSuccess, isTrue);
    expect((await repository.config()).isSuccess, isTrue);
    expect((await repository.announcements()).isSuccess, isTrue);
    expect((await repository.plans()).isSuccess, isTrue);
    expect((await repository.nodes()).isSuccess, isTrue);
    expect((await repository.subscription()).isSuccess, isTrue);
    expect((await repository.traffic()).isSuccess, isTrue);
    expect((await repository.invite()).isSuccess, isTrue);
    expect((await repository.lotteryStatus()).isSuccess, isTrue);
    expect((await repository.aiChat(message: 'hello')).isSuccess, isTrue);
    expect((await repository.orderStatus('order-1')).isSuccess, isTrue);
  });

  test('navigation reserves seven HGFAST slots with explicit retention', () {
    final items = navigation.getItems();
    final enabledItems = navigation.getItems(enableHgfast: true);
    const labels = {
      PageLabel.connect,
      PageLabel.discover,
      PageLabel.support,
      PageLabel.account,
      PageLabel.vip,
      PageLabel.plans,
      PageLabel.docs,
    };
    final slots = items.where((item) => labels.contains(item.label)).toList();
    final enabledSlots = enabledItems
        .where((item) => labels.contains(item.label))
        .toList();

    expect(slots.map((item) => item.label).toSet(), labels);
    expect(slots.every((item) => item.keep == false), isTrue);
    expect(slots.every((item) => item.path != null), isTrue);
    expect(slots.every((item) => item.modes.isEmpty), isTrue);
    // support is desktop-only as of the "更多"-drawer redesign (mobile
    // reaches it via the Connect access-gate's contact-support CTA, which
    // pushes it directly instead of switching tabs — see
    // CurrentPageLabel.toPage) — connect/discover/account are still the
    // three labels every mode must carry.
    expect(
      enabledSlots
          .where(
            (item) => {
              PageLabel.connect,
              PageLabel.discover,
              PageLabel.account,
            }.contains(item.label),
          )
          .every(
            (item) => item.modes.toSet().containsAll([
              NavigationItemMode.mobile,
              NavigationItemMode.desktop,
            ]),
          ),
      isTrue,
    );
    expect(
      enabledSlots
          .firstWhere((item) => item.label == PageLabel.support)
          .modes,
      [NavigationItemMode.desktop],
    );
  });

  test('all four locales contain the seven HGFAST label keys', () {
    const keys = {
      'connect',
      'discover',
      'support',
      'account',
      'vip',
      'plans',
      'docs',
    };
    for (final locale in ['en', 'ja', 'ru', 'zh_CN']) {
      final content =
          jsonDecode(File('arb/intl_$locale.arb').readAsStringSync())
              as Map<String, Object?>;
      expect(content.keys.toSet(), containsAll(keys));
    }
  });
}

final class _Policy implements NavigationPolicy {
  @override
  NavigationDecision evaluate(NavigationRequest request) {
    return NavigationDecision.allow;
  }
}

final class _Webview implements HgWebview {
  HgWebviewSpec? opened;
  BridgePayload? posted;

  @override
  Future<void> open(HgWebviewSpec spec) async {
    opened = spec;
  }

  @override
  Future<void> postMessage(BridgePayload payload) async {
    posted = payload;
  }
}

final class _Telemetry implements HgTelemetry {
  final List<(String, Map<String, Object?>)> events = [];

  @override
  void log(String eventName, Map<String, Object?> props) {
    events.add((eventName, props));
  }
}

final class _Repository implements HgfastRepository {
  @override
  Future<HgfastResult<HgfastSession, HgfastError>> login({
    required String credential,
    required String password,
  }) async {
    return HgfastResult.success(HgfastSession({}));
  }

  @override
  Future<HgfastResult<void, HgfastError>> logout() async {
    return const HgfastResult.success(null);
  }

  @override
  Future<HgfastResult<HgfastSession?, HgfastError>> restoreSession() async {
    return HgfastResult.success(HgfastSession({}));
  }

  @override
  Future<HgfastResult<HgfastBootstrap, HgfastError>> bootstrap() async {
    return HgfastResult.success(HgfastBootstrap({}));
  }

  @override
  Future<HgfastResult<HgfastConfig, HgfastError>> config() async {
    return HgfastResult.success(HgfastConfig({}));
  }

  @override
  Future<HgfastResult<HgfastAnnouncementCatalog, HgfastError>> announcements() async {
    return HgfastResult.success(HgfastAnnouncementCatalog({}));
  }

  @override
  Future<HgfastResult<HgfastPlanCatalog, HgfastError>> plans() async {
    return HgfastResult.success(HgfastPlanCatalog({}));
  }

  @override
  Future<HgfastResult<NodeCatalog, HgfastError>> nodes() async {
    return HgfastResult.success(NodeCatalog(automatic: true, groups: {}));
  }

  @override
  Future<HgfastResult<HgfastSubscription, HgfastError>> subscription() async {
    return HgfastResult.success(HgfastSubscription({}));
  }

  @override
  Future<HgfastResult<HgfastTraffic, HgfastError>> traffic() async {
    return HgfastResult.success(HgfastTraffic({}));
  }

  @override
  Future<HgfastResult<HgfastInvite, HgfastError>> invite() async {
    return HgfastResult.success(HgfastInvite({}));
  }

  @override
  Future<HgfastResult<HgfastLotteryStatus, HgfastError>> lotteryStatus() async {
    return HgfastResult.success(HgfastLotteryStatus({}));
  }

  @override
  Future<HgfastResult<HgfastAiResponse, HgfastError>> aiChat({
    required String message,
    String? model,
    HgfastJson? context,
  }) async {
    return HgfastResult.success(HgfastAiResponse({}));
  }

  @override
  Future<HgfastResult<HgfastOrderStatus, HgfastError>> orderStatus(
    String orderId,
  ) async {
    return HgfastResult.success(HgfastOrderStatus({}));
  }

  @override
  Future<HgfastResult<HgfastOrderStatus, HgfastError>> createOrder({
    required String planId,
    required String period,
    String? couponCode,
  }) async {
    return HgfastResult.success(HgfastOrderStatus({}));
  }
  @override
  Future<HgfastResult<HgfastJson, HgfastError>> requestPasswordReset({
    required String email,
  }) async {
    return const HgfastResult.success(<String, Object?>{});
  }

  @override
  Future<HgfastResult<HgfastJson, HgfastError>> confirmPasswordReset({
    required String email,
    required String code,
    required String newPassword,
  }) async {
    return const HgfastResult.success(<String, Object?>{});
  }
}
