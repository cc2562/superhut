import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:liquid_glass_easy/liquid_glass_easy.dart';
import 'package:superhut/theme/app_theme.dart';
import 'package:superhut/theme/glass/glass_menu.dart';
import 'package:superhut/theme/glass/glass_search_bar.dart';
import 'package:superhut/theme/glass/glass_top_bar.dart';

/// 功能层玻璃的触摸手感（`LiquidGlassLens.touch`）。
///
/// 只断言「接上了正确的档位」，具体的形变曲线由包负责；测试环境没有
/// shader，所以用 `glassTint: 0` 让模糊归零，避免多余的 backdrop pass。
void main() {
  ThemeData theme({required bool glassEnabled}) => AppTheme.fromScheme(
    AppTheme.presetScheme(AppThemePreset.indigo, Brightness.light),
    glassEnabled: glassEnabled,
    glassTint: 0,
  );

  Widget wrap(Widget child, {bool glassEnabled = true}) => MaterialApp(
    theme: theme(glassEnabled: glassEnabled),
    home: Scaffold(body: Center(child: child)),
  );

  /// 取树里第一枚镜片的触摸配置里「沿拉伸方向的峰值伸长量」。
  double? stretchOf(WidgetTester tester) {
    final lens = tester.widget<LiquidGlassLens>(find.byType(LiquidGlassLens));
    return lens.touch?.flex?.stretch;
  }

  testWidgets('返回圆钮接上 button 档手感', (tester) async {
    await tester.pumpWidget(
      wrap(
        const GlassControlButton(
          icon: Icons.arrow_back_ios_new_rounded,
          semanticLabel: '返回',
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byType(LiquidGlassLens), findsOneWidget);
    expect(stretchOf(tester), 6);
  });

  testWidgets('右侧操作组与返回钮同档', (tester) async {
    await tester.pumpWidget(
      wrap(
        GlassActionGroup(
          actions: [
            GlassActionButton(icon: Icons.refresh, onPressed: () {}),
            GlassActionButton(icon: Icons.more_horiz, onPressed: () {}),
          ],
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byType(LiquidGlassLens), findsOneWidget);
    expect(stretchOf(tester), 6);
  });

  testWidgets('搜索栏用横轴锁定的 field 档', (tester) async {
    await tester.pumpWidget(
      wrap(GlassSearchBar(controller: TextEditingController())),
    );
    await tester.pumpAndSettle();

    final lens = tester.widget<LiquidGlassLens>(find.byType(LiquidGlassLens));
    expect(lens.touch?.flex?.stretch, 9);
    expect(lens.touch?.flex?.lockAxis, Axis.horizontal);
  });

  testWidgets('弹出菜单面板接上 panel 档手感', (tester) async {
    await tester.pumpWidget(
      wrap(
        Builder(
          builder:
              (context) => TextButton(
                onPressed:
                    () => showGlassMenu<String>(
                      context: context,
                      anchor: const Rect.fromLTWH(20, 120, 120, 44),
                      items: const [
                        GlassMenuItem(value: 'a', label: '第一项'),
                        GlassMenuItem(value: 'b', label: '第二项'),
                      ],
                    ),
                child: const Text('打开菜单'),
              ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('打开菜单'));
    await tester.pumpAndSettle();

    expect(find.text('第一项'), findsOneWidget);
    final lens = tester.widget<LiquidGlassLens>(find.byType(LiquidGlassLens));
    expect(lens.touch?.flex?.stretch, 5);
  });

  testWidgets('玻璃关闭时不申请手感（零 listener / 零 ticker）', (tester) async {
    await tester.pumpWidget(
      wrap(
        const GlassControlButton(
          icon: Icons.arrow_back_ios_new_rounded,
          semanticLabel: '返回',
        ),
        glassEnabled: false,
      ),
    );
    await tester.pumpAndSettle();

    final lens = tester.widget<LiquidGlassLens>(find.byType(LiquidGlassLens));
    expect(lens.touch, isNull);
  });
}
