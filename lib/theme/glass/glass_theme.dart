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

  /// 滚动边缘色带的峰值颜色：直接取页面底色，只把 alpha 提到接近不透明。
  ///
  /// 不用文档默认的 `0x8A000000`（固定深色压暗）——那是给深色内容的，浅色
  /// 页面上会压出一条灰黑带。跟底色等价于「内容滚到顶栏下方时淡回背景」，
  /// 也就是 iOS 26 scroll edge 在浅色界面里的观感。
  Color scrollEdgeTint(Color pageColor) =>
      pageColor.withValues(alpha: isDark ? 0.92 : 0.98);

  /// 滚动边缘色带的背景模糊，跟随通透度滑杆同向变化。
  ///
  /// `tintStrength = 0` 时算出约 0.36——这种量级的模糊肉眼看不出，却要为它
  /// 付一次整屏 backdrop 读取，所以宿主页面会按 [scrollEdgeBlurOrNull] 归零。
  double get scrollEdgeBlur => blurFor(6);

  /// 给 `LiquidGlassScrollEdge.blur` 用的值：太小就返回 `null`，
  /// 让调用方传 0，包会把整层 `BackdropFilter` 从树里摘掉。
  double? get scrollEdgeBlurOrNull =>
      scrollEdgeBlur < 0.5 ? null : scrollEdgeBlur;

  /// 高光（锐利亮带）。
  ///
  /// 苹果官方稿里不同部件的边光强度差得很远：44pt 圆钮几乎只剩一条发丝
  /// 描边，底部栏只有顶边微微一亮，搜索框介于两者之间。参数收在这里按部件
  /// 给值，不在各组件里散着写，免得又调成一条「霓虹描边」。
  LiquidGlassLight _specularLight({
    required double thickness,
    required double intensity,
    double sharpness = 0.4,
    double angle = 39,
    double spread = 0.85,
    double opposite = 0.2,
  }) => LiquidGlassLight.specular(
    thickness: thickness,
    sharpness: sharpness,
    angle: angle,
    spread: spread,
    intensity: intensity,
    oppositeIntensity: opposite,
  );

  /// 辉光（宽软侧带）。显式给低 alpha 白色：不给色的话这盏灯只拾取背景色
  /// 再提亮，纯白页面上拾取到的还是白，等于没开灯。
  LiquidGlassLight _glowLight({
    required double thickness,
    required double intensity,
    double angle = 129,
    double spread = 0.95,
    double opposite = 0.3,
    double alpha = 0.10,
  }) => LiquidGlassLight.glow(
    thickness: thickness,
    angle: angle,
    spread: spread,
    intensity: intensity,
    oppositeIntensity: opposite,
    color: Colors.white.withValues(alpha: alpha),
  );

  /// 44pt 圆钮 / 分段控件 / 课程卡：苹果在浅色页面上几乎只画描边，
  /// 灯压到最低，只求「有一点点边」而不是「发光」。
  LiquidGlassLight get _buttonSpecular => _specularLight(
    thickness: 1,
    intensity: isDark ? 0.5 : 0.55,
    spread: 0.8,
    opposite: 0.15,
  );

  LiquidGlassLight get _buttonGlow =>
      _glowLight(thickness: 5, intensity: isDark ? 0.18 : 0.2, alpha: 0.07);

  /// 底部栏：面积大且贴地，苹果只让**顶边**微亮、两侧几乎平掉，
  /// 所以轴走 `90°`（上下），对侧（底边）只留 22%。
  LiquidGlassLight get _barSpecular => _specularLight(
    thickness: 1.6,
    sharpness: 0.45,
    angle: 90,
    spread: 0.72,
    intensity: isDark ? 0.5 : 0.68,
    opposite: 0.22,
  );

  LiquidGlassLight get _barGlow => _glowLight(
    thickness: 9,
    angle: 0,
    intensity: isDark ? 0.2 : 0.24,
    alpha: 0.08,
  );

  /// 搜索框：比圆钮亮一档，但不做整圈——仍只有顶边有光。
  LiquidGlassLight get _fieldSpecular => _specularLight(
    thickness: 1.2,
    angle: 90,
    spread: 0.78,
    intensity: isDark ? 0.5 : 0.62,
    opposite: 0.18,
  );

  LiquidGlassLight get _fieldGlow => _glowLight(
    thickness: 6,
    angle: 0,
    intensity: isDark ? 0.2 : 0.22,
    alpha: 0.07,
  );

  /// 弹层大面板：靠灯自己勾边（没有页面侧描边），可以比圆钮略强一点。
  LiquidGlassLight get _panelSpecular => _specularLight(
    thickness: 1.4,
    spread: 0.9,
    intensity: isDark ? 0.6 : 0.7,
    opposite: 0.3,
  );

  LiquidGlassLight get _panelGlow =>
      _glowLight(thickness: 8, intensity: isDark ? 0.26 : 0.28, alpha: 0.09);

  /// 顶部栏控件用的玻璃：44×44 圆形（[radius] 22）或同高的椭圆胶囊。
  ///
  /// [withShadow] 控制是否带接触投影：悬浮在内容上的圆按钮需要它来分层，
  /// 而排在同一平面里的分段控件不要——那圈投影会在控件周围留一条灰边。
  LiquidGlassStyle controlStyle({double radius = 22, bool withShadow = true}) =>
      LiquidGlassStyle(
        shape: LiquidGlassShape.continuousRoundedRectangle(
          cornerRadius: radius,
        ),
        specular: _buttonSpecular,
        glow: _buttonGlow,
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

  /// 悬浮搜索栏：底色比圆钮厚（长期压着内容），模糊也更强，边光取中间档。
  LiquidGlassStyle searchBarStyle({double radius = 26}) => LiquidGlassStyle(
    shape: LiquidGlassShape.continuousRoundedRectangle(cornerRadius: radius),
    specular: _fieldSpecular,
    glow: _fieldGlow,
    refractionIndex: 1.03,
    refractionWidth: 12,
    blur: blurFor(9),
    color: elevatedTint,
    shadow: LiquidGlassShadow(
      blur: 16,
      opacity: isDark ? 0.36 : 0.16,
      inset: 2,
    ),
  );

  /// 底部标签栏胶囊：形状交给组件按高度派生全胶囊。
  ///
  /// 不投影——与 iOS 原生底部栏一致，只用一层发丝描边勾出轮廓（描边由
  /// 页面侧叠加，见 `homeview` 的标签栏描边层）。
  LiquidGlassStyle get tabBarStyle => LiquidGlassStyle(
    specular: _barSpecular,
    glow: _barGlow,
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
    specular: _panelSpecular,
    glow: _panelGlow,
    refractionIndex: 1.03,
    refractionWidth: 14,
    blur: blurFor(6),
    color: elevatedTint,
    shadow: LiquidGlassShadow(blur: 24, opacity: isDark ? 0.45 : 0.2, inset: 0),
  );

  /// 锚定菜单面板：比对话框更小的圆角与更轻的投影。
  LiquidGlassStyle get menuStyle => LiquidGlassStyle(
    shape: LiquidGlassShape.continuousRoundedRectangle(cornerRadius: 18),
    specular: _panelSpecular,
    glow: _panelGlow,
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
    specular: _panelSpecular,
    glow: _panelGlow,
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
