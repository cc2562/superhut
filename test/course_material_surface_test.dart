import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:liquid_glass_easy/liquid_glass_easy.dart';
import 'package:superhut/home/coursetable/style/course_card_surface.dart';
import 'package:superhut/home/coursetable/style/course_table_style.dart';
import 'package:superhut/theme/app_theme.dart';

/// 课表页通用表面的材质行为：纯色 / 毛玻璃 / 液态玻璃（含降级）。
///
/// 测试环境没有 shader，玻璃主题统一用 `glassTint: 0` 把模糊归零，
/// 断言只看结构，不看具体像素。
void main() {
  const Color base = Color(0xFFD0BCFF);

  ThemeData theme({required bool glassEnabled}) => AppTheme.fromScheme(
    AppTheme.presetScheme(AppThemePreset.indigo, Brightness.light),
    glassEnabled: glassEnabled,
    glassTint: 0,
  );

  Widget wrap(Widget child, {bool glassEnabled = false}) => MaterialApp(
    theme: theme(glassEnabled: glassEnabled),
    home: Scaffold(body: Center(child: child)),
  );

  Widget surface(CourseTableStyle style, {double borderRadius = 12}) =>
      CourseMaterialSurface(
        tint: style.surfaceTint(base),
        style: style,
        borderRadius: borderRadius,
        child: const SizedBox(width: 80, height: 40),
      );

  /// 只查看表面内部的图层，避免把 Scaffold / Material 的实现细节算进来。
  Finder inSurface(Finder matching) => find.descendant(
    of: find.byType(CourseMaterialSurface),
    matching: matching,
  );

  testWidgets('纯色材质画一层底色并使用给定圆角', (tester) async {
    const CourseTableStyle style = CourseTableStyle(cardOpacity: 1);
    await tester.pumpWidget(wrap(surface(style)));

    final Finder box = inSurface(find.byType(DecoratedBox));
    expect(box, findsOneWidget);
    final BoxDecoration decoration =
        tester.widget<DecoratedBox>(box).decoration as BoxDecoration;
    expect(decoration.color, base.withValues(alpha: 1));
    expect(decoration.borderRadius, BorderRadius.circular(12));
    expect(inSurface(find.byType(BackdropFilter)), findsNothing);
  });

  testWidgets('纯色且不透明度为 0 时只保留 child，不创建任何图层', (tester) async {
    const CourseTableStyle style = CourseTableStyle(cardOpacity: 0);
    await tester.pumpWidget(wrap(surface(style)));

    expect(inSurface(find.byType(DecoratedBox)), findsNothing);
    expect(inSurface(find.byType(BackdropFilter)), findsNothing);
    expect(find.byType(SizedBox), findsWidgets);
  });

  testWidgets('毛玻璃材质构建 BackdropFilter', (tester) async {
    const CourseTableStyle style = CourseTableStyle(
      material: CourseCardMaterial.frosted,
      cardBlur: 12,
    );
    await tester.pumpWidget(wrap(surface(style)));

    expect(inSurface(find.byType(BackdropFilter)), findsOneWidget);
    expect(inSurface(find.byType(DecoratedBox)), findsOneWidget);
  });

  testWidgets('毛玻璃模糊为 0 时跳过 BackdropFilter', (tester) async {
    const CourseTableStyle style = CourseTableStyle(
      material: CourseCardMaterial.frosted,
      cardBlur: 0,
    );
    await tester.pumpWidget(wrap(surface(style)));

    expect(inSurface(find.byType(BackdropFilter)), findsNothing);
    // 底色仍然存在，只是没有模糊。
    expect(inSurface(find.byType(DecoratedBox)), findsOneWidget);
  });

  testWidgets('液态玻璃在玻璃外观关闭时降级为毛玻璃', (tester) async {
    const CourseTableStyle style = CourseTableStyle(
      material: CourseCardMaterial.liquidGlass,
      cardBlur: 12,
    );
    await tester.pumpWidget(wrap(surface(style), glassEnabled: false));

    expect(inSurface(find.byType(LiquidGlassLens)), findsNothing);
    expect(inSurface(find.byType(BackdropFilter)), findsOneWidget);
  });

  testWidgets('液态玻璃在玻璃外观开启时走折射镜片', (tester) async {
    const CourseTableStyle style = CourseTableStyle(
      material: CourseCardMaterial.liquidGlass,
    );
    await tester.pumpWidget(wrap(surface(style), glassEnabled: true));
    await tester.pumpAndSettle();

    expect(inSurface(find.byType(LiquidGlassLens)), findsOneWidget);
    expect(inSurface(find.byType(BackdropFilter)), findsNothing);
  });
}
