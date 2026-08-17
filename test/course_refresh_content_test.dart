import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:superhut/bridge/getCoursePage.dart';

Widget _buildFailurePage({required bool isRenew}) {
  return MaterialApp(
    home: Scaffold(
      body: CourseRefreshContent(
        state: CourseRefreshViewState.failure,
        progress: 0,
        isRenew: isRenew,
      ),
    ),
  );
}

void main() {
  testWidgets('first refresh failure only offers retry', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(_buildFailurePage(isRenew: false));

    expect(find.text('重新尝试'), findsOneWidget);
    expect(find.text('返回'), findsNothing);
    expect(find.text('请检查网络后重试'), findsOneWidget);
  });

  testWidgets('manual refresh failure still offers return', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(_buildFailurePage(isRenew: true));

    expect(find.text('重新尝试'), findsOneWidget);
    expect(find.text('返回'), findsOneWidget);
  });
}
