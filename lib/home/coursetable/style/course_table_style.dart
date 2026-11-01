import 'package:flutter/material.dart';

/// 课程块材质。
enum CourseCardMaterial {
  solid('纯色', '课程块只铺一层课程色；不透明度为 0 时完全不显示底色'),
  frosted('毛玻璃', '课程块把身后的背景雾化，适合搭配图片背景'),
  liquidGlass('液态玻璃', '带折射与高光的玻璃课程块，需开启液态玻璃外观');

  const CourseCardMaterial(this.label, this.description);

  final String label;
  final String description;

  static CourseCardMaterial parse(String? value) => values.firstWhere(
    (material) => material.name == value,
    orElse: () => CourseCardMaterial.solid,
  );
}

/// 课程块文字颜色策略。
enum CourseTextColorMode {
  adaptive('自适应', '按课程色与页面底色的对比度自动选深字或白字'),
  white('白字', '始终使用白色文字'),
  black('黑字', '始终使用接近纯黑的文字');

  const CourseTextColorMode(this.label, this.description);

  final String label;
  final String description;

  static CourseTextColorMode parse(String? value) => values.firstWhere(
    (mode) => mode.name == value,
    orElse: () => CourseTextColorMode.adaptive,
  );
}

/// 课表外观在 `SharedPreferences` 里的键名。
class CourseTableStyleKeys {
  const CourseTableStyleKeys._();

  static const String prefix = 'courseTableStyle.';
  static const String backgroundColor = '${prefix}backgroundColor';
  static const String imagePath = '${prefix}imagePath';
  static const String imageOpacity = '${prefix}imageOpacity';
  static const String imageBlur = '${prefix}imageBlur';
  static const String imageBrightness = '${prefix}imageBrightness';
  static const String cardOpacity = '${prefix}cardOpacity';
  static const String cardMaterial = '${prefix}cardMaterial';
  static const String cardBlur = '${prefix}cardBlur';
  static const String cardColorful = '${prefix}cardColorful';
  static const String textColor = '${prefix}textColor';
}

/// 课表页的全部可自定义外观参数。
///
/// 这是一个不可变值对象：控制器持有一份实例，页面只读，所有修改都走
/// [copyWith] 生成新实例，方便「拖动预览 → 松手提交」这类两段式交互。
///
/// 默认值刻意等价于引入本功能之前的观感：背景跟随主题 surface、无图片、
/// 课程块 82% 不透明度纯色、文字自适应。
@immutable
class CourseTableStyle {
  const CourseTableStyle({
    this.backgroundColor,
    this.backgroundImagePath,
    this.imageOpacity = 1.0,
    this.imageBlur = 0.0,
    this.imageBrightness = 0.0,
    this.cardOpacity = 0.82,
    this.material = CourseCardMaterial.solid,
    this.cardBlur = 12,
    this.colorful = true,
    this.textColor = CourseTextColorMode.adaptive,
  });

  /// 出厂默认值。
  static const CourseTableStyle defaults = CourseTableStyle();

  /// 图片模糊的可调上限（sigma）。再高就只剩一团色块，文件解码也没意义。
  static const double maxImageBlur = 30;

  /// 课程块毛玻璃模糊的可调上限（sigma）。
  ///
  /// 比背景图更放开：课程块面积小、贴身距离近，重雾化更像真实磨砂玻璃；
  /// 60 已经接近「只剩一层雾、看不出底下是什么」，再高只是白付离屏开销。
  static const double maxCardBlur = 60;

  /// 自适应文字判据：合成后底色亮度高于该值用深字，否则用白字。
  static const double _adaptiveThreshold = 0.45;

  /// 深色文字颜色，与主题中性前景色一致。
  static const Color _darkText = Color(0xFF1B1B1F);

  /// 背景纯色；`null` 表示跟随主题 `colorScheme.surface`。
  final Color? backgroundColor;

  /// 背景图片在应用私有目录里的绝对路径；`null` 表示不用图片。
  final String? backgroundImagePath;

  /// 图片不透明度（0–1）。
  final double imageOpacity;

  /// 图片模糊 sigma（0–[maxImageBlur]）。
  final double imageBlur;

  /// 明暗补偿（-1 变暗 – 1 变亮）。
  final double imageBrightness;

