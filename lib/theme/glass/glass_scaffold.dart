import 'package:flutter/material.dart';
import 'package:liquid_glass_easy/liquid_glass_easy.dart';

import 'glass_theme.dart';
import 'glass_top_bar.dart';

/// 玻璃模式下页面内容需要预留的顶部内边距（状态栏 + 悬浮控件高度）。
///
/// 非玻璃模式返回 0：此时由 Material `AppBar` 自己占据高度。
double glassTopInset(BuildContext context, {double barHeight = 56}) {
  if (!context.glassTheme.enabled) return 0;
  return MediaQuery.paddingOf(context).top + barHeight;
}

/// 页面骨架：玻璃开启时提供「内容 + 悬浮功能层」，关闭时回落到 Material 3。
///
/// 内容层始终由调用方提供；这里只负责顶部的功能层以及滚动通知的处理，
/// 绝不把内容包进玻璃。
///
/// 使用约定：玻璃模式下页面内容需要自行把首个滚动容器的顶部内边距加到
/// [topBarHeight]，这样内容初始位于按钮下方，滚动时从按钮后方穿过。
class GlassScaffold extends StatefulWidget {
  const GlassScaffold({
    super.key,
    required this.title,
    required this.body,
    this.leading,
    this.actions = const [],
    this.alwaysShowTitle = true,
    this.floatingActionButton,
    this.bottomNavigationBar,
    this.backgroundColor,
    this.resizeToAvoidBottomInset,
    this.topBarHeight = 56,
    this.foregroundColor,
    this.actionsReservedWidth,
    this.showBackButton,
    this.insetBody = false,
    this.showScrollEdge = true,
    this.scrollEdgeColor,
    this.scrollEdgeFade = 24,
  });

  final String title;
  final Widget body;

  /// 左侧控件；为 `null` 且可返回时自动生成玻璃返回按钮。
  final Widget? leading;

  final List<Widget> actions;

  /// 标题是否常驻，默认 `true`。
  ///
  /// 只有聚合多功能的浏览型页面（智慧工大）才传 `false`，让标题随滚动
  /// 淡入淡出；其余页面标题始终可见，避免用户失去位置感。
  final bool alwaysShowTitle;

  final Widget? floatingActionButton;
  final Widget? bottomNavigationBar;
  final Color? backgroundColor;
  final bool? resizeToAvoidBottomInset;
  final double topBarHeight;

  /// 顶栏文字与图标颜色；默认跟随主题。压在深色内容上时传 `Colors.white`。
  final Color? foregroundColor;

  /// 操作组宽度；容纳 `TextButton` 等非图标动作时显式指定。
  final double? actionsReservedWidth;

  /// 是否显示返回按钮；为 `null` 时按 `Navigator.canPop()` 决定。
  final bool? showBackButton;

  /// 是否把 body 整体下移，避免被悬浮顶栏遮挡。
  ///
  /// 适用于 WebView、表单、loading 等不能「滚到玻璃下方」的页面；可滚动
  /// 页面应保持 `false`，改为在滚动容器 padding 里加 [glassTopInset]，
  /// 让内容穿过玻璃形成 scroll edge 效果。
  final bool insetBody;

  /// 顶栏背后是否叠一层滚动边缘色带（iOS 26 的 scroll edge 变体）。
  ///
  /// 色带夹在内容与顶栏之间：与顶边相接处完全不透明，向内容方向溶解，
  /// 给「滚到玻璃下方」的内容补上可读性。需要关闭的两种情况：
  /// * WebView 等原生视图——玻璃与色带都采样不到原生画面；
  /// * 相机预览等深色实拍画面——浅色带压上去会脏。
  ///
  /// [insetBody] 为真时自动跳过：内容本来就不从顶栏下方穿过，
  /// 叠一层只剩 backdrop 开销而没有收益。
  final bool showScrollEdge;

  /// 色带的峰值颜色；默认跟随页面底色（[backgroundColor] ?? `surface`）。
  final Color? scrollEdgeColor;

  /// 顶栏下沿之外多留的羽化尾巴，让过渡落在按钮下沿之外，
  /// 不会在圆钮正下方切出一条线。
  final double scrollEdgeFade;

  @override
  State<GlassScaffold> createState() => _GlassScaffoldState();
}

class _GlassScaffoldState extends State<GlassScaffold> {
  final ValueNotifier<bool> _revealed = ValueNotifier<bool>(false);

  @override
  void dispose() {
    _revealed.dispose();
    super.dispose();
  }

