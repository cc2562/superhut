import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:liquid_glass_easy/liquid_glass_easy.dart';

/// 液态玻璃设计令牌。
///
/// 按 Apple Liquid Glass 规范，玻璃只用于「功能层」——导航栏、工具栏、
/// 弹层与控件；内容层（列表、卡片、表单）保持 Material 3 材质。因此这里
/// 只提供控件与 chrome 需要的样式，不提供任何内容面板样式。
///
/// 玻璃本身固定为中性白 / 烟灰黑，不随主题色染色；文字与图标颜色由
/// [foreground] / [foregroundMuted] 显式给出，避免依赖自适应采样。
@immutable
class AppGlassTheme extends ThemeExtension<AppGlassTheme> {
  const AppGlassTheme({
    required this.enabled,
    required this.brightness,
    this.tintStrength = 0.5,
  });

  /// 玻璃外观是否启用。为 `false` 时所有玻璃组件都应回落到 Material 实现，
  /// 且**不构建任何 lens**。
  final bool enabled;

  final Brightness brightness;

  /// 通透度：`0` 最通透（几乎只是折射），`1` 最有色调（更不透明、对比更强）。
  ///
  /// 由主题设置的「玻璃通透度」滑杆控制（透明 ↔ 色调），同时驱动底色的
  /// alpha 与背景模糊强度；`0.5` 等于改造前的默认观感。
  final double tintStrength;

  bool get isDark => brightness == Brightness.dark;

  /// 中性玻璃底色：浅色白、深色烟灰黑，alpha 随 [tintStrength] 线性变化。
  Color get tint {
    final alpha =
        isDark
            ? ui.lerpDouble(0.26, 0.54, tintStrength)!
            : ui.lerpDouble(0.16, 0.54, tintStrength)!;
    return (isDark ? const Color(0xFF000000) : const Color(0xFFFFFFFF))
        .withValues(alpha: alpha);
  }

  /// 弹层用的更厚一点的底色（保证压在任意内容上都能读出文字）。
  Color get elevatedTint {
    final alpha =
        isDark
            ? ui.lerpDouble(0.40, 0.72, tintStrength)!
            : ui.lerpDouble(0.30, 0.70, tintStrength)!;
    return (isDark ? const Color(0xFF000000) : const Color(0xFFFFFFFF))
        .withValues(alpha: alpha);
  }

  /// 模糊强度随通透度同向变化：越「色调」越雾化，越「透明」越清晰。
  ///
  /// 曲线是分段的，让三个档位都说得通：
  /// * `tintStrength == 0` 时只剩 [base] 的 6%，约等于「几乎不模糊」——
  ///   这是「透明」端该有的观感，能看清底下的内容；
  /// * `0.5`（默认）保持 [base] 原值，等于改造前的观感；
  /// * `1` 时放大到 1.8 倍，最「色调」的一档足够雾化、文字最稳。
  double blurFor(double base) {
    final double multiplier =
        tintStrength <= 0.5
            ? ui.lerpDouble(0.06, 1.0, tintStrength * 2)!
            : ui.lerpDouble(1.0, 1.8, (tintStrength - 0.5) * 2)!;
    return base * multiplier;
  }

  /// 玻璃上的主要前景色。
  Color get foreground =>
      isDark ? const Color(0xFFF2F2F7) : const Color(0xFF1B1B1F);

  /// 玻璃上的次要前景色（未选中图标、说明文字）。
  Color get foregroundMuted =>
      isDark ? const Color(0xB3EBEBF5) : const Color(0x991B1B1F);

  /// 选中胶囊 / 悬停高亮的底色。
  Color get selectionTint =>
      isDark ? const Color(0x33FFFFFF) : const Color(0x14000000);

  LiquidGlassLight get _specular => LiquidGlassLight.specular(
    thickness: 1.4,
    sharpness: 0.35,
    angle: 39,
    spread: 0.92,
    intensity: isDark ? 0.95 : 1,
  );

  LiquidGlassLight get _glow => LiquidGlassLight.glow(
    thickness: 7,
    angle: 129,
    spread: 0.6,
    intensity: isDark ? 0.45 : 0.6,
  );

  /// 顶部栏控件用的玻璃：44×44 圆形（[radius] 22）或同高的椭圆胶囊。
  ///
  /// [withShadow] 控制是否带接触投影：悬浮在内容上的圆按钮需要它来分层，
  /// 而排在同一平面里的分段控件不要——那圈投影会在控件周围留一条灰边。
  LiquidGlassStyle controlStyle({double radius = 22, bool withShadow = true}) =>
      LiquidGlassStyle(
        shape: LiquidGlassShape.continuousRoundedRectangle(
          cornerRadius: radius,
        ),
        specular: _specular,
        glow: _glow,
        refractionIndex: 1.03,
        refractionWidth: 12,
        blur: blurFor(4),
        color: tint,
        shadow:
            withShadow
                ? LiquidGlassShadow(
                  blur: 12,
                  opacity: isDark ? 0.34 : 0.14,
                  inset: 2,
                )
                : null,
      );

