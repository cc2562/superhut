import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:superhut/theme/app_theme.dart';
import 'package:superhut/theme/glass/glass_menu.dart';
import 'package:superhut/theme/glass/glass_segmented.dart';
import 'package:superhut/theme/glass/glass_theme.dart';

void main() {
  test('底栏图标配色跟随主题色', () {
    final scheme = AppTheme.presetScheme(
      AppThemePreset.indigo,
      Brightness.light,
    );
    final glass = AppGlassTheme(enabled: true, brightness: Brightness.light);

    final style = glass.tabItemStyleOf(scheme);

    expect(style.selectedColor, scheme.primary);
    expect(style.unselectedColor, scheme.onSurfaceVariant);
  });

  testWidgets('玻璃关闭时 GlassSegmented 回落 Material 分段控件', (tester) async {
    var selected = 'week';

    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.fromScheme(
          AppTheme.presetScheme(AppThemePreset.indigo, Brightness.light),
        ),
        home: Scaffold(
          body: StatefulBuilder(
            builder:
                (context, setState) => GlassSegmented<String>(
                  segments: const [
                    GlassSegment(value: 'week', label: '周'),
                    GlassSegment(value: 'day', label: '日'),
                  ],
                  selected: selected,
                  onChanged: (value) => setState(() => selected = value),
                ),
          ),
        ),
      ),
    );

    expect(find.byType(SegmentedButton<String>), findsOneWidget);

    await tester.tap(find.text('日'));
    await tester.pumpAndSettle();
    expect(selected, 'day');
  });

  testWidgets('玻璃关闭时 showGlassMenu 回落 Material 菜单', (tester) async {
    String? picked;

    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.fromScheme(
          AppTheme.presetScheme(AppThemePreset.indigo, Brightness.light),
        ),
        home: Builder(
          builder:
              (context) => Scaffold(
                body: Center(
                  child: ElevatedButton(
                    onPressed: () async {
                      picked = await showGlassMenu<String>(
                        context: context,
                        anchor: const Rect.fromLTWH(80, 120, 140, 40),
                        items: const [
                          GlassMenuItem(value: 'current', label: '回到当前周'),
                        ],
                      );
                    },
                    child: const Text('open'),
                  ),
                ),
              ),
        ),
      ),
    );

    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
    expect(find.text('回到当前周'), findsOneWidget);

    await tester.tap(find.text('回到当前周'));
    await tester.pumpAndSettle();
    expect(picked, 'current');
  });
}
