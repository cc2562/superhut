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
  const AppGlassTheme({required this.enabled, required this.brightness});

  /// 玻璃外观是否启用。为 `false` 时所有玻璃组件都应回落到 Material 实现，
  /// 且**不构建任何 lens**。
  final bool enabled;

  final Brightness brightness;

  bool get isDark => brightness == Brightness.dark;

  /// 中性玻璃底色：浅色 35% 白、深色 40% 烟灰黑。
  Color get tint => isDark ? const Color(0x66000000) : const Color(0x59FFFFFF);

  /// 弹层用的更厚一点的底色（保证压在任意内容上都能读出文字）。
  Color get elevatedTint =>
      isDark ? const Color(0x8F000000) : const Color(0x80FFFFFF);

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

  LiquidGlassShadow get _contactShadow => LiquidGlassShadow(
    blur: 12,
    opacity: isDark ? 0.34 : 0.14,
    inset: 2,
  );

  /// 顶部栏控件用的玻璃：44×44 圆形（[radius] 22）或同高的椭圆胶囊。
  LiquidGlassStyle controlStyle({double radius = 22}) => LiquidGlassStyle(
    shape: LiquidGlassShape.continuousRoundedRectangle(cornerRadius: radius),
    specular: _specular,
    glow: _glow,
    refractionIndex: 1.03,
    refractionWidth: 12,
    blur: 4,
    color: tint,
    shadow: _contactShadow,
  );

  /// 底部标签栏胶囊：形状交给组件按高度派生全胶囊。
  LiquidGlassStyle get tabBarStyle => LiquidGlassStyle(
    specular: _specular,
    glow: _glow,
    refractionIndex: 1.04,
    refractionWidth: 14,
    blur: 5,
    color: tint,
    shadow: LiquidGlassShadow(
      blur: 18,
      opacity: isDark ? 0.4 : 0.16,
      inset: 0,
    ),
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
    blur: 6,
    color: elevatedTint,
    shadow: LiquidGlassShadow(
      blur: 24,
      opacity: isDark ? 0.45 : 0.2,
      inset: 0,
    ),
  );

  /// 锚定菜单面板：比对话框更小的圆角与更轻的投影。
  LiquidGlassStyle get menuStyle => LiquidGlassStyle(
    shape: LiquidGlassShape.continuousRoundedRectangle(cornerRadius: 18),
    specular: _specular,
    glow: _glow,
    refractionIndex: 1.03,
    refractionWidth: 10,
    blur: 5,
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
    blur: 6,
    color: elevatedTint,
    shadow: LiquidGlassShadow(
      blur: 26,
      opacity: isDark ? 0.45 : 0.18,
      inset: 0,
    ),
  );

  @override
  AppGlassTheme copyWith({bool? enabled, Brightness? brightness}) {
    return AppGlassTheme(
      enabled: enabled ?? this.enabled,
      brightness: brightness ?? this.brightness,
    );
  }

  /// 样式对象本身不可插值，主题切换时按中点直接取一侧，避免中间态出现
  /// 半套玻璃令牌。
  @override
  AppGlassTheme lerp(covariant AppGlassTheme? other, double t) {
    if (other == null) return this;
    return t < 0.5 ? this : other;
  }
}

extension AppGlassThemeContext on BuildContext {
  /// 当前主题的玻璃令牌；主题未注入时返回一个「关闭」的占位实例。
  AppGlassTheme get glassTheme {
    return Theme.of(this).extension<AppGlassTheme>() ??
        AppGlassTheme(
          enabled: false,
          brightness: Theme.of(this).brightness,
        );
  }

  bool get glassEnabled => glassTheme.enabled;
}
