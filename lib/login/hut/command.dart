import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../utils/hut_user_api.dart';

var api = HutUserApi();
String doubleRandom = "0";
String timestamp = DateTime.timestamp().millisecondsSinceEpoch.toString();
bool first = true;

void loginToHuT(String username, String password, context) {
  api.userLogin(username: username, password: password).then((value) {
    if (value) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('成功')));
      Navigator.pop(context);
    } else {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('登录失败')));
    }
  });
}

/// 读取上次短信登录回填的手机号（无则空串）。
Future<String> readHutMobile() async {
  final prefs = await SharedPreferences.getInstance();
  return prefs.getString('hutMobile') ?? '';
}
