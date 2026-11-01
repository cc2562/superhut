import 'dart:io';

import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'course_table_style.dart';

/// 课表外观的单一真源。
///
/// 写入策略与 `ThemeController` 一致：先改内存（界面立即跟随），再异步落盘。
/// 所有失败都只记一条日志，绝不让一次写盘失败影响页面可用性。
class CourseTableStyleController extends GetxController {
  /// 取控制器；未注册时（例如 widget 测试）就地注册一份默认实例。
  static CourseTableStyleController get instance {
    if (Get.isRegistered<CourseTableStyleController>()) {
      return Get.find<CourseTableStyleController>();
    }
    return Get.put(CourseTableStyleController());
  }

  final Rx<CourseTableStyle> style = CourseTableStyle.defaults.obs;

  CourseTableStyle get value => style.value;

  /// 启动时读取设置；图片文件已被系统清理时静默回落到纯色背景。
  Future<void> load() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      var next = CourseTableStyle.decode(
        backgroundColorArgb: prefs.getInt(CourseTableStyleKeys.backgroundColor),
        imagePath: prefs.getString(CourseTableStyleKeys.imagePath),
        imageOpacity: prefs.getDouble(CourseTableStyleKeys.imageOpacity),
        imageBlur: prefs.getDouble(CourseTableStyleKeys.imageBlur),
        imageBrightness: prefs.getDouble(CourseTableStyleKeys.imageBrightness),
        cardOpacity: prefs.getDouble(CourseTableStyleKeys.cardOpacity),
        material: prefs.getString(CourseTableStyleKeys.cardMaterial),
        textColor: prefs.getString(CourseTableStyleKeys.textColor),
      );
      final path = next.backgroundImagePath;
      if (path != null && !File(path).existsSync()) {
        debugPrint('课表背景图片已丢失，回落到纯色背景：$path');
        next = next.copyWith(backgroundImagePath: null);
      }
      style.value = next;
    } catch (error) {
      debugPrint('读取课表外观设置失败：$error');
    }
  }

  Future<void> setBackgroundColor(Color? color) =>
      _apply(value.copyWith(backgroundColor: color));

  Future<void> setImageOpacity(double opacity) =>
      _apply(value.copyWith(imageOpacity: opacity));

  Future<void> setImageBlur(double blur) =>
      _apply(value.copyWith(imageBlur: blur));

  Future<void> setImageBrightness(double brightness) =>
      _apply(value.copyWith(imageBrightness: brightness));

  Future<void> setCardOpacity(double opacity) =>
      _apply(value.copyWith(cardOpacity: opacity));

  Future<void> setMaterial(CourseCardMaterial material) =>
      _apply(value.copyWith(material: material));

  Future<void> setTextColor(CourseTextColorMode mode) =>
      _apply(value.copyWith(textColor: mode));

  /// 从相册选一张背景图，复制到应用私有目录后再切换过去。
  ///
  /// 返回 `false` 表示用户取消、无权限或写盘失败——调用方不需要区分，静默
  /// 保持在原背景即可。
  Future<bool> pickBackgroundImage() async {
    XFile? picked;
    try {
      picked = await ImagePicker().pickImage(
        source: ImageSource.gallery,
        maxWidth: 2400,
        imageQuality: 90,
      );
    } catch (error) {
      // iOS 上相册权限被拒时这里会抛异常，文案已在 Info.plist 说明用途。
      debugPrint('打开相册失败：$error');
      return false;
    }
    if (picked == null) return false;

    try {
      final dir = await getApplicationDocumentsDirectory();
      final folder = Directory('${dir.path}/course_style');
      if (!folder.existsSync()) {
        await folder.create(recursive: true);
      }
      final extension = _extensionOf(picked.path);
      final target =
          '${folder.path}/course_bg_'
          '${DateTime.now().millisecondsSinceEpoch}$extension';
      await File(picked.path).copy(target);

      final old = value.backgroundImagePath;
      style.value = value.copyWith(backgroundImagePath: target);
      await _persist();
      // 先落盘成功再删旧文件，避免中途失败后指向一个已删除的路径。
      if (old != null && old != target) {
        await _deleteImage(old);
      }
      return true;
    } catch (error) {
      debugPrint('保存课表背景图片失败：$error');
      return false;
    }
  }

  /// 移除背景图并删除私有目录里的副本。
  Future<void> clearBackgroundImage() async {
    final old = value.backgroundImagePath;
    if (old == null) return;
    style.value = value.copyWith(backgroundImagePath: null);
    await _persist();
    await _deleteImage(old);
  }

  /// 恢复到出厂观感：清空所有自定义项（含背景图文件与全部持久化键）。
  Future<void> reset() async {
    final old = value.backgroundImagePath;
    style.value = CourseTableStyle.defaults;
    try {
      final prefs = await SharedPreferences.getInstance();
      for (final key in CourseTableStyle.defaults.encode().keys) {
        await prefs.remove(key);
      }
    } catch (error) {
      debugPrint('清空课表外观设置失败：$error');
    }
    if (old != null) await _deleteImage(old);
  }

  Future<void> _apply(CourseTableStyle next) async {
    if (next == value) return;
    style.value = next;
    await _persist();
  }

  Future<void> _persist() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final data = value.encode();
      for (final entry in data.entries) {
        final Object? item = entry.value;
        if (item == null) {
          await prefs.remove(entry.key);
        } else if (item is int) {
          await prefs.setInt(entry.key, item);
        } else if (item is double) {
          await prefs.setDouble(entry.key, item);
        } else if (item is String) {
          await prefs.setString(entry.key, item);
        } else if (item is bool) {
          await prefs.setBool(entry.key, item);
        }
      }
    } catch (error) {
      debugPrint('保存课表外观设置失败：$error');
    }
  }

  Future<void> _deleteImage(String path) async {
    try {
      final file = File(path);
      if (file.existsSync()) await file.delete();
    } catch (error) {
      debugPrint('删除旧课表背景图片失败：$error');
    }
  }

  /// 取小写扩展名；相册可能给出没有扩展名或非常见格式的临时文件。
  static String _extensionOf(String path) {
    final int dot = path.lastIndexOf('.');
    final int separator = path.lastIndexOf('/');
    final int windowsSeparator = path.lastIndexOf(r'\');
    final int lastSeparator =
        separator > windowsSeparator ? separator : windowsSeparator;
    if (dot <= lastSeparator || dot == path.length - 1) return '.jpg';
    final String extension = path.substring(dot).toLowerCase();
    const Set<String> supported = {'.jpg', '.jpeg', '.png', '.webp', '.heic'};
    return supported.contains(extension) ? extension : '.jpg';
  }
}
