import 'package:flutter/material.dart';
import 'package:liquid_glass_easy/liquid_glass_easy.dart';

import 'glass_theme.dart';

/// 玻璃弹窗。玻璃关闭或平台不支持时回落到 Material 的 [AlertDialog]。
Future<T?> showGlassDialog<T>({
  required BuildContext context,
  Widget? title,
  Widget? content,
  List<Widget>? actions,
  bool barrierDismissible = true,
}) {
  final glass = context.glassTheme;

  if (!glass.enabled) {
    return showDialog<T>(
      context: context,
      barrierDismissible: barrierDismissible,
      builder:
          (context) =>
              AlertDialog(title: title, content: content, actions: actions),
    );
  }

  final textTheme = Theme.of(context).textTheme;
  return showLiquidGlassDialog<T>(
    context: context,
    barrierDismissible: barrierDismissible,
    builder:
        (context) => LiquidGlassAlertDialog(
          style: glass.dialogStyle,
          title: title,
          content: content,
          actions: actions,
          actionsPadding: const EdgeInsets.only(top: 4),
          titleTextStyle: textTheme.titleLarge?.copyWith(
            color: glass.foreground,
            fontWeight: FontWeight.w600,
          ),
          contentTextStyle: textTheme.bodyMedium?.copyWith(
            color: glass.foregroundMuted,
            height: 1.55,
          ),
        ),
  );
}

/// 玻璃底部弹层（高度由内容决定或由 [isScrollControlled] 放开）。
Future<T?> showGlassSheet<T>({
  required BuildContext context,
  required WidgetBuilder builder,
  Widget? header,
  EdgeInsets? padding,
  BoxConstraints? constraints,
  bool isScrollControlled = false,
  bool showDragHandle = true,
}) {
  final glass = context.glassTheme;

  if (!glass.enabled) {
    return showModalBottomSheet<T>(
      context: context,
      isScrollControlled: isScrollControlled,
      showDragHandle: showDragHandle,
      constraints: constraints,
      builder: builder,
    );
  }

  return showLiquidGlassSheet<T>(
    context: context,
    isScrollControlled: isScrollControlled,
    constraints: constraints,
    style: glass.sheetStyle,
    foregroundColor: glass.foreground,
    header: header,
    grabber: showDragHandle,
    padding: padding ?? const EdgeInsets.fromLTRB(20, 4, 20, 20),
    builder: builder,
  );
}

/// 高度可随拖拽变化的玻璃弹层。
///
/// 官方要求：需要 resize 的 sheet 用 `showModalBottomSheet` +
/// `DraggableScrollableSheet`，并在其 builder 内放**裸的** [LiquidGlassSheet]，
/// 玻璃必须处在被 resize 的范围内。
Future<void> showGlassDraggableSheet({
  required BuildContext context,
  required Widget Function(BuildContext context, ScrollController controller)
  bodyBuilder,
  double initialChildSize = 0.52,
  double minChildSize = 0.35,
  double maxChildSize = 0.85,
}) {
  final glass = context.glassTheme;

  if (!glass.enabled) {
    return showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      builder:
          (context) => SafeArea(
            child: DraggableScrollableSheet(
              expand: false,
              initialChildSize: initialChildSize,
              minChildSize: minChildSize,
              maxChildSize: maxChildSize,
              builder:
                  (context, controller) => bodyBuilder(context, controller),
            ),
          ),
    );
  }

  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    elevation: 0,
    barrierColor: Colors.black26,
    builder:
        (context) => DraggableScrollableSheet(
          expand: false,
          initialChildSize: initialChildSize,
          minChildSize: minChildSize,
          maxChildSize: maxChildSize,
          builder:
              (context, controller) => LiquidGlassSheet(
                style: glass.sheetStyle,
                foregroundColor: glass.foreground,
                // 内容自带内边距，玻璃只负责表面与拖拽条。
                padding: EdgeInsets.zero,
                child: bodyBuilder(context, controller),
              ),
        ),
  );
}
