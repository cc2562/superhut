import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'course_table_style.dart';

/// 课表页的整页背景层：纯色 → 图片（不透明度 / 模糊）→ 明暗遮罩。
///
/// 它由首页外壳铺在 `PageView` 之下，因此会自然延伸到状态栏区域、悬浮
/// 顶栏与底部标签栏的下方——这正是「背景覆盖整页」的实现方式。
class CourseTableBackground extends StatelessWidget {
  const CourseTableBackground({
    super.key,
    required this.style,
    required this.scheme,
  });

  final CourseTableStyle style;

  /// 页面「原本」的配色。
  ///
  /// 深色背景时上层内容会切到深色主题，但背景本身必须仍按用户设定的
  /// 主题配色取底色，否则会与设置页预览不一致。
  final ColorScheme scheme;

  @override
  Widget build(BuildContext context) {
    final Color base = style.pageColor(scheme);
    final double brightness = style.imageBrightness.clamp(-1.0, 1.0);

    final List<Widget> layers = <Widget>[
      ColoredBox(color: base, child: const SizedBox.expand()),
    ];
    if (style.hasImage) {
      layers.add(_BackgroundImage(style: style));
      if (brightness != 0) {
        layers.add(
          DecoratedBox(
            decoration: BoxDecoration(
              color: (brightness < 0 ? Colors.black : Colors.white).withValues(
                alpha: brightness.abs() * 0.72,
              ),
            ),
          ),
        );
      }
    }

    // 底图变暗后状态栏图标要跟着转白，否则在深色照片上一片看不见。
    final bool darkBackground =
        style.estimatedPageColor(scheme).computeLuminance() < 0.45;

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness:
            darkBackground ? Brightness.light : Brightness.dark,
        statusBarBrightness:
            darkBackground ? Brightness.dark : Brightness.light,
      ),
      child: Stack(fit: StackFit.expand, children: layers),
    );
  }
}

/// 背景图片层：限制解码尺寸，模糊时放大一点避免边缘透色。
class _BackgroundImage extends StatelessWidget {
  const _BackgroundImage({required this.style});

  final CourseTableStyle style;

  @override
  Widget build(BuildContext context) {
    final double opacity = style.imageOpacity.clamp(0.0, 1.0);
    if (opacity <= 0) return const SizedBox.shrink();

    final MediaQueryData? media = MediaQuery.maybeOf(context);
    final double logicalWidth = media?.size.width ?? 420;
    final double pixelRatio = media?.devicePixelRatio ?? 2;
    // 12MP 原图整幅解码要吃几十 MB 内存，按屏幕物理宽度降采样即可。
    final int cacheWidth = (logicalWidth * pixelRatio).round().clamp(480, 2560);

    Widget image = Image.file(
      File(style.backgroundImagePath!),
      fit: BoxFit.cover,
      cacheWidth: cacheWidth,
      gaplessPlayback: true,
      // 文件被清理 / 解码失败时不摆错误图标，静默露出下层纯色。
      errorBuilder: (_, _, _) => const SizedBox.shrink(),
    );

    final double blur = style.imageBlur.clamp(
      0.0,
      CourseTableStyle.maxImageBlur,
    );
    if (blur > 0) {
      image = ClipRect(
        child: Transform.scale(
          // 模糊会把四周像素向外摊开，放大一点让边缘不露出透明缝。
          scale: 1.08,
          child: ImageFiltered(
            imageFilter: ui.ImageFilter.blur(sigmaX: blur, sigmaY: blur),
            child: image,
          ),
        ),
      );
    }

    if (opacity >= 1) return image;
    return Opacity(opacity: opacity, child: image);
  }
}
