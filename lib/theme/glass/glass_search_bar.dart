import 'package:flutter/material.dart';
import 'package:liquid_glass_easy/liquid_glass_easy.dart';

import 'glass_theme.dart';

/// 悬浮在页面底部的玻璃搜索栏（iOS 工具栏搜索形态）。
///
/// 全宽圆角胶囊、贴底浮在内容之上，内容从它下方穿过；获得焦点时随键盘
/// 一起上移（由外层 `Scaffold` 的 `resizeToAvoidBottomInset` 驱动，不做
/// 自定义位移动画，保证与系统体验一致）。
///
/// 玻璃关闭时回落 Material 胶囊，形态保持不变，只是没有玻璃。
class GlassSearchBar extends StatelessWidget {
  const GlassSearchBar({
    super.key,
    required this.controller,
    this.focusNode,
    this.hintText = '搜索',
    this.onChanged,
    this.onSubmitted,
    this.onClear,
    this.height = 50,
  });

  final TextEditingController controller;
  final FocusNode? focusNode;
  final String hintText;
  final ValueChanged<String>? onChanged;
  final ValueChanged<String>? onSubmitted;
  final VoidCallback? onClear;
  final double height;

  @override
  Widget build(BuildContext context) {
    final glass = context.glassTheme;
    final scheme = Theme.of(context).colorScheme;
    final foreground = glass.enabled ? glass.foreground : scheme.onSurface;
    final muted =
        glass.enabled ? glass.foregroundMuted : scheme.onSurfaceVariant;

    final field = ValueListenableBuilder<TextEditingValue>(
      valueListenable: controller,
      builder: (context, value, _) {
        // 图标、输入框、清除按钮放在同一行，交给 Row 的 center 对齐——
        // 用 InputDecoration 的 prefix/suffixIcon 会让文字被图标高度顶偏。
        return Row(
          children: [
            const SizedBox(width: 14),
            Icon(Icons.search, size: 20, color: muted),
            const SizedBox(width: 8),
            Expanded(
              child: TextField(
                controller: controller,
                focusNode: focusNode,
                onChanged: onChanged,
                onSubmitted: onSubmitted,
                textInputAction: TextInputAction.search,
                textAlignVertical: TextAlignVertical.center,
                cursorColor: scheme.primary,
                style: TextStyle(fontSize: 15, color: foreground),
                decoration: InputDecoration(
                  isCollapsed: true,
                  isDense: true,
                  filled: false,
                  hintText: hintText,
                  hintStyle: TextStyle(fontSize: 15, color: muted),
                  border: InputBorder.none,
                  enabledBorder: InputBorder.none,
                  focusedBorder: InputBorder.none,
                  contentPadding: EdgeInsets.zero,
                ),
              ),
            ),
            if (value.text.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(left: 6, right: 10),
                child: InkResponse(
                  radius: 16,
                  onTap: () {
                    controller.clear();
                    onChanged?.call('');
                    onClear?.call();
                  },
                  child: Icon(Icons.cancel, size: 18, color: muted),
                ),
              )
            else
              const SizedBox(width: 14),
          ],
        );
      },
    );

    if (!glass.enabled) {
      return Container(
        height: height,
        decoration: BoxDecoration(
          color: scheme.surfaceContainer,
          borderRadius: BorderRadius.circular(height / 2),
        ),
        alignment: Alignment.center,
        child: field,
      );
    }

    return SizedBox(
      height: height,
      child: LiquidGlassLens(
        // 搜索栏长期停在内容之上，用弹层级的厚底色 + 更强模糊保证文字
        // 在任何背景上都读得清；边光是介于圆钮与底部栏之间的中间档。
        style: glass.searchBarStyle(radius: height / 2),
        child: Center(child: field),
      ),
    );
  }
}
