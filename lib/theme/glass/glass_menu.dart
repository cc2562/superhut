import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:liquid_glass_easy/liquid_glass_easy.dart';

import 'glass_theme.dart';

/// 玻璃菜单里的一项。
@immutable
class GlassMenuItem<T> {
  const GlassMenuItem({required this.value, required this.label, this.icon});

  final T value;
  final String label;
  final IconData? icon;
}

/// 在 [anchor] 下方浮出一枚玻璃菜单。
///
/// 用于替代 `PopupMenuButton`：锚点由调用方用 `GlobalKey` 计算
/// （`RenderBox.localToGlobal` + `size`），内部会做屏幕边界收敛。
/// 玻璃关闭时回落 Material 的 `showMenu`。
Future<T?> showGlassMenu<T>({
  required BuildContext context,
  required Rect anchor,
  required List<GlassMenuItem<T>> items,
  double minWidth = 180,
  double itemHeight = 44,
  double maxPanelHeight = 360,
}) {
  final glass = context.glassTheme;

  if (!glass.enabled) {
    final overlayBox =
        Overlay.of(context).context.findRenderObject() as RenderBox?;
    final overlaySize = overlayBox?.size ?? MediaQuery.sizeOf(context);
    return showMenu<T>(
      context: context,
      position: RelativeRect.fromRect(anchor, Offset.zero & overlaySize),
      items: [
        for (final item in items)
          PopupMenuItem<T>(
            value: item.value,
            child: Row(
              children: [
                if (item.icon != null) ...[
                  Icon(item.icon, size: 18),
                  const SizedBox(width: 10),
                ],
                Text(item.label),
              ],
            ),
          ),
      ],
    );
  }

  final screen = MediaQuery.sizeOf(context);
  const gap = 6.0;
  const margin = 8.0;
  final double width = math.max(minWidth, anchor.width).toDouble();
  final double left =
      anchor.left
          .clamp(margin, math.max(margin, screen.width - width - margin))
          .toDouble();
  // 条目数量不设上限：面板高度收敛到 maxPanelHeight 与可用空间，超出部分滚动。
  final double contentHeight = items.length * itemHeight + 12;
  final double spaceBelow = screen.height - margin - (anchor.bottom + gap);
  final double spaceAbove = anchor.top - gap - margin;
  final bool openBelow =
      spaceBelow >= math.min(contentHeight, maxPanelHeight) ||
      spaceBelow >= spaceAbove;
  final double panelHeight = math.min(
    contentHeight,
    math.min(
      maxPanelHeight,
      math.max(openBelow ? spaceBelow : spaceAbove, 96.0),
    ),
  );
  final double top =
      openBelow
          ? anchor.bottom + gap
          : math.max(margin, anchor.top - gap - panelHeight).toDouble();

  return showGeneralDialog<T>(
    context: context,
    barrierDismissible: true,
    barrierLabel: MaterialLocalizations.of(context).modalBarrierDismissLabel,
    barrierColor: Colors.transparent,
    transitionDuration: const Duration(milliseconds: 180),
    pageBuilder: (dialogContext, animation, secondaryAnimation) {
      return Stack(
        children: [
          Positioned(
            left: left,
            top: top,
            width: width,
            child: FadeTransition(
              opacity: animation,
              child: ScaleTransition(
                alignment: Alignment.topLeft,
                scale: Tween<double>(begin: 0.96, end: 1).animate(
                  CurvedAnimation(
                    parent: animation,
                    curve: Curves.easeOutCubic,
                  ),
                ),
                child: ConstrainedBox(
                  constraints: BoxConstraints(maxHeight: panelHeight),
                  child: LiquidGlassLens(
                    style: glass.menuStyle,
                    // 菜单点完就关，只留按下时的轻微鼓包。
                    touch: glass.touchPanel,
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.symmetric(vertical: 6),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          for (final item in items)
                            _GlassMenuRow(
                              label: item.label,
                              icon: item.icon,
                              height: itemHeight,
                              onTap:
                                  () => Navigator.of(
                                    dialogContext,
                                  ).pop(item.value),
                            ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      );
    },
  );
}

class _GlassMenuRow extends StatelessWidget {
  const _GlassMenuRow({
    required this.label,
    required this.onTap,
    required this.height,
    this.icon,
  });

  final String label;
  final IconData? icon;
  final double height;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Material(
      type: MaterialType.transparency,
      child: InkWell(
        onTap: onTap,
        child: SizedBox(
          height: height,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              children: [
                if (icon != null) ...[
                  Icon(icon, size: 18, color: scheme.onSurfaceVariant),
                  const SizedBox(width: 10),
                ],
                Expanded(
                  child: Text(
                    label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(fontSize: 14, color: scheme.onSurface),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
