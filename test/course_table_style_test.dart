import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:superhut/home/coursetable/style/course_table_style.dart';
import 'package:superhut/home/coursetable/style/course_table_style_controller.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('CourseTableStyle 模型', () {
    test('默认值等价于引入本功能之前的观感', () {
      const CourseTableStyle style = CourseTableStyle.defaults;
      expect(style.backgroundColor, isNull);
      expect(style.hasImage, isFalse);
      expect(style.hasCustomBackground, isFalse);
      expect(style.imageOpacity, 1.0);
      expect(style.imageBlur, 0.0);
      expect(style.imageBrightness, 0.0);
      expect(style.cardOpacity, 0.82);
      expect(style.material, CourseCardMaterial.solid);
      expect(style.textColor, CourseTextColorMode.adaptive);
    });

    test('没有自定义时页面底色跟随主题 surface', () {
      const ColorScheme scheme = ColorScheme.light();
      expect(CourseTableStyle.defaults.pageColor(scheme), scheme.surface);
      expect(
        const CourseTableStyle(backgroundColor: Colors.teal).pageColor(scheme),
        Colors.teal,
      );
    });

    test('copyWith 可以把背景色与图片置空', () {
      const CourseTableStyle style = CourseTableStyle(
        backgroundColor: Colors.red,
        backgroundImagePath: '/tmp/a.jpg',
      );
      expect(style.copyWith(backgroundColor: null).backgroundColor, isNull);
      expect(style.copyWith(backgroundImagePath: null).hasImage, isFalse);
      // 不传这两个参数时保持原值。
      expect(style.copyWith(cardOpacity: 0.5).backgroundColor, Colors.red);
      expect(
        style.copyWith(cardOpacity: 0.5).backgroundImagePath,
        '/tmp/a.jpg',
      );
    });

    test('数值字段写入时被 clamp 到合法区间', () {
      final CourseTableStyle style = CourseTableStyle.defaults.copyWith(
        imageOpacity: 3,
        imageBlur: 999,
        imageBrightness: -8,
        cardOpacity: -1,
      );
      expect(style.imageOpacity, 1.0);
      expect(style.imageBlur, CourseTableStyle.maxImageBlur);
      expect(style.imageBrightness, -1.0);
      expect(style.cardOpacity, 0.0);
    });

    test('decode 对缺失与非法值容错', () {
      final CourseTableStyle decoded = CourseTableStyle.decode(
        material: 'not-a-material',
        textColor: 'not-a-mode',
        cardOpacity: 12,
        imageBlur: -4,
      );
      expect(decoded.material, CourseCardMaterial.solid);
      expect(decoded.textColor, CourseTextColorMode.adaptive);
      expect(decoded.cardOpacity, 1.0);
      expect(decoded.imageBlur, 0.0);
      expect(decoded.backgroundImagePath, isNull);
    });

    test('encode → decode 能还原颜色与枚举', () {
      const CourseTableStyle style = CourseTableStyle(
        backgroundColor: Color(0xFF4C5BD4),
        backgroundImagePath: '/tmp/bg.png',
        imageOpacity: 0.4,
        imageBlur: 12,
        imageBrightness: -0.3,
        cardOpacity: 0.25,
        material: CourseCardMaterial.frosted,
        textColor: CourseTextColorMode.white,
      );
      final Map<String, Object?> raw = style.encode();
      final CourseTableStyle restored = CourseTableStyle.decode(
        backgroundColorArgb: raw[CourseTableStyleKeys.backgroundColor] as int?,
        imagePath: raw[CourseTableStyleKeys.imagePath] as String?,
        imageOpacity: raw[CourseTableStyleKeys.imageOpacity] as double?,
        imageBlur: raw[CourseTableStyleKeys.imageBlur] as double?,
        imageBrightness: raw[CourseTableStyleKeys.imageBrightness] as double?,
        cardOpacity: raw[CourseTableStyleKeys.cardOpacity] as double?,
        material: raw[CourseTableStyleKeys.cardMaterial] as String?,
        textColor: raw[CourseTableStyleKeys.textColor] as String?,
      );
      expect(restored, style);
    });

    test('没有背景图时 encode 把图片路径写成 null（应删除该键）', () {
      final Map<String, Object?> raw = CourseTableStyle.defaults.encode();
      expect(raw[CourseTableStyleKeys.imagePath], isNull);
      expect(raw[CourseTableStyleKeys.backgroundColor], isNull);
    });
  });

  group('课程块文字颜色', () {
    const Color accent = Color(0xFF1B3FA0);

    test('白字 / 黑字模式忽略背景', () {
      const CourseTableStyle white = CourseTableStyle(
        textColor: CourseTextColorMode.white,
      );
      const CourseTableStyle black = CourseTableStyle(
        textColor: CourseTextColorMode.black,
      );
      expect(
        white.courseForeground(accent, pageEstimate: Colors.white),
        Colors.white,
      );
      expect(
        black.courseForeground(accent, pageEstimate: Colors.black),
        const Color(0xFF1B1B1F),
      );
    });

    test('自适应在浅底上给深字、深底上给白字', () {
      const CourseTableStyle style = CourseTableStyle();
      expect(
        style.courseForeground(
          const Color(0xFFE8E8E8),
          pageEstimate: Colors.white,
        ),
        const Color(0xFF1B1B1F),
      );
      expect(
        style.courseForeground(accent, pageEstimate: Colors.black),
        Colors.white,
      );
    });

    test('不透明度为 0 时自适应跟随页面底色', () {
      const CourseTableStyle style = CourseTableStyle(cardOpacity: 0);
      expect(
        style.courseForeground(accent, pageEstimate: Colors.white),
        const Color(0xFF1B1B1F),
      );
      expect(
        style.courseForeground(accent, pageEstimate: Colors.black),
        Colors.white,
      );
    });

    test('卡片底色带上用户设定的不透明度', () {
      const CourseTableStyle style = CourseTableStyle(cardOpacity: 0.5);
      expect(style.cardTint(accent).a, closeTo(0.5, 0.01));
    });
  });

  group('页面底色估算', () {
    test('图片 + 变暗会让估算底色更暗', () {
      const ColorScheme scheme = ColorScheme.light();
      const CourseTableStyle plain = CourseTableStyle();
      const CourseTableStyle image = CourseTableStyle(
        backgroundImagePath: '/tmp/bg.jpg',
      );
      final CourseTableStyle dark = image.copyWith(imageBrightness: -1);
      final CourseTableStyle bright = image.copyWith(imageBrightness: 1);

      expect(
        dark.estimatedPageColor(scheme).computeLuminance(),
        lessThan(image.estimatedPageColor(scheme).computeLuminance()),
      );
      expect(
        bright.estimatedPageColor(scheme).computeLuminance(),
        greaterThan(image.estimatedPageColor(scheme).computeLuminance()),
      );
      // 没有图片时明暗参数不参与估算。
      expect(
        plain.copyWith(imageBrightness: -1).estimatedPageColor(scheme),
        plain.estimatedPageColor(scheme),
      );
    });
  });

  group('CourseTableStyleController', () {
    setUp(() async {
      SharedPreferences.setMockInitialValues({});
      await Get.deleteAll(force: true);
    });

    tearDown(() async {
      await Get.deleteAll(force: true);
    });

    test('load 读取已持久化的设置', () async {
      SharedPreferences.setMockInitialValues({
        CourseTableStyleKeys.cardOpacity: 0.3,
        CourseTableStyleKeys.cardMaterial: 'frosted',
        CourseTableStyleKeys.textColor: 'black',
        CourseTableStyleKeys.backgroundColor: 0xFF112233,
      });
      final controller = Get.put(CourseTableStyleController());
      await controller.load();

      expect(controller.value.cardOpacity, 0.3);
      expect(controller.value.material, CourseCardMaterial.frosted);
      expect(controller.value.textColor, CourseTextColorMode.black);
      expect(controller.value.backgroundColor, const Color(0xFF112233));
    });

    test('setter 立即改内存并落盘', () async {
      final controller = Get.put(CourseTableStyleController());
      await controller.load();
      await controller.setCardOpacity(0.15);
      await controller.setMaterial(CourseCardMaterial.liquidGlass);

      expect(controller.value.cardOpacity, 0.15);
      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getDouble(CourseTableStyleKeys.cardOpacity), 0.15);
      expect(
        prefs.getString(CourseTableStyleKeys.cardMaterial),
        CourseCardMaterial.liquidGlass.name,
      );
    });

    test('背景图片路径失效时回落到纯色', () async {
      SharedPreferences.setMockInitialValues({
        CourseTableStyleKeys.imagePath: '/definitely/not/here.jpg',
      });
      final controller = Get.put(CourseTableStyleController());
      await controller.load();
      expect(controller.value.hasImage, isFalse);
    });

    test('reset 清空全部自定义项', () async {
      final controller = Get.put(CourseTableStyleController());
      await controller.load();
      await controller.setBackgroundColor(Colors.orange);
      await controller.setTextColor(CourseTextColorMode.white);
      await controller.reset();

      expect(controller.value, CourseTableStyle.defaults);
      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getInt(CourseTableStyleKeys.backgroundColor), isNull);
      expect(prefs.getString(CourseTableStyleKeys.textColor), isNull);
    });
  });
}
