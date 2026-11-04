import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:superhut/agreement/agreement_controller.dart';
import 'package:superhut/pages/settings/privacy_settings_page.dart';
import 'package:superhut/privacy/analytics_recorder.dart';
import 'package:superhut/privacy/privacy_consent_controller.dart';
import 'package:superhut/theme/theme_controller.dart';

class _FakeRecorder implements AnalyticsRecorder {
  int enableCalls = 0;
  int withdrawCalls = 0;

  @override
  Future<void> enable(BuildContext context) async {
    enableCalls++;
  }

  @override
  Future<void> withdraw() async {
    withdrawCalls++;
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() async {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    await Get.deleteAll(force: true);
  });

  tearDown(() async {
    await Get.deleteAll(force: true);
  });

  testWidgets('开启调用 enable；关闭需确认后才调用 withdraw', (tester) async {
    await tester.binding.setSurfaceSize(const Size(800, 1400));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    final AgreementController agreement = Get.put(AgreementController());
    await agreement.accept();
    final PrivacyConsentController consentController = Get.put(
      PrivacyConsentController(agreement: agreement),
    );
    await consentController.load();
    final ThemeController themeController = Get.put(ThemeController());
    await themeController.load();

    final _FakeRecorder recorder = _FakeRecorder();
    await tester.pumpWidget(
      MaterialApp(
        theme: themeController.lightTheme,
        home: PrivacySettingsPage(recorder: recorder),
      ),
    );
    await tester.pumpAndSettle();

    expect(consentController.analyticsConsent, isFalse);

    // 整行可点：点副标题也能切换开关。
    await tester.tap(find.text('Microsoft Clarity · 友盟+ 统计与性能监控'));
    await tester.pumpAndSettle();
    expect(consentController.analyticsConsent, isTrue);
    expect(recorder.enableCalls, 1);

    // 关闭会弹确认框；选择保持开启则不改状态、不撤回。
    await tester.tap(find.byType(Switch));
    await tester.pumpAndSettle();
    expect(find.text('关闭使用体验分析？'), findsOneWidget);
    await tester.tap(find.text('保持开启'));
    await tester.pumpAndSettle();
    expect(consentController.analyticsConsent, isTrue);
    expect(recorder.withdrawCalls, 0);

    // 确认后立即停止采集。
    await tester.tap(find.byType(Switch));
    await tester.pumpAndSettle();
    await tester.tap(find.text('仍要关闭'));
    await tester.pumpAndSettle();
    expect(consentController.analyticsConsent, isFalse);
    expect(recorder.withdrawCalls, 1);
  });

  testWidgets('页内提供两份协议入口', (tester) async {
    await tester.binding.setSurfaceSize(const Size(800, 1400));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    final AgreementController agreement = Get.put(AgreementController());
    await agreement.accept();
    Get.put(PrivacyConsentController(agreement: agreement));
    final ThemeController themeController = Get.put(ThemeController());
    await themeController.load();

    await tester.pumpWidget(
      MaterialApp(
        theme: themeController.lightTheme,
        home: PrivacySettingsPage(recorder: _FakeRecorder()),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('《用户协议》'), findsOneWidget);
    expect(find.text('《隐私政策》'), findsOneWidget);
  });
}