  /// 课程块底色不透明度（0–1），0 时纯色材质完全不画底色。
  ///
  /// 关闭 [colorful] 后它表示白（浅色页面）/ 黑（深色页面）蒙版的浓度：
  /// 0 完全透明、1 整体变白或变黑。
  final double cardOpacity;

  final CourseCardMaterial material;

  /// 毛玻璃材质的模糊 sigma（0–[maxCardBlur]）。
  ///
  /// 默认 12 与参数化之前写死的值一致，老用户升级后观感不变。
  final double cardBlur;

  /// 课程块是否保留课程色。
  ///
  /// 关闭后所有课程块不再区分颜色，只铺一层白/黑蒙版（浓度见 [cardOpacity]）；
  /// 文字仍按蒙版与页面底色合成后的实际亮度自适应。
  final bool colorful;

  final CourseTextColorMode textColor;

  bool get hasImage => (backgroundImagePath ?? '').isNotEmpty;

  /// 是否启用过任何背景自定义（决定「恢复默认」是否可点、预览是否显示角标）。
  bool get hasCustomBackground => backgroundColor != null || hasImage;

  /// 背景基底色：有自定义纯色就用它，否则跟随主题。
  Color pageColor(ColorScheme scheme) => backgroundColor ?? scheme.surface;

  /// 页面「平均色」估算，用于课程块的自适应文字。
  ///
  /// 纯色背景可以精确取值；有图片时图片平均亮度未知，按中灰近似后再叠加
  /// 明暗参数——自适应文字只需要一个足够接近的判断依据，不必真的采样图片。
  Color estimatedPageColor(ColorScheme scheme) {
    final base = pageColor(scheme);
    if (!hasImage) return base;
    const Color imageAverage = Color(0xFF7A7A7A);
    final withImage = Color.alphaBlend(
      imageAverage.withValues(alpha: imageOpacity.clamp(0.0, 1.0) * 0.85),
      base,
    );
    final double value = imageBrightness.clamp(-1.0, 1.0);
    if (value == 0) return withImage;
    return Color.alphaBlend(
      (value < 0 ? Colors.black : Colors.white).withValues(
        alpha: value.abs() * 0.72,
      ),
      withImage,
    );
  }

  /// 非彩色模式下的蒙版颜色：页面偏亮铺纯白、偏暗铺纯黑。
  ///
  /// 判据是 [estimatedPageColor]（已含背景纯色、背景图与明暗补偿），也就是
  /// 文字自适应用的同一个「页面实际底色」。两处同源，关掉彩色后不会出现
  /// 「蒙版是白的、文字却按白底选了白字」这类糊在一起的情况。
  Color _monochromeBase(Color pageEstimate) =>
      pageEstimate.computeLuminance() > _adaptiveThreshold
          ? Colors.white
          : Colors.black;

  /// 课程块基底色（不含用户设定的不透明度）。
  ///
  /// 彩色模式直接是课程色；非彩色模式是一层无色蒙版，靠白/黑把课程块
  /// 从背景里拎出来——很浅的页面铺白、很深的页面铺黑，两个方向都是「提亮」。
  Color cardBaseColor(Color accent, {required Color pageEstimate}) =>
      colorful ? accent : _monochromeBase(pageEstimate);

  /// 课程块底色（基底色 + 用户设定的不透明度）。
  Color cardTint(Color accent, {required Color pageEstimate}) =>
      cardBaseColor(
        accent,
        pageEstimate: pageEstimate,
      ).withValues(alpha: cardOpacity.clamp(0.0, 1.0));

  /// 课程块文字颜色。
  ///
  /// 自适应会把「课程色按当前不透明度合成到页面底色上」的结果当作实际背景，
  /// 因此把不透明度拉到很低时文字不会糊进背景里。
  Color courseForeground(Color accent, {required Color pageEstimate}) {
    switch (textColor) {
      case CourseTextColorMode.white:
        return Colors.white;
      case CourseTextColorMode.black:
        return _darkText;
      case CourseTextColorMode.adaptive:
        final blended = Color.alphaBlend(
          cardTint(accent, pageEstimate: pageEstimate),
          pageEstimate,
        );
        return blended.computeLuminance() > _adaptiveThreshold
            ? _darkText
            : Colors.white;
    }
  }

  /// 课程块次要文字（地点、教师）的颜色。
  Color courseSecondaryForeground(
    Color accent, {
    required Color pageEstimate,
  }) => courseForeground(
    accent,
    pageEstimate: pageEstimate,
  ).withValues(alpha: 0.82);

