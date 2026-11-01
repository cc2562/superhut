import 'package:flutter/material.dart';

/// 浮在「平台视图」（WebView / 地图 / 相机）之上的圆形控件。
///
/// 玻璃镜片只能采样 Flutter 自己的图层，采样不到 `InAppWebView` 这类原生
/// 视图，硬套 [LiquidGlassLens] 只会得到一块没有折射的死灰圆片。这里改用
/// 半透明实底 + 细描边 + 轻投影：在任何网页背景上都能读出图标，也不假装
/// 自己是玻璃。
class ScrimControlButton extends StatelessWidget {
  const ScrimControlButton({
    super.key,
    required this.icon,
    this.onTap,
    this.size = 44,
    this.iconSize = 20,
    this.tooltip,
    this.semanticLabel,
    this.color,
  });

  final IconData icon;
  final VoidCallback? onTap;
  final double size;
  final double iconSize;
  final String? tooltip;
  final String? semanticLabel;

  /// 图标颜色；默认按明暗模式取白 / 近黑。
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final bool isDark = Theme.of(context).brightness == Brightness.dark;
    final Color iconColor = color ?? (isDark ? Colors.white : scheme.onSurface);
    final Color scrim =
        isDark
            ? Colors.black.withValues(alpha: 0.55)
            : Colors.white.withValues(alpha: 0.88);

    Widget button = SizedBox(
      width: size,
      height: size,
      child: Material(
        color: scrim,
        shape: CircleBorder(
          side: BorderSide(
            color: (isDark ? Colors.white : Colors.black).withValues(
              alpha: isDark ? 0.18 : 0.06,
            ),
          ),
        ),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: Icon(icon, size: iconSize, color: iconColor),
        ),
      ),
    );

    button = DecoratedBox(
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.34 : 0.12),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: button,
    );

    if (tooltip != null) {
      button = Tooltip(message: tooltip!, child: button);
    }
    return Semantics(
      button: true,
      label: semanticLabel ?? tooltip,
      child: button,
    );
  }
}
