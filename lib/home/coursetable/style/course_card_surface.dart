import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:liquid_glass_easy/liquid_glass_easy.dart';

import '../../../theme/glass/glass_theme.dart';
import 'course_table_style.dart';

/// 课程块的外壳：按用户选择的材质渲染「纯色 / 毛玻璃 / 液态玻璃」。
///
/// 布局（高度、外边距、内边距）仍由课表页决定，这里只负责表面与描边，
/// 这样周视图、日视图和设置页预览可以共用同一份材质实现。
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
    final AppGlassTheme glass = context.glassTheme;
    final BorderRadius radius = BorderRadius.circular(borderRadius);
    final double opacity = style.cardOpacity.clamp(0.0, 1.0);
    final Color tint = accent.withValues(alpha: opacity);

    // 液态玻璃没开启（或平台不支持）时降到毛玻璃，避免出现「选了但没效果」。
    final CourseCardMaterial material =
        style.material == CourseCardMaterial.liquidGlass && !glass.enabled
            ? CourseCardMaterial.frosted
            : style.material;

    switch (material) {
      case CourseCardMaterial.solid:
        if (opacity <= 0) {
          // 纯色 0 透明度 = 完全不显示底色，只留文字与点击区域。
          return child;
        }
        return DecoratedBox(
          decoration: BoxDecoration(color: tint, borderRadius: radius),
          child: child,
        );

      case CourseCardMaterial.frosted:
        return ClipRRect(
          borderRadius: radius,
          child: BackdropFilter(
            filter: ui.ImageFilter.blur(sigmaX: 12, sigmaY: 12),
            child: DecoratedBox(
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
            ),
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
