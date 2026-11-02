import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:liquid_glass_easy/liquid_glass_easy.dart';

import '../../../theme/glass/glass_theme.dart';
import 'course_table_style.dart';

/// 课程块的外壳：按用户选择的材质渲染「纯色 / 毛玻璃 / 液态玻璃」。
///
/// 布局（高度、外边距、内边距）仍由课表页决定，这里只负责表面与描边，
/// 这样周视图、日视图和设置页预览可以共用同一份材质实现。
///
/// 只负责把「课程身份色」换算成实际底色；材质渲染统一委托给
/// [CourseMaterialSurface]，避免课表页出现第二套 switch。
class CourseCardSurface extends StatelessWidget {
  const CourseCardSurface({
    super.key,
    required this.accent,
    required this.style,
    required this.child,
    this.borderRadius = 8,
  });

  /// 课程身份色（由课程名哈希生成），仍是每门课的视觉标识。
  final Color accent;

  final CourseTableStyle style;

  final Widget child;

  final double borderRadius;

  @override
  Widget build(BuildContext context) {
    final ColorScheme scheme = Theme.of(context).colorScheme;
    // 底色统一由 style 计算：打开「课程块彩色」时是课程色，关闭时是无色蒙版
    // （页面偏亮铺白、偏暗铺黑）。文字色自适应用的是同一份计算，不会两处打架。
    final Color tint = style.cardTint(
      accent,
      pageEstimate: style.estimatedPageColor(scheme),
    );

    return CourseMaterialSurface(
      tint: tint,
      style: style,
      borderRadius: borderRadius,
      child: child,
    );
  }
}

/// 课表页可选外观的通用表面：纯色 / 毛玻璃 / 液态玻璃。
///
/// 只接收**已经算好 alpha 的 [tint]**，因此课程块（课程色）、周视图「今天」
/// 指示、日视图「下一节课」（主题色）可以共用同一份材质实现与降级逻辑：
/// * 液态玻璃未开启（或平台不支持）时降级为毛玻璃，避免「选了但没效果」；
/// * 毛玻璃 `sigma < 0.5` 时跳过 [BackdropFilter]，不为看不见的模糊付离屏开销；
/// * 纯色且完全透明时直接返回 [child]，不产生任何图层。
class CourseMaterialSurface extends StatelessWidget {
  const CourseMaterialSurface({
    super.key,
    required this.tint,
    required this.style,
    required this.child,
    this.borderRadius = 8,
  });

  /// 已带不透明度的底色。
  final Color tint;

  /// 材质与模糊参数的来源（课程块外观设置）。
  final CourseTableStyle style;

  final Widget child;

  final double borderRadius;

  @override
  Widget build(BuildContext context) {
    final ColorScheme scheme = Theme.of(context).colorScheme;
    final AppGlassTheme glass = context.glassTheme;
    final BorderRadius radius = BorderRadius.circular(borderRadius);

    // 液态玻璃没开启（或平台不支持）时降到毛玻璃，避免出现「选了但没效果」。
    final CourseCardMaterial material =
        style.material == CourseCardMaterial.liquidGlass && !glass.enabled
            ? CourseCardMaterial.frosted
            : style.material;

    switch (material) {
      case CourseCardMaterial.solid:
        if (tint.a <= 0) {
          // 纯色 0 透明度 = 完全不显示底色，只留文字与点击区域。
          return child;
        }
        return DecoratedBox(
          decoration: BoxDecoration(color: tint, borderRadius: radius),
          child: child,
        );

      case CourseCardMaterial.frosted:
        final double sigma = style.cardBlur.clamp(
          0.0,
          CourseTableStyle.maxCardBlur,
        );
        final Widget frostedBody = DecoratedBox(
          decoration: BoxDecoration(
            color: tint,
            borderRadius: radius,
            // 白玻璃压在浅色底图上也要有轮廓，与顶栏控件同一条发丝描边。
            border: Border.all(
              color: scheme.onSurface.withValues(
                alpha: glass.isDark ? 0.16 : 0.10,
              ),
            ),
          ),
          child: child,
        );
        // sigma 为 0 时模糊没有视觉效果，直接跳过 BackdropFilter，
        // 省掉一张离屏图层（每块课程卡各一份，周视图里一次就是十几张）。
        if (sigma < 0.5) return frostedBody;
        return ClipRRect(
          borderRadius: radius,
          child: BackdropFilter(
            filter: ui.ImageFilter.blur(sigmaX: sigma, sigmaY: sigma),
            child: frostedBody,
          ),
        );

      case CourseCardMaterial.liquidGlass:
        return LiquidGlassLens(
          style: glass
              .controlStyle(radius: borderRadius, withShadow: false)
              .copyWith(color: tint),
          child: child,
        );
    }
  }
}
