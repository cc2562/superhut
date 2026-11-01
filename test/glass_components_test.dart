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

  testWidgets('expand 版分段控件在玻璃关闭时同样回落 Material', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.fromScheme(
          AppTheme.presetScheme(AppThemePreset.indigo, Brightness.light),
        ),
        home: Scaffold(
          body: GlassSegmented<String>(
            expand: true,
            height: 40,
            pillHighlight: true,
            segments: const [
              GlassSegment(value: 'a', label: '系统', icon: Icons.brightness_auto),
              GlassSegment(value: 'b', label: '浅色', icon: Icons.light_mode),
              GlassSegment(value: 'c', label: '深色', icon: Icons.dark_mode),
            ],
            selected: 'a',
            onChanged: (_) {},
          ),
        ),
      ),
    );

    expect(find.byType(SegmentedButton<String>), findsOneWidget);
    expect(find.text('浅色'), findsOneWidget);
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
