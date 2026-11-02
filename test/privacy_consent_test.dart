import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:superhut/agreement/agreement_controller.dart';
import 'package:superhut/privacy/privacy_consent_controller.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues(<String, Object>{});
  });

  test('只同意协议、未勾选行为分析时不采集', () async {
    final AgreementController agreement = AgreementController();
    await agreement.accept();

    final PrivacyConsentController controller = PrivacyConsentController(
      agreement: agreement,
    );
    await controller.load();

    expect(agreement.accepted, isTrue);
    expect(controller.analyticsConsent, isFalse);
    // 协议同意 ≠ 行为分析同意。
    expect(controller.analyticsAllowed, isFalse);
  });

  test('勾选行为分析后落盘，重启后仍然生效', () async {
    final AgreementController agreement = AgreementController();
    await agreement.accept();
    final PrivacyConsentController controller = PrivacyConsentController(
      agreement: agreement,
    );
    await controller.load();

    await controller.setAnalyticsConsent(true);
    expect(controller.analyticsConsent, isTrue);
    expect(controller.analyticsAllowed, isTrue);
    expect(controller.updatedAt, isNotEmpty);

    final SharedPreferences prefs = await SharedPreferences.getInstance();
    expect(
      prefs.getBool(PrivacyConsentController.consentKey),
      isTrue,
      reason: '开关必须落盘，否则下次启动会静默恢复采集',
    );
    expect(prefs.getString(PrivacyConsentController.updatedAtKey), isNotEmpty);

    // 新实例模拟冷启动。
    final PrivacyConsentController restored = PrivacyConsentController(
      agreement: agreement,
    );
    await restored.load();
    expect(restored.analyticsConsent, isTrue);
    expect(restored.analyticsAllowed, isTrue);
  });

  test('撤回后停止采集并落盘', () async {
    final AgreementController agreement = AgreementController();
    await agreement.accept();
    final PrivacyConsentController controller = PrivacyConsentController(
      agreement: agreement,
    );
    await controller.load();
    await controller.setAnalyticsConsent(true);

    await controller.setAnalyticsConsent(false);

    expect(controller.analyticsAllowed, isFalse);
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    expect(prefs.getBool(PrivacyConsentController.consentKey), isFalse);
  });

  test('协议未同意时即使勾了开关也不采集', () async {
    final AgreementController agreement = AgreementController();
    final PrivacyConsentController controller = PrivacyConsentController(
      agreement: agreement,
    );
    await controller.load();
    await controller.setAnalyticsConsent(true);

    expect(controller.analyticsConsent, isTrue);
    expect(controller.analyticsAllowed, isFalse);
  });
}