  static const Object _unset = Object();

  /// 复制并覆盖若干字段；传入 `null` 表示「清空」该字段（背景色 / 背景图）。
  CourseTableStyle copyWith({
    Object? backgroundColor = _unset,
    Object? backgroundImagePath = _unset,
    double? imageOpacity,
    double? imageBlur,
    double? imageBrightness,
    double? cardOpacity,
    CourseCardMaterial? material,
    double? cardBlur,
    bool? colorful,
    CourseTextColorMode? textColor,
  }) {
    return CourseTableStyle(
      backgroundColor:
          identical(backgroundColor, _unset)
              ? this.backgroundColor
              : backgroundColor as Color?,
      backgroundImagePath:
          identical(backgroundImagePath, _unset)
              ? this.backgroundImagePath
              : backgroundImagePath as String?,
      imageOpacity: (imageOpacity ?? this.imageOpacity).clamp(0.0, 1.0),
      imageBlur: (imageBlur ?? this.imageBlur).clamp(0.0, maxImageBlur),
      imageBrightness: (imageBrightness ?? this.imageBrightness).clamp(
        -1.0,
        1.0,
      ),
      cardOpacity: (cardOpacity ?? this.cardOpacity).clamp(0.0, 1.0),
      material: material ?? this.material,
      cardBlur: (cardBlur ?? this.cardBlur).clamp(0.0, maxCardBlur),
      colorful: colorful ?? this.colorful,
      textColor: textColor ?? this.textColor,
    );
  }

  /// 落盘用的键值对；`null` 值表示应该删除该键。
  Map<String, Object?> encode() => <String, Object?>{
    CourseTableStyleKeys.backgroundColor: backgroundColor?.toARGB32(),
    CourseTableStyleKeys.imagePath: hasImage ? backgroundImagePath : null,
    CourseTableStyleKeys.imageOpacity: imageOpacity,
    CourseTableStyleKeys.imageBlur: imageBlur,
    CourseTableStyleKeys.imageBrightness: imageBrightness,
    CourseTableStyleKeys.cardOpacity: cardOpacity,
    CourseTableStyleKeys.cardMaterial: material.name,
    CourseTableStyleKeys.cardBlur: cardBlur,
    CourseTableStyleKeys.cardColorful: colorful,
    CourseTableStyleKeys.textColor: textColor.name,
  };

  /// 从 `SharedPreferences` 读出的原始值还原；缺失或越界时回落到默认值。
  factory CourseTableStyle.decode({
    int? backgroundColorArgb,
    String? imagePath,
    double? imageOpacity,
    double? imageBlur,
    double? imageBrightness,
    double? cardOpacity,
    String? material,
    double? cardBlur,
    bool? colorful,
    String? textColor,
  }) {
    return CourseTableStyle(
      backgroundColor:
          backgroundColorArgb == null ? null : Color(backgroundColorArgb),
      backgroundImagePath: (imagePath ?? '').isEmpty ? null : imagePath,
      imageOpacity: (imageOpacity ?? 1.0).clamp(0.0, 1.0),
      imageBlur: (imageBlur ?? 0.0).clamp(0.0, maxImageBlur),
      imageBrightness: (imageBrightness ?? 0.0).clamp(-1.0, 1.0),
      cardOpacity: (cardOpacity ?? 0.82).clamp(0.0, 1.0),
      material: CourseCardMaterial.parse(material),
      cardBlur: (cardBlur ?? 12.0).clamp(0.0, maxCardBlur),
      // 缺键（老版本用户）按彩色处理，升级后观感与之前完全一致。
      colorful: colorful ?? true,
      textColor: CourseTextColorMode.parse(textColor),
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is CourseTableStyle &&
        other.backgroundColor == backgroundColor &&
        other.backgroundImagePath == backgroundImagePath &&
        other.imageOpacity == imageOpacity &&
        other.imageBlur == imageBlur &&
        other.imageBrightness == imageBrightness &&
        other.cardOpacity == cardOpacity &&
        other.material == material &&
        other.cardBlur == cardBlur &&
        other.colorful == colorful &&
        other.textColor == textColor;
  }

  @override
  int get hashCode => Object.hash(
    backgroundColor,
    backgroundImagePath,
    imageOpacity,
    imageBlur,
    imageBrightness,
    cardOpacity,
    material,
    cardBlur,
    colorful,
    textColor,
  );
}
