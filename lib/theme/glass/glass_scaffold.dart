import 'package:flutter/material.dart';

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
    this.alwaysShowTitle = false,
    this.floatingActionButton,
    this.bottomNavigationBar,
    this.backgroundColor,
    this.resizeToAvoidBottomInset,
    this.topBarHeight = 56,
    this.foregroundColor,
    this.actionsReservedWidth,
    this.showBackButton,
    this.insetBody = false,
  });

  final String title;
  final Widget body;

  /// 左侧控件；为 `null` 且可返回时自动生成玻璃返回按钮。
  final Widget? leading;

  final List<Widget> actions;

  /// 页面不可滚动时让标题常驻。
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