  /// 底部标签栏胶囊：形状交给组件按高度派生全胶囊。
  ///
  /// 不投影——与 iOS 原生底部栏一致，只用一层发丝描边勾出轮廓（描边由
  /// 页面侧叠加，见 `homeview` 的标签栏描边层）。
  LiquidGlassStyle get tabBarStyle => LiquidGlassStyle(
    specular: _specular,
    glow: _glow,
    refractionIndex: 1.04,
    refractionWidth: 14,
    blur: blurFor(5),
    color: tint,
  );

  LiquidGlassTabItemStyle get tabItemStyle => LiquidGlassTabItemStyle(
    selectedColor: foreground,
    unselectedColor: foregroundMuted,
    iconSize: 24,
    labelFontSize: 10.5,
    selectedFontWeight: FontWeight.w600,
    unselectedFontWeight: FontWeight.w500,
  );

  /// 底部标签栏图标配色：选中跟随主题 primary，未选中用次要前景色。
  ///
  /// 与 [tabItemStyle] 的中性版本并存——中性版本用于不希望被主题色染色的
  /// 场景（如深色相机预览上的浮层）。
  LiquidGlassTabItemStyle tabItemStyleOf(ColorScheme scheme) =>
      LiquidGlassTabItemStyle(
        selectedColor: scheme.primary,
        unselectedColor: scheme.onSurfaceVariant,
        iconSize: 24,
        labelFontSize: 10.5,
        selectedFontWeight: FontWeight.w600,
        unselectedFontWeight: FontWeight.w500,
      );

  LiquidGlassTabPillStyle get tabPillStyle => LiquidGlassTabPillStyle(
    // 只有 Impeller 上才用折射 pill；Skia/Web 退化为普通胶囊，避免黑块。
    mode: LiquidGlassPillMode.impellerOnly,
    animated: true,
    animationDuration: const Duration(milliseconds: 300),
    animationCurve: Curves.easeOutCubic,
    color: selectionTint,
    blur: 0,
    growHeight: 6,
    refractionIndex: 1.025,
    refractionWidth: 10,
  );

  /// 对话框面板。
  LiquidGlassStyle get dialogStyle => LiquidGlassStyle(
    shape: LiquidGlassShape.continuousRoundedRectangle(cornerRadius: 28),
    specular: _specular,
    glow: _glow,
    refractionIndex: 1.03,
    refractionWidth: 14,
    blur: blurFor(6),
    color: elevatedTint,
    shadow: LiquidGlassShadow(blur: 24, opacity: isDark ? 0.45 : 0.2, inset: 0),
  );

  /// 锚定菜单面板：比对话框更小的圆角与更轻的投影。
  LiquidGlassStyle get menuStyle => LiquidGlassStyle(
    shape: LiquidGlassShape.continuousRoundedRectangle(cornerRadius: 18),
    specular: _specular,
    glow: _glow,
    refractionIndex: 1.03,
    refractionWidth: 10,
    blur: blurFor(5),
    color: elevatedTint,
    shadow: LiquidGlassShadow(
      blur: 20,
      opacity: isDark ? 0.42 : 0.18,
      inset: 0,
    ),
  );

  /// 底部弹层面板。
  LiquidGlassStyle get sheetStyle => LiquidGlassStyle(
    shape: LiquidGlassShape.continuousRoundedRectangle(cornerRadius: 28),
    specular: _specular,
    glow: _glow,
    refractionIndex: 1.03,
    refractionWidth: 14,
    blur: blurFor(6),
    color: elevatedTint,
    shadow: LiquidGlassShadow(
      blur: 26,
      opacity: isDark ? 0.45 : 0.18,
      inset: 0,
    ),
  );

  @override
  AppGlassTheme copyWith({
    bool? enabled,
    Brightness? brightness,
    double? tintStrength,
  }) {
    return AppGlassTheme(
      enabled: enabled ?? this.enabled,
      brightness: brightness ?? this.brightness,
      tintStrength: tintStrength ?? this.tintStrength,
    );
  }

  /// 样式对象本身不可插值，主题切换时按中点直接取一侧，避免中间态出现
  /// 半套玻璃令牌；通透度是标量，可以连续插值。
  @override
  AppGlassTheme lerp(covariant AppGlassTheme? other, double t) {
    if (other == null) return this;
    final pickOther = t >= 0.5;
    return AppGlassTheme(
      enabled: pickOther ? other.enabled : enabled,
      brightness: pickOther ? other.brightness : brightness,
      tintStrength: ui.lerpDouble(tintStrength, other.tintStrength, t)!,
    );
  }
}

extension AppGlassThemeContext on BuildContext {
  /// 当前主题的玻璃令牌；主题未注入时返回一个「关闭」的占位实例。
  AppGlassTheme get glassTheme {
    return Theme.of(this).extension<AppGlassTheme>() ??
        AppGlassTheme(enabled: false, brightness: Theme.of(this).brightness);
  }

  bool get glassEnabled => glassTheme.enabled;
}
