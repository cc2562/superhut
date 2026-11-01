import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:superhut/home/coursetable/style/course_table_style.dart';
import 'package:superhut/home/coursetable/style/course_table_style_controller.dart';
import 'package:superhut/pages/settings/course_table_style_page.dart';
import 'package:superhut/theme/theme_controller.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await Get.deleteAll(force: true);
  });

  tearDown(() async {
    await Get.deleteAll(force: true);
  });

  Future<ThemeController> pumpPage(WidgetTester tester) async {
    await tester.binding.setSurfaceSize(const Size(800, 1600));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final ThemeController theme = Get.put(ThemeController());
    await theme.load();
    await tester.pumpWidget(
      MaterialApp(theme: theme.lightTheme, home: const CourseTableStylePage()),
    );
    await tester.pumpAndSettle();
    return theme;
  }

  testWidgets('设置页展示全部分组与预览', (tester) async {
    await pumpPage(tester);

    expect(find.text('背景'), findsOneWidget);
    expect(find.text('背景颜色'), findsOneWidget);
    expect(find.text('背景图片'), findsOneWidget);
    expect(find.text('课程块'), findsOneWidget);
    expect(find.text('恢复默认设置'), findsOneWidget);
    expect(find.text('预览'), findsOneWidget);

    // 预览里的三门示例课程。
    expect(find.text('高等数学'), findsOneWidget);
    expect(find.text('大学物理'), findsOneWidget);

    // 玻璃关闭时回落 Material 分段控件，材质与文字颜色各一枚。
    expect(find.byType(SegmentedButton<CourseCardMaterial>), findsOneWidget);
    expect(find.byType(SegmentedButton<CourseTextColorMode>), findsOneWidget);

    for (final material in CourseCardMaterial.values) {
      expect(find.text(material.label), findsWidgets);
    }
  });

  testWidgets('拖动不透明度滑杆松手后提交给控制器', (tester) async {
    await pumpPage(tester);
    final controller = CourseTableStyleController.instance;

    // 没有背景图时图片滑杆被 IgnorePointer 禁用，最后一枚是课程块不透明度。
    final Slider slider = tester.widget<Slider>(find.byType(Slider).last);
    expect(slider.value, controller.value.cardOpacity);

    await tester.drag(find.byType(Slider).last, const Offset(-120, 0));
    await tester.pumpAndSettle();

    expect(controller.value.cardOpacity, lessThan(0.82));
  });

  testWidgets('切换材质与文字颜色立即写回控制器', (tester) async {
    await pumpPage(tester);
    final controller = CourseTableStyleController.instance;

    await tester.tap(find.text(CourseCardMaterial.frosted.label));
    await tester.pumpAndSettle();
    expect(controller.value.material, CourseCardMaterial.frosted);

    await tester.tap(find.text(CourseTextColorMode.white.label));
    await tester.pumpAndSettle();
    expect(controller.value.textColor, CourseTextColorMode.white);
  });

  testWidgets('恢复默认会弹确认框并清空设置', (tester) async {
    await pumpPage(tester);
    final controller = CourseTableStyleController.instance;
    await controller.setCardOpacity(0.2);
    await tester.pumpAndSettle();

    await tester.tap(find.text('恢复默认设置'));
    await tester.pumpAndSettle();
    expect(find.text('恢复默认？'), findsOneWidget);

    await tester.tap(find.text('恢复'));
    await tester.pumpAndSettle();
    expect(controller.value, CourseTableStyle.defaults);
  });
}
