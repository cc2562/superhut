import 'package:flutter/material.dart';
import 'package:liquid_glass_easy/liquid_glass_easy.dart';

import 'glass_theme.dart';

/// 玻璃分段控件里的一个分段。
@immutable
class GlassSegment<T> {
  const GlassSegment({required this.value, required this.label, this.icon});

  final T value;
  final String label;
  final IconData? icon;
}

/// 单片玻璃里的分段切换。
///
/// 结构：一枚玻璃胶囊 + 内部等宽的若干分段，选中段是一枚在 180ms 内横向
/// 滑动的柔光药丸。两种宽度策略：
/// * 默认按 [segmentWidth] 贴合内容收缩（课表的「周 / 日」）；
/// * [expand] 为真时等分父级宽度（设置的「系统 / 浅色 / 深色」）。
///
/// 玻璃关闭时回落 Material `SegmentedButton`。
class GlassSegmented<T> extends StatelessWidget {
  const GlassSegmented({
    super.key,
    required this.segments,
    required this.selected,
    required this.onChanged,
    this.height = 34,
    this.segmentWidth = 44,
    this.expand = false,
    this.pillHighlight = false,
    this.style,
  });

  final List<GlassSegment<T>> segments;
  final T selected;
  final ValueChanged<T> onChanged;
  final double height;

  /// 未开启 [expand] 时每个分段的固定宽度。
  final double segmentWidth;

  /// 是否铺满父级宽度（各段等分）。
  final bool expand;

  /// 选中药丸是否使用主题色的「玻璃滑块」质感（描边 + 高光 + 投影）。
  final bool pillHighlight;

  final LiquidGlassStyle? style;

  static const double _inset = 3;
  static const Duration _duration = Duration(milliseconds: 180);

  @override
  Widget build(BuildContext context) {
    final glass = context.glassTheme;
    final scheme = Theme.of(context).colorScheme;

    if (!glass.enabled) {
      return SegmentedButton<T>(
        showSelectedIcon: false,
        segments: [
          for (final segment in segments)
            ButtonSegment<T>(
              value: segment.value,
              label: Text(segment.label),
              icon: segment.icon == null ? null : Icon(segment.icon),
            ),
        ],
        selected: <T>{selected},
        onSelectionChanged: (selection) {
          if (selection.isNotEmpty) onChanged(selection.first);
        },
      );
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        final double available = constraints.maxWidth;
        final bool stretch = expand && available.isFinite;
        final double width =
            stretch ? available : segments.length * segmentWidth + _inset * 2;
        final double segmentExtent =
            stretch ? (width - _inset * 2) / segments.length : segmentWidth;
        final double pillRadius = (height - _inset * 2) / 2;

        final index = segments.indexWhere(
          (segment) => segment.value == selected,
        );
        final selectedIndex = index < 0 ? 0 : index;
        final Color selectedTextColor =
            pillHighlight ? scheme.primary : scheme.onSurface;

        return SizedBox(
          height: height,
          width: width,
          child: Container(
            // 不投影，但和顶部圆钮、底部栏一样补一圈发丝描边：白色玻璃压
            // 在浅色页面上才看得出边界。
            foregroundDecoration: BoxDecoration(
              borderRadius: BorderRadius.circular(height / 2),
              border: Border.all(
                color: scheme.onSurface.withValues(
                  alpha: glass.isDark ? 0.16 : 0.10,
                ),
              ),
            ),
            child: LiquidGlassLens(
              // 分段控件与内容同层，不投影，避免胶囊周围出现一条灰边。
              style:
                  style ??
                  glass.controlStyle(radius: height / 2, withShadow: false),
              child: Padding(
                padding: const EdgeInsets.all(_inset),
                child: Stack(
                  children: [
                    AnimatedPositioned(
                      duration: _duration,
                      curve: Curves.easeOutCubic,
                      left: selectedIndex * segmentExtent,
                      top: 0,
                      bottom: 0,
                      width: segmentExtent,
                      child: DecoratedBox(
                        decoration: _pillDecoration(glass, scheme, pillRadius),
                      ),
                    ),
                    Row(
                      children: [
                        for (final segment in segments)
                          SizedBox(
                            width: segmentExtent,
                            child: Material(
                              type: MaterialType.transparency,
                              child: InkWell(
                                borderRadius: BorderRadius.circular(pillRadius),
                                onTap: () => onChanged(segment.value),
                                child: Semantics(
                                  button: true,
                                  selected: segment.value == selected,
                                  label: segment.label,
                                  child: Center(
                                    child: Row(
                                      mainAxisAlignment:
                                          MainAxisAlignment.center,
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        if (segment.icon != null) ...[
                                          Icon(
                                            segment.icon,
                                            size: 16,
                                            color:
                                                segment.value == selected
                                                    ? selectedTextColor
                                                    : scheme.onSurfaceVariant,
                                          ),
                                          const SizedBox(width: 4),
                                        ],
                                        Flexible(
                                          child: Text(
                                            segment.label,
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                            style: TextStyle(
                                              fontSize: 13,
                                              fontWeight: FontWeight.w600,
                                              color:
                                                  segment.value == selected
                                                      ? selectedTextColor
                                                      : scheme.onSurfaceVariant,
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  /// 选中药丸：默认是中性柔光，[pillHighlight] 时叠成主题色的玻璃滑块
  /// （描边 + 顶部高光），仍然只有一层描边装饰、不叠第二枚镜片。
  ///
  /// 药丸不投任何阴影：它贴在胶囊里滑动，投影会在胶囊内侧留下一条灰边。
  BoxDecoration _pillDecoration(
    AppGlassTheme glass,
    ColorScheme scheme,
    double radius,
  ) {
    if (!pillHighlight) {
      return BoxDecoration(
        color: glass.selectionTint,
        borderRadius: BorderRadius.circular(radius),
      );
    }
    return BoxDecoration(
      color: scheme.primary.withValues(alpha: glass.isDark ? 0.30 : 0.20),
      borderRadius: BorderRadius.circular(radius),
      border: Border.all(
        color: Colors.white.withValues(alpha: glass.isDark ? 0.18 : 0.55),
        width: 1,
      ),
      // 顶部到中部的白色高光渐变，让药丸读起来是一枚玻璃滑块而不是色块。
      // 浅色下收敛到 0.18，否则会把 primary 底洗成一片白。
      gradient: LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [
          Colors.white.withValues(alpha: glass.isDark ? 0.10 : 0.18),
          Colors.white.withValues(alpha: 0),
        ],
        stops: const [0, 1],
      ),
    );
  }
}
