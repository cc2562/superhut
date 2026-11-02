import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:superhut/agreement/agreement_controller.dart';
import 'package:superhut/agreement/agreement_documents.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues(<String, Object>{});
  });

  test('从未同意过时视为未同意', () async {
    final AgreementController controller = AgreementController();
    await controller.load();

    expect(controller.accepted, isFalse);
    expect(controller.acceptedVersion, isEmpty);
  });

  test('同意后按当前协议版本落盘，重新读取仍为已同意', () async {
    final AgreementController controller = AgreementController();
    await controller.load();
    await controller.accept();

    expect(controller.accepted, isTrue);
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    expect(
      prefs.getString('agreement.acceptedVersion'),
      AgreementDocuments.version,
    );

    final AgreementController restored = AgreementController();
    await restored.load();
    expect(restored.accepted, isTrue);
  });

  test('存的是旧版本号时要求重新同意', () async {
    SharedPreferences.setMockInitialValues(<String, Object>{
      'agreement.acceptedVersion': '2025-12-20',
    });

    final AgreementController controller = AgreementController();
    await controller.load();

    expect(controller.accepted, isFalse);
    expect(controller.acceptedVersion, '2025-12-20');
  });

  test('撤销同意后回到未同意并清除记录', () async {
    final AgreementController controller = AgreementController();
    await controller.load();
    await controller.accept();

    await controller.revoke();

    expect(controller.accepted, isFalse);
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    expect(prefs.getString('agreement.acceptedVersion'), isNull);
  });
}
