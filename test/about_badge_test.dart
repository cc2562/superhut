import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:superhut/home/about/badge_effects.dart';
import 'package:superhut/home/about/trans_badge.dart';
import 'package:superhut/home/about/view.dart';

Finder get _customPaintWithPainter => find.byWidgetPredicate(
  (Widget widget) => widget is CustomPaint && widget.painter != null,
);

void main() {
  group('转四圈触发', () {
    test('累计满 8π 才触发，反向与重置都按绝对值累计', () {
      final BadgeSpinAccumulator spin = BadgeSpinAccumulator();
      expect(spin.shouldReveal, isFalse);

      spin.add(math.pi * 2);
      expect(spin.shouldReveal, isFalse);

      // 往反方向继续转同样计入（用户可能左右来回搓）。
      spin.add(-math.pi * 6);
      expect(spin.total, closeTo(8 * math.pi, 1e-9));
      expect(spin.shouldReveal, isTrue);

      spin.reset();
      expect(spin.total, 0);
      expect(spin.shouldReveal, isFalse);
    });

    test('来回小幅抖动不会误触发', () {
      final BadgeSpinAccumulator spin = BadgeSpinAccumulator();
      for (int i = 0; i < 20; i++) {
        spin.add(i.isEven ? 0.2 : -0.2);
      }
      expect(spin.shouldReveal, isFalse);
    });
  });

  group('立体徽章渲染', () {
    testWidgets('各种翻转角度与明暗主题都不会抛异常', (WidgetTester tester) async {
      const List<double> angles = <double>[
        0,
        math.pi / 4,
        math.pi / 2,
        3 * math.pi / 4,
        math.pi,
        3 * math.pi / 2,
      ];

      for (final Brightness brightness in Brightness.values) {
        for (final double angle in angles) {
          await tester.pumpWidget(
            MaterialApp(
              theme: ThemeData(brightness: brightness),
              home: Scaffold(
                body: Center(
                  child: TransBadge(
                    pose: BadgePose(rotationX: angle / 6, rotationY: angle),
                  ),
                ),
              ),
            ),
          );
          expect(
            tester.takeException(),
            isNull,
            reason: 'angle=$angle brightness=$brightness',
          );
        }
      }
    });

    testWidgets('徽章真的落在画布上（存在不透明像素）', (WidgetTester tester) async {
      final GlobalKey key = GlobalKey();
      await tester.pumpWidget(
        MaterialApp(
          theme: ThemeData(brightness: Brightness.light),
          home: Scaffold(
            body: Center(
              child: RepaintBoundary(
                key: key,
                child: const TransBadge(pose: BadgePose(rotationY: 0.4)),
              ),
            ),
          ),
        ),
      );

      final RenderRepaintBoundary boundary =
          key.currentContext!.findRenderObject()! as RenderRepaintBoundary;

      final int painted =
          await tester.runAsync(() async {
            final ui.Image image = await boundary.toImage();
            final ByteData? data = await image.toByteData(
              format: ui.ImageByteFormat.rawRgba,
            );
            image.dispose();
            if (data == null) return 0;
            final Uint8List bytes = data.buffer.asUint8List();
            int count = 0;
            for (int i = 3; i < bytes.length; i += 4) {
              if (bytes[i] > 8) count++;
            }
            return count;
          }) ??
          0;

      expect(painted, greaterThan(2000));
    });
  });

  group('关于页集成', () {
    testWidgets('拖动转满四圈后亮起泛光与粒子', (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: ThemeData(useMaterial3: true),
          home: const AboutPage(),
        ),
      );
      await tester.pump();

      final Finder badge = find.byType(TransBadge);
      expect(badge, findsOneWidget);

      // 灵敏度是每逻辑像素 π/80，400px 约 5π，两次即超过四圈（8π）。
      await tester.drag(badge, const Offset(400, 0));
      await tester.pump();
      expect(
        tester.widget<TransBadge>(badge).pose.rotationY.abs(),
        greaterThan(1),
        reason: '拖动应该改变徽章姿态',
      );
      await tester.drag(badge, const Offset(400, 0));
      // 第一帧只启动 ticker，第二帧才开始推进动画时间。
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 320));

      expect(tester.takeException(), isNull);
      // 徽章、泛光、粒子三层都在画。
      expect(
        _customPaintWithPainter.evaluate().length,
        greaterThanOrEqualTo(3),
        reason:
            'pose=${tester.widget<TransBadge>(badge).pose.rotationY}, '
            'glow=${tester.widget<BadgeGlow>(find.byType(BadgeGlow)).intensity}, '
            'badges=${find.byType(BadgeGlow).evaluate().length}',
      );

      // 走完 8 秒展示与 1 秒淡出，避免测试结束时留下挂起的计时器。
      await tester.pump(const Duration(seconds: 8));
      await tester.pump(const Duration(seconds: 1));
      await tester.pump(const Duration(milliseconds: 900));
      expect(tester.takeException(), isNull);
    });
  });

  group('彩蛋奖励', () {
    testWidgets('泛光强度为 0 时不构建任何图层', (WidgetTester tester) async {
      await tester.pumpWidget(const MaterialApp(home: BadgeGlow(intensity: 0)));
      expect(_customPaintWithPainter, findsNothing);
    });

    testWidgets('泛光亮起后绘制光晕', (WidgetTester tester) async {
      await tester.pumpWidget(const MaterialApp(home: BadgeGlow(intensity: 1)));
      expect(_customPaintWithPainter, findsOneWidget);
    });

    testWidgets('粒子在未播放时不绘制，播放后出现', (WidgetTester tester) async {
      final AnimationController controller = AnimationController(
        vsync: const TestVSync(),
        duration: const Duration(milliseconds: 1200),
      );
      addTearDown(controller.dispose);

      await tester.pumpWidget(
        MaterialApp(home: BadgeParticles(controller: controller, size: 200)),
      );
      expect(_customPaintWithPainter, findsNothing);

      controller.forward();
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
      expect(_customPaintWithPainter, findsOneWidget);

      // 播完之后回到静止状态，不常驻动画。
      await tester.pump(const Duration(milliseconds: 1200));
      expect(_customPaintWithPainter, findsNothing);
    });
  });
}
