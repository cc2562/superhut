import 'package:flutter/material.dart';

import '../../security/credential_store.dart';
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
///
/// 手机号属于个人标识，跟着其它凭据一起放在系统安全存储里。
Future<String> readHutMobile() async {
  return CredentialStore.instance.readOrEmpty('hutMobile');
}
