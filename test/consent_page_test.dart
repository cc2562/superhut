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

  testWidgets('两项都不勾时按钮禁用；只勾协议即可继续，且不上报行为分析同意', (tester) async {
    int accepted = 0;
    int exited = 0;
    bool? reportedAnalytics;

    await tester.pumpWidget(
      MaterialApp(
        home: AgreementConsentPage(
          onAccept: (
            BuildContext context, {
            required bool analyticsConsent,
          }) async {
            accepted++;
            reportedAnalytics = analyticsConsent;
          },
          onExit: () async => exited++,
        ),
      ),
    );

    final Finder agreeButton = find.widgetWithText(FilledButton, '同意并继续');
    expect(tester.widget<FilledButton>(agreeButton).onPressed, isNull);

    // 只勾第一项（协议必选）。
    await tester.tap(find.text('我已阅读并同意'));
    await tester.pump();
    expect(tester.widget<FilledButton>(agreeButton).onPressed, isNotNull);

    await tester.tap(agreeButton);
    await tester.pump();
    expect(accepted, 1);
    expect(reportedAnalytics, isFalse);

    await tester.tap(find.text('不同意，退出应用'));
    await tester.pump();
    expect(exited, 1);
  });

  testWidgets('单独勾选行为分析后才上报 true', (tester) async {
    bool? reportedAnalytics;

    await tester.pumpWidget(
      MaterialApp(
        home: AgreementConsentPage(
          onAccept: (
            BuildContext context, {
            required bool analyticsConsent,
          }) async {
            reportedAnalytics = analyticsConsent;
          },
          onExit: () async {},
        ),
      ),
    );

    await tester.tap(find.text('我已阅读并同意'));
    await tester.tap(find.text('我同意将使用行为数据用于产品改进'));
    await tester.pump();

    await tester.tap(find.widgetWithText(FilledButton, '同意并继续'));
    await tester.pump();

    expect(reportedAnalytics, isTrue);
  });

  testWidgets('同意页可以直接打开两份协议', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: AgreementConsentPage(
          onAccept:
              (BuildContext context, {required bool analyticsConsent}) async {},
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
