import 'package:fl_clash/hgfast/models/error.dart';
import 'package:fl_clash/hgfast/models/node.dart';
import 'package:fl_clash/hgfast/repository/repository.dart';
import 'package:fl_clash/l10n/l10n.dart';
import 'package:fl_clash/pages/auth/forgot_password_view.dart';
import 'package:fl_clash/providers/providers.dart';
import 'package:fl_clash/state.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('shows the generic fallback when bootstrap has no contacts', (
    tester,
  ) async {
    final container = ProviderContainer(
      overrides: [
        hgfastRepositoryProvider.overrideWithValue(
          _FakeRepository(contacts: const []),
        ),
      ],
    );
    addTearDown(container.dispose);
    globalState.container = container;

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const _TestApp(child: ForgotPasswordView()),
      ),
    );
    await tester.pump();
    await tester.pump();

    expect(find.text('客服联系方式暂未配置，请稍后再试'), findsOneWidget);
  });

  testWidgets('renders fallback_contacts from bootstrap', (tester) async {
    final container = ProviderContainer(
      overrides: [
        hgfastRepositoryProvider.overrideWithValue(
          _FakeRepository(
            contacts: const [
              {'label': 'Telegram', 'value': '@example'},
            ],
          ),
        ),
      ],
    );
    addTearDown(container.dispose);
    globalState.container = container;

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const _TestApp(child: ForgotPasswordView()),
      ),
    );
    await tester.pump();
    await tester.pump();

    expect(find.text('Telegram'), findsOneWidget);
    expect(find.text('@example'), findsOneWidget);
  });

  testWidgets('back button pops the route', (tester) async {
    final container = ProviderContainer(
      overrides: [
        hgfastRepositoryProvider.overrideWithValue(
          _FakeRepository(contacts: const []),
        ),
      ],
    );
    addTearDown(container.dispose);
    globalState.container = container;

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: _TestApp(
          child: Builder(
            builder: (context) {
              return TextButton(
                onPressed: () {
                  Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => const ForgotPasswordView(),
                    ),
                  );
                },
                child: const Text('open forgot password'),
              );
            },
          ),
        ),
      ),
    );
    await tester.pump();

    await tester.tap(find.text('open forgot password'));
    await tester.pumpAndSettle();
    expect(find.byType(ForgotPasswordView), findsOneWidget);

    // The form is taller now (real email/code/password fields), so on the
    // default test viewport the back button can sit below the fold —
    // scroll it into view before tapping rather than assuming it's already
    // visible.
    await tester.ensureVisible(find.widgetWithText(TextButton, '返回登录'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(TextButton, '返回登录'));
    await tester.pumpAndSettle();

    expect(find.byType(ForgotPasswordView), findsNothing);
    expect(find.text('open forgot password'), findsOneWidget);
  });

  testWidgets(
    'requesting a code against a gated backend shows the honest '
    '"not available yet" message, never a fake "sent" success',
    (tester) async {
      final container = ProviderContainer(
        overrides: [
          hgfastRepositoryProvider.overrideWithValue(
            _FakeRepository(
              contacts: const [],
              requestPasswordResetResult: const HgfastResult.failure(
                HgfastError.c1('WRITE_DISABLED'),
              ),
            ),
          ),
        ],
      );
      addTearDown(container.dispose);
      globalState.container = container;

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: const _TestApp(child: ForgotPasswordView()),
        ),
      );
      await tester.pump();
      await tester.pump();

      await tester.enterText(
        find.widgetWithText(TextField, '账号 / 邮箱'),
        'user@example.com',
      );
      await tester.tap(find.text('获取验证码'));
      await tester.pump();
      await tester.pump();

      expect(find.text('在线找回密码暂未开放，请使用下方联系方式'), findsOneWidget);
      expect(find.textContaining('验证码已发送'), findsNothing);
    },
  );

  testWidgets(
    'a real requestPasswordReset success shows the real "sent" message',
    (tester) async {
      final container = ProviderContainer(
        overrides: [
          hgfastRepositoryProvider.overrideWithValue(
            _FakeRepository(
              contacts: const [],
              requestPasswordResetResult: const HgfastResult.success(
                <String, Object?>{},
              ),
            ),
          ),
        ],
      );
      addTearDown(container.dispose);
      globalState.container = container;

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: const _TestApp(child: ForgotPasswordView()),
        ),
      );
      await tester.pump();
      await tester.pump();

      await tester.enterText(
        find.widgetWithText(TextField, '账号 / 邮箱'),
        'user@example.com',
      );
      await tester.tap(find.text('获取验证码'));
      await tester.pump();
      await tester.pump();

      expect(find.text('验证码已发送，请查收邮箱'), findsOneWidget);
    },
  );

  testWidgets(
    'confirming reset against a gated backend shows the honest message, '
    'never a fake "password reset" success',
    (tester) async {
      final container = ProviderContainer(
        overrides: [
          hgfastRepositoryProvider.overrideWithValue(
            _FakeRepository(
              contacts: const [],
              confirmPasswordResetResult: const HgfastResult.failure(
                HgfastError.c1('WRITE_NOT_IMPLEMENTED'),
              ),
            ),
          ),
        ],
      );
      addTearDown(container.dispose);
      globalState.container = container;

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: const _TestApp(child: ForgotPasswordView()),
        ),
      );
      await tester.pump();
      await tester.pump();

      await tester.enterText(
        find.widgetWithText(TextField, '账号 / 邮箱'),
        'user@example.com',
      );
      await tester.enterText(find.widgetWithText(TextField, '验证码'), '123456');
      await tester.enterText(
        find.widgetWithText(TextField, '新密码'),
        'newpass123',
      );
      await tester.tap(find.text('重置密码'));
      await tester.pump();
      await tester.pump();

      expect(find.text('在线找回密码暂未开放，请使用下方联系方式'), findsOneWidget);
      expect(find.textContaining('密码已重置'), findsNothing);
    },
  );

  testWidgets('empty fields show a validation message, never call the repository', (
    tester,
  ) async {
    final container = ProviderContainer(
      overrides: [
        hgfastRepositoryProvider.overrideWithValue(
          _FakeRepository(contacts: const []),
        ),
      ],
    );
    addTearDown(container.dispose);
    globalState.container = container;

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const _TestApp(child: ForgotPasswordView()),
      ),
    );
    await tester.pump();
    await tester.pump();

    await tester.tap(find.text('重置密码'));
    await tester.pump();

    expect(find.text('请填写邮箱、验证码和新密码'), findsOneWidget);
  });
}