  bool _handleScroll(ScrollNotification notification) {
    // 只关心纵向滚动，横向（如课表周视图）不影响标题。
    if (notification.metrics.axis != Axis.vertical) return false;
    final pixels = notification.metrics.pixels;
    if (!_revealed.value && pixels > 12) {
      _revealed.value = true;
    } else if (_revealed.value && pixels < 6) {
      _revealed.value = false;
    }
    return false;
  }

  /// 顶栏背后的滚动边缘色带。
  ///
  /// 高度 = 状态栏 + 顶栏 + 羽化尾巴：前两段让顶栏区域足够实（内容滚过去时
  /// 不会和标题/按钮抢注意力），尾巴把过渡推到按钮下沿之外，避免在圆钮正
  /// 下方切出一条线。
  Widget? _buildScrollEdge(
    BuildContext context,
    ColorScheme scheme,
    AppGlassTheme glass,
  ) {
    if (!widget.showScrollEdge || widget.insetBody) {
      return null;
    }

    final double height =
        MediaQuery.paddingOf(context).top +
        widget.topBarHeight +
        widget.scrollEdgeFade;
    final Color tint = glass.scrollEdgeTint(
      widget.scrollEdgeColor ?? widget.backgroundColor ?? scheme.surface,
    );

    return Positioned(
      top: 0,
      left: 0,
      right: 0,
      // 包内 height 为 null 时会撑满父级约束，这里用 SizedBox 明确给高度。
      child: SizedBox(
        height: height,
        child: LiquidGlassScrollEdge(
          edge: LiquidGlassEdge.top,
          height: height,
          color: tint,
          // 模糊随通透度联动；算出太小就直接传 0，包会把 BackdropFilter
          // 整层摘掉，不为看不见的模糊付一次整屏读取。
          blur: glass.scrollEdgeBlurOrNull ?? 0,
          // soft：模糊羽化收边，与下方的锐利内容之间没有接缝。
          style: LiquidGlassScrollEdgeStyle.soft,
          curve: Curves.easeInOut,
          // 默认的 easeInQuart 会把模糊保留到色带末端，顶栏下方一大片发灰；
          // 顶栏场景要的是「离开顶栏就尽快清晰」。
          blurCurve: Curves.easeInOut,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final glass = context.glassTheme;
    final canPop = Navigator.of(context).canPop();

    if (!glass.enabled) {
      return Scaffold(
        backgroundColor: widget.backgroundColor,
        resizeToAvoidBottomInset: widget.resizeToAvoidBottomInset,
        appBar: AppBar(
          title: Text(widget.title),
          centerTitle: true,
          automaticallyImplyLeading: widget.showBackButton ?? true,
          leading: widget.leading,
          actions: widget.actions,
        ),
        body: widget.body,
        floatingActionButton: widget.floatingActionButton,
        bottomNavigationBar: widget.bottomNavigationBar,
      );
    }

    final showBack = widget.showBackButton ?? canPop;
    final Widget? leading =
        widget.leading ??
        (showBack && canPop
            ? GlassControlButton(
              icon: Icons.arrow_back_ios_new_rounded,
              tooltip: '返回',
              semanticLabel: '返回',
              color: widget.foregroundColor,
              onTap: () => Navigator.of(context).maybePop(),
            )
            : null);

    final Widget body =
        widget.insetBody
            ? Padding(
              padding: EdgeInsets.only(
                top: glassTopInset(context, barHeight: widget.topBarHeight),
              ),
              // 顶栏已经让出了状态栏，移除 MediaQuery 的顶部内边距，
              // 避免页面里的 SafeArea 再叠加一次。
              child: MediaQuery.removePadding(
                context: context,
                removeTop: true,
                child: widget.body,
              ),
            )
            : widget.body;

    final scheme = Theme.of(context).colorScheme;
    final Widget? scrollEdge = _buildScrollEdge(context, scheme, glass);

    return Scaffold(
      backgroundColor: widget.backgroundColor,
      resizeToAvoidBottomInset: widget.resizeToAvoidBottomInset,
      floatingActionButton: widget.floatingActionButton,
      bottomNavigationBar: widget.bottomNavigationBar,
      body: NotificationListener<ScrollNotification>(
        onNotification: _handleScroll,
        child: Stack(
          fit: StackFit.expand,
          children: [
            body,
            // 色带必须压在内容之上、顶栏之下：它只该改变玻璃「下面」的东西。
            if (scrollEdge != null) scrollEdge,
            Positioned(
              top: 0,
              left: 0,
              right: 0,
              child: GlassTopBar(
                title: widget.title,
                revealed: _revealed,
                leading: leading,
                actions: widget.actions,
                alwaysShowTitle: widget.alwaysShowTitle,
                height: widget.topBarHeight,
                foregroundColor: widget.foregroundColor,
                actionsReservedWidth: widget.actionsReservedWidth,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
