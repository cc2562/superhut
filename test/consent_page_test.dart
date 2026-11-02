import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:superhut/agreement/agreement_page.dart';
import 'package:superhut/agreement/consent_page.dart';
import 'package:superhut/analytics/clarity_service.dart';

void main() {
  test('测试环境 / 非移动平台不启动 Clarity', () {
    // `flutter test` 会设置 FLUTTER_TEST=true，ClarityService 必须据此短路，
    // 否则会抛 MissingPluginException 污染所有 widget 测试。
    expect(ClarityService.isSupportedPlatform, isFalse);
    // 项目 ID 写死成常量，防止后续误改成占位值。
    expect(ClarityService.projectId, 's1q3qmd7zu');
  });

  testWidgets('未勾选时按钮禁用，勾选后可同意，不同意走回调', (tester) async {
    int accepted = 0;
    int exited = 0;

    await tester.pumpWidget(
      MaterialApp(
        home: AgreementConsentPage(
          onAccept: (BuildContext context) async => accepted++,
          onExit: () async => exited++,
        ),
      ),
    );

    final Finder agreeButton = find.widgetWithText(FilledButton, '同意并继续');
    expect(tester.widget<FilledButton>(agreeButton).onPressed, isNull);

    // 点文案也能切换勾选（命中区域更大）。
    await tester.tap(find.text('我已阅读并同意'));
    await tester.pump();
    expect(tester.widget<FilledButton>(agreeButton).onPressed, isNotNull);

    await tester.tap(agreeButton);
    await tester.pump();
    expect(accepted, 1);

    await tester.tap(find.text('不同意，退出应用'));
    await tester.pump();
    expect(exited, 1);
  });

  testWidgets('同意页可以直接打开两份协议', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: AgreementConsentPage(
          onAccept: (BuildContext context) async {},
          onExit: () async {},
        ),
      ),
    );

    // 协议名在「卡片列表」与「勾选行」各出现一次，取第一个即可。
    await tester.tap(find.text('《用户协议》').first);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));

    expect(find.byType(AgreementPage), findsOneWidget);
  });
}
