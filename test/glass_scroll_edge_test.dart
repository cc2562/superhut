import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:liquid_glass_easy/liquid_glass_easy.dart';
import 'package:superhut/theme/app_theme.dart';
import 'package:superhut/theme/glass/glass_scaffold.dart';
import 'package:superhut/theme/glass/glass_top_bar.dart';

/// 顶栏背后的滚动边缘色带。
///
/// 测试环境没有 shader 资源，所以统一用 `glassTint: 0` 让色带的模糊归零
/// （包会把 `BackdropFilter` 整层摘掉），只验证结构与取色。
void main() {
  ThemeData glassTheme() => AppTheme.fromScheme(
    AppTheme.presetScheme(AppThemePreset.indigo, Brightness.light),
    glassEnabled: true,
    glassTint: 0,
  );

  Widget wrap(Widget child) => MaterialApp(theme: glassTheme(), home: child);

  testWidgets('玻璃模式下顶栏背后叠一层 top 边色带', (tester) async {
    await tester.pumpWidget(
      wrap(
        const GlassScaffold(
          title: '成绩查询',
          body: SizedBox.expand(child: Text('content')),
        ),
      ),
    );
    await tester.pumpAndSettle();

    final band = tester.widget<LiquidGlassScrollEdge>(
      find.byType(LiquidGlassScrollEdge),
    );
    // 测试环境没有状态栏，高度 = 顶栏 56 + 羽化尾巴 24。
    expect(band.edge, LiquidGlassEdge.top);
    expect(band.height, 80);
    expect(band.style, LiquidGlassScrollEdgeStyle.soft);
    // 通透度 0 时模糊太小，直接不生成 filter。
    expect(band.blur, 0);
  });

  testWidgets('色带取页面底色作为峰值颜色', (tester) async {
    const pageColor = Color(0xFF112233);
    await tester.pumpWidget(
      wrap(
        const GlassScaffold(
          title: '电费充值',
          backgroundColor: pageColor,
          body: SizedBox.expand(child: Text('content')),
        ),
      ),
    );
    await tester.pumpAndSettle();

    final band = tester.widget<LiquidGlassScrollEdge>(
      find.byType(LiquidGlassScrollEdge),
    );
    expect(band.color, pageColor.withValues(alpha: 0.98));
  });

  testWidgets('insetBody 页面不叠色带', (tester) async {
    await tester.pumpWidget(
      wrap(
        const GlassScaffold(
          title: 'HUT统一认证',
          insetBody: true,
          body: SizedBox.expand(child: Text('content')),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byType(LiquidGlassScrollEdge), findsNothing);
  });

  testWidgets('showScrollEdge 为 false 时不叠色带', (tester) async {
    await tester.pumpWidget(
      wrap(
        const GlassScaffold(
          title: '',
          showScrollEdge: false,
          body: SizedBox.expand(child: Text('webview')),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byType(LiquidGlassScrollEdge), findsNothing);
  });

  testWidgets('标题不再挂同色光晕', (tester) async {
    await tester.pumpWidget(
      wrap(
        const GlassScaffold(
          title: '关于',
          body: SizedBox.expand(child: Text('content')),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byType(GlassTopBar), findsOneWidget);
    final title = tester.widget<Text>(find.text('关于').first);
    expect(title.style?.shadows, isNull);
  });
}
