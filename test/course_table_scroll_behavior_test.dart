import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:superhut/home/coursetable/course_table_scroll_behavior.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  /// 安卓 + Material 3 才会用拉伸（Stretching）指示器，也就是闪烁的元凶。
  final ThemeData androidM3 = ThemeData(
    platform: TargetPlatform.android,
    useMaterial3: true,
  );

  Widget wrap(Widget child) =>
      MaterialApp(theme: androidM3, home: Scaffold(body: child));

  Widget tallList() => ListView(children: const [SizedBox(height: 4000)]);

  testWidgets('对照组：默认安卓 M3 列表会挂拉伸指示器', (tester) async {
    await tester.pumpWidget(wrap(tallList()));
    await tester.pumpAndSettle();

    // 指示器是常驻在 Scrollable 里的（只是不滚动时不画），所以不必真的拖动。
    expect(find.byType(StretchingOverscrollIndicator), findsOneWidget);
  });

  testWidgets('课表滚动行为不挂任何 overscroll 指示器', (tester) async {
    await tester.pumpWidget(
      wrap(
        ScrollConfiguration(
          behavior: const CourseTableScrollBehavior(),
          child: tallList(),
        ),
      ),
    );
    await tester.pumpAndSettle();

    // 拉伸（闪烁来源）与光晕都不该出现：滚到边缘内容直接停住。
    expect(find.byType(StretchingOverscrollIndicator), findsNothing);
    expect(find.byType(GlowingOverscrollIndicator), findsNothing);
  });

  testWidgets('课表滚动行为原样返回传入的 child', (tester) async {
    late BuildContext captured;
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) {
            captured = context;
            return const SizedBox.shrink();
          },
        ),
      ),
    );

    const Widget child = SizedBox(key: Key('course-table-body'));
    final Widget built = const CourseTableScrollBehavior()
        .buildOverscrollIndicator(
          captured,
          child,
          const ScrollableDetails(direction: AxisDirection.down),
        );

    expect(identical(built, child), isTrue);
  });
}
