import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:liquid_glass_easy/liquid_glass_easy.dart';

import 'glass_theme.dart';

/// 顶部功能层的结构。
///
/// 三段彼此独立，不共用一整条玻璃：
/// * 左侧：一枚独立的圆形玻璃按钮（返回等）；
/// * 中间：纯文字标题，**背后没有玻璃**，仅在页面下滚后淡入；
/// * 右侧：所有操作按钮共用一枚玻璃——单个操作是正圆，两个及以上是椭圆胶囊。
class GlassTopBar extends StatelessWidget {
  const GlassTopBar({
    super.key,
    required this.title,
    required this.revealed,
    this.leading,
    this.actions = const [],
    this.alwaysShowTitle = true,
    this.height = 56,
    this.controlSize = 44,
    this.horizontalPadding = 12,
    this.foregroundColor,
    this.actionsReservedWidth,
  });

  final String title;

  /// 标题是否显现（由宿主页面的滚动通知驱动）。
  final ValueListenable<bool> revealed;

  /// 左侧控件；为 `null` 时不渲染。
  final Widget? leading;

  /// 右侧操作按钮；为 `null` 或空时不渲染玻璃组。
  final List<Widget> actions;

  /// 标题是否常驻。
  ///
  /// 默认 `true`——绝大多数页面（电费、成绩、设置等）的标题始终可见，用户
  /// 随时知道自己在哪。只有聚合多功能的浏览型页面（如智慧工大）才传
  /// `false`，改用 [revealed] 做「下滚淡入、回顶淡出」。
  final bool alwaysShowTitle;

  final double height;

  /// 单个控件的边长：圆形按钮的直径，也是操作胶囊的高度。
  final double controlSize;

  final double horizontalPadding;

  /// 标题与图标的统一前景色；默认取主题 `onSurface`。
  /// 压在深色内容（相机预览等）上时传 `Colors.white`。
  final Color? foregroundColor;

  /// 操作组宽度；为 `null` 时按按钮数量推算。
  ///
  /// 需要容纳 `TextButton` 这类非图标动作时显式指定（如 110），
  /// 同时它也是标题避让的预留宽度。
  final double? actionsReservedWidth;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final foreground = foregroundColor ?? scheme.onSurface;
    final topInset = MediaQuery.paddingOf(context).top;
    final hasLeading = leading != null;
    final hasActions = actions.isNotEmpty;

    final double actionGroupWidth =
        !hasActions
            ? 0
            : actionsReservedWidth ??
                GlassActionGroup.widthFor(actions.length, controlSize);
    final double reserveLeft = hasLeading ? controlSize + 8 : 0;
    final double reserveRight = hasActions ? actionGroupWidth + 8 : 0;
    final double titleInset =
        horizontalPadding +
        (reserveLeft > reserveRight ? reserveLeft : reserveRight);

    return Padding(
      padding: EdgeInsets.only(top: topInset),
      child: SizedBox(
        height: height,
        child: Stack(
          children: [
            // ── 居中标题：没有任何玻璃底板 ────────────────────────
            Positioned.fill(
              child: IgnorePointer(
                child: Padding(
                  padding: EdgeInsets.symmetric(horizontal: titleInset),
                  child: Center(child: _buildTitle(scheme, foreground)),
                ),
              ),
            ),
            // ── 左侧圆形玻璃 ────────────────────────────────────
            if (hasLeading)
              Positioned(
                left: horizontalPadding,
                top: (height - controlSize) / 2,
                child: leading!,
              ),
            // ── 右侧操作玻璃（单圆 / 多椭圆）────────────────────
            if (hasActions)
              Positioned(
                right: horizontalPadding,
                top: (height - controlSize) / 2,
                child: GlassActionGroup(
                  actions: actions,
                  size: controlSize,
                  foregroundColor: foreground,
                  groupWidth: actionsReservedWidth,
                ),
              ),
          ],
        ),
      ),
    );
  }

  /// 标题本体：常驻时直接渲染，浏览型页面才挂上淡入动画子树。
  Widget _buildTitle(ColorScheme scheme, Color foreground) {
    final text = Semantics(
      header: true,
      child: Text(
        title,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        textAlign: TextAlign.center,
        style: TextStyle(
          fontSize: 17,
          fontWeight: FontWeight.w600,
          letterSpacing: 0.2,
          color: foreground,
          // 标题没有玻璃托底，压在滚动内容上时用两层同色光晕（halo）
          // 保证可读性——不额外增加任何底板，符合「标题背后无玻璃」。
          shadows: [
            Shadow(
              color: scheme.surface.withValues(alpha: 0.98),
              blurRadius: 14,
            ),
            Shadow(color: scheme.surface.withValues(alpha: 0.9), blurRadius: 4),
          ],
        ),
      ),
    );

    if (alwaysShowTitle) return text;

    return ValueListenableBuilder<bool>(
      valueListenable: revealed,
      builder: (context, isRevealed, child) {
        return AnimatedOpacity(
          opacity: isRevealed ? 1 : 0,
          duration: const Duration(milliseconds: 220),
          curve: Curves.easeOut,
          child: AnimatedSlide(
            offset: isRevealed ? Offset.zero : const Offset(0, 0.24),
            duration: const Duration(milliseconds: 220),
            curve: Curves.easeOut,
            child: child,
          ),
        );
      },
      child: text,
    );
  }
}