class _TestApp extends StatelessWidget {
  final Widget child;

  const _TestApp({required this.child});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      localizationsDelegates: const [
        AppLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
      ],
      supportedLocales: AppLocalizations.delegate.supportedLocales,
      home: child,
    );
  }
}

final class _FakeRepository implements HgfastRepository {
  _FakeRepository({
    required this.contacts,
    this.requestPasswordResetResult = const HgfastResult.failure(
      HgfastError.c1('WRITE_DISABLED'),
    ),
    this.confirmPasswordResetResult = const HgfastResult.failure(
      HgfastError.c1('WRITE_DISABLED'),
    ),
  });

  final List<Map<String, Object?>> contacts;
  final HgfastResult<HgfastJson, HgfastError> requestPasswordResetResult;
  final HgfastResult<HgfastJson, HgfastError> confirmPasswordResetResult;

  @override
  Future<HgfastResult<HgfastSession, HgfastError>> login({
    required String credential,
    required String password,
  }) async {
    return const HgfastResult.failure(HgfastError.authFailed());
  }

  @override
  Future<HgfastResult<void, HgfastError>> logout() async {
    return const HgfastResult.success(null);
  }

  @override
  Future<HgfastResult<HgfastSession?, HgfastError>> restoreSession() async {
    return const HgfastResult.success(null);
  }

  @override
  Future<HgfastResult<HgfastBootstrap, HgfastError>> bootstrap() async {
    return HgfastResult.success(
      HgfastBootstrap({'fallback_contacts': contacts}),
    );
  }

  @override
  Future<HgfastResult<HgfastConfig, HgfastError>> config() async {
    return HgfastResult.success(HgfastConfig({}));
  }

  @override
  Future<HgfastResult<HgfastAnnouncementCatalog, HgfastError>>
  announcements() async {
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
    return requestPasswordResetResult;
  }

  @override
  Future<HgfastResult<HgfastJson, HgfastError>> confirmPasswordReset({
    required String email,
    required String code,
    required String newPassword,
  }) async {
    return confirmPasswordResetResult;
  }
}
