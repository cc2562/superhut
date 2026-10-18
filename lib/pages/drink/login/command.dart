import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:superhut/pages/drink/api/drink_api.dart';

import 'loginpart2.dart';

class DrinkLoginCommand {
  static final DrinkLoginCommand _instance = DrinkLoginCommand._internal();
  factory DrinkLoginCommand() => _instance;

  DrinkLoginCommand._internal() {
    _reset();
  }

  final DrinkApi api = DrinkApi();
  String _captchaKey = "";
  bool _first = true;

  static const String _captchaChars =
      "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789";

  void _reset() {
    // 仅重置请求标记，保留当前 key，避免刷新失败时提交空的 s 参数
    _first = true;
  }

  /// 生成 10 位字母数字验证码 key，与官方客户端一致
  String _newCaptchaKey() {
    final random = Random();
    return List.generate(
      10,
      (_) => _captchaChars[random.nextInt(_captchaChars.length)],
    ).join();
  }

  Future<Uint8List> getImageCaptcha() async {
    if (!_first) {
      return Uint8List(0);
    }
    _captchaKey = _newCaptchaKey();
    // 先落标记，避免同一帧内重复 build 触发多次验证码请求造成 key 不一致
    _first = false;
    try {
      return await api.userCaptcha(key: _captchaKey);
    } catch (e) {
      debugPrint("[drink] 获取图形验证码失败: $e");
      return Uint8List(0);
    }
  }

  void to2Login(BuildContext context, String phoneNumber) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => DrinkLoginPage2(phoneNumber: phoneNumber),
      ),
    );
  }

  Future<void> sendMessageCode(
    BuildContext context,
    String phoneNumber,
    String imageCode,
  ) async {
    final result = await api.userMessageCode(
      captchaKey: _captchaKey,
      photoCode: imageCode,
      phone: phoneNumber,
    );

    if (!context.mounted) return;
    if (result.success) {
      to2Login(context, phoneNumber);
    } else {
      _showMessage(context, result.msg.isEmpty ? '验证码错误' : result.msg);
    }
  }

  Future<void> login(
    String phoneNumber,
    String code,
    BuildContext context,
  ) async {
    final result = await api.userLogin(phone: phoneNumber, messageCode: code);
    if (!context.mounted) return;
    if (result.success) {
      _showMessage(context, '登录成功');
      Navigator.pop(context);
      Navigator.pop(context); // 退出登录页面时，确保返回两层
    } else {
      _showMessage(context, result.msg.isEmpty ? '登录失败' : result.msg);
    }
  }

  void _showMessage(BuildContext context, String message) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  // 清理方法，在页面销毁时调用
  void dispose() {
    _reset();
  }
}