/// 一枚独立的圆形玻璃控件（返回按钮等）。
class GlassControlButton extends StatelessWidget {
  const GlassControlButton({
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

  /// 图标颜色；默认取主题 `onSurface`。
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final glass = context.glassTheme;
    final scheme = Theme.of(context).colorScheme;
    final button = SizedBox(
      width: size,
      height: size,
      child: Container(
        // 白色玻璃压在白底页面上时几乎看不见，补一圈发丝描边把轮廓勾出来。
        // 只是控件自身的边界，不是内容层材质。
        foregroundDecoration: BoxDecoration(
          shape: BoxShape.circle,
          border: Border.all(
            color: scheme.onSurface.withValues(
              alpha: glass.isDark ? 0.16 : 0.10,
            ),
          ),
        ),
        child: LiquidGlassLens(
          style: glass.controlStyle(radius: size / 2),
          child: Material(
            type: MaterialType.transparency,
            child: InkResponse(
              onTap: onTap,
              radius: size / 2,
              highlightShape: BoxShape.circle,
              child: Center(
                child: Icon(
                  icon,
                  size: iconSize,
                  color: color ?? scheme.onSurface,
                  semanticLabel: semanticLabel,
                ),
              ),
            ),
          ),
        ),
      ),
    );

    if (tooltip == null) return button;
    return Tooltip(message: tooltip!, child: button);
  }
}

/// 右侧操作按钮组：所有按钮共用同一枚玻璃。
///
/// 单个操作为 44×44 正圆；两个及以上为高 44 的椭圆胶囊。
class GlassActionGroup extends StatelessWidget {
  const GlassActionGroup({
    super.key,
    required this.actions,
    this.size = 44,
    this.spacing = 8,
    this.horizontalPadding = 6,
    this.foregroundColor,
    this.groupWidth,
  });

  final List<Widget> actions;
  final double size;
  final double spacing;
  final double horizontalPadding;

  /// 未传 [groupWidth] 时的图标前景色（纯装饰用，图标自身颜色优先）。
  final Color? foregroundColor;

  /// 显式指定整枚玻璃的宽度：用于容纳 `TextButton` 这类非图标动作。
  ///
  /// 为 `null` 时按 [widthFor] 推算，并给每个动作固定 [size] 见方的格子。
  final double? groupWidth;

  /// 给定按钮数量时这枚玻璃的宽度。
  static double widthFor(int count, double size) {
    if (count <= 1) return size;
    const spacing = 8.0;
    const horizontalPadding = 6.0;
    return count * size + (count - 1) * spacing + horizontalPadding * 2;
  }

  @override
  Widget build(BuildContext context) {
    final glass = context.glassTheme;
    final width = groupWidth ?? widthFor(actions.length, size);
    // 指定了整体宽度时，动作按内容自适应（TextButton 等），不再套 44 方框。
    final flexible = groupWidth != null;

    return SizedBox(
      width: width,
      height: size,
      child: Container(
        // 与返回键同一条发丝描边，白色玻璃压在浅色页面上才有轮廓。
        foregroundDecoration: BoxDecoration(
          borderRadius: BorderRadius.circular(size / 2),
          border: Border.all(
            color: Theme.of(context).colorScheme.onSurface.withValues(
              alpha: glass.isDark ? 0.16 : 0.10,
            ),
          ),
        ),
        child: LiquidGlassLens(
          style: glass.controlStyle(radius: size / 2),
          child: Padding(
            padding: EdgeInsets.symmetric(
              horizontal:
                  flexible ? 10 : (actions.length <= 1 ? 0 : horizontalPadding),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                for (var i = 0; i < actions.length; i++) ...[
                  if (i > 0) SizedBox(width: spacing),
                  if (flexible)
                    Flexible(child: Center(child: actions[i]))
                  else
                    SizedBox(
                      width: size,
                      height: size,
                      child: Center(child: actions[i]),
                    ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// 玻璃操作组里的一个图标按钮：让按钮的命中区与视觉尺寸一致。
class GlassActionButton extends StatelessWidget {
  const GlassActionButton({
    super.key,
    required this.icon,
    this.onPressed,
    this.size = 44,
    this.iconSize = 20,
    this.tooltip,
    this.semanticLabel,
    this.color,
  });

  final IconData icon;
  final VoidCallback? onPressed;
  final double size;
  final double iconSize;
  final String? tooltip;
  final String? semanticLabel;

  /// 图标颜色；默认取主题 `onSurface`。
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final button = IconButton(
      onPressed: onPressed,
      iconSize: iconSize,
      padding: EdgeInsets.zero,
      constraints: BoxConstraints.tight(Size.square(size)),
      icon: Icon(
        icon,
        size: iconSize,
        color: color ?? scheme.onSurface,
        semanticLabel: semanticLabel,
      ),
    );
    if (tooltip == null) return button;
    return Tooltip(message: tooltip!, child: button);
  }
}
