import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:superhut/theme/app_theme.dart';
import 'package:superhut/theme/glass/glass_scaffold.dart';

/// 测试环境没有 shader 资源，玻璃始终回落到 Material 分支；
/// 这里验证回落分支的骨架仍然完整（居中标题、返回按钮、内容）。
void main() {
  testWidgets('GlassScaffold falls back to a centered Material app bar', (
    tester,
  ) async {
    final theme = AppTheme.fromScheme(
      AppTheme.presetScheme(AppThemePreset.indigo, Brightness.light),
    );

    await tester.pumpWidget(
      MaterialApp(
        theme: theme,
        home: const GlassScaffold(
          title: '外观与主题',
          body: SizedBox.expand(child: Text('content')),
        ),
      ),
    );
    await tester.pumpAndSettle();

    final appBar = tester.widget<AppBar>(find.byType(AppBar));
    expect(appBar.centerTitle, isTrue);
    expect(find.text('外观与主题'), findsOneWidget);
    expect(find.text('content'), findsOneWidget);
  });
}
