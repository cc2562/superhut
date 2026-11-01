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

/// 单片玻璃里的分段切换（用于课表的「周 / 日」）。
///
/// 结构：一枚玻璃胶囊 + 内部等宽的若干分段，选中段是一枚在 180ms 内横向
/// 滑动的柔光药丸。玻璃关闭时回落 Material `SegmentedButton`。
class GlassSegmented<T> extends StatelessWidget {
  const GlassSegmented({
    super.key,
    required this.segments,
    required this.selected,
    required this.onChanged,
    this.height = 34,
    this.segmentWidth = 44,
    this.style,
  });

  final List<GlassSegment<T>> segments;
  final T selected;
  final ValueChanged<T> onChanged;
  final double height;
  final double segmentWidth;
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

    final index = segments.indexWhere((segment) => segment.value == selected);
    final selectedIndex = index < 0 ? 0 : index;
    final width = segments.length * segmentWidth + _inset * 2;

    return SizedBox(
      height: height,
      width: width,
      child: LiquidGlassLens(
        style: style ?? glass.controlStyle(radius: height / 2),
        child: Padding(
          padding: const EdgeInsets.all(_inset),
          child: Stack(
            children: [
              AnimatedPositioned(
                duration: _duration,
                curve: Curves.easeOutCubic,
                left: selectedIndex * segmentWidth,
                top: 0,
                bottom: 0,
                width: segmentWidth,
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    color: glass.selectionTint,
                    borderRadius: BorderRadius.circular((height - _inset * 2) / 2),
                  ),
                ),
              ),
              Row(
                children: [
                  for (final segment in segments)
                    SizedBox(
                      width: segmentWidth,
                      child: Material(
                        type: MaterialType.transparency,
                        child: InkWell(
                          borderRadius: BorderRadius.circular(
                            (height - _inset * 2) / 2,
                          ),
                          onTap: () => onChanged(segment.value),
                          child: Semantics(
                            button: true,
                            selected: segment.value == selected,
                            label: segment.label,
                            child: Center(
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  if (segment.icon != null) ...[
                                    Icon(
                                      segment.icon,
                                      size: 16,
                                      color:
                                          segment.value == selected
                                              ? scheme.onSurface
                                              : scheme.onSurfaceVariant,
                                    ),
                                    const SizedBox(width: 4),
                                  ],
                                  Text(
                                    segment.label,
                                    style: TextStyle(
                                      fontSize: 13,
                                      fontWeight: FontWeight.w600,
                                      color:
                                          segment.value == selected
                                              ? scheme.onSurface
                                              : scheme.onSurfaceVariant,
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
    );
  }
}
