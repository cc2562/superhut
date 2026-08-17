import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:superhut/login/loginwithpost.dart';
import 'package:superhut/utils/withhttp.dart';

import '../login/hut_cas_login_page.dart';
import '../login/unified_login_page.dart';

Future<void> saveToken(String token) async {
  final prefs = await SharedPreferences.getInstance();
  prefs.setString('token', token);
}

Future<String> getToken() async {
  final prefs = await SharedPreferences.getInstance();
  String token = prefs.getString('token') ?? '';
  return token;
}

Future<bool> checkTokenValid() async {
  try {
    await configureDioFromStorage();
    Response response;
    response = await postDioWithCookie('/njwhd/noticeTab', {});
    Map data = response.data;
    if (data['code'] == "1") {
      return true;
    } else {
      return false;
    }
  } catch (e) {
    return false;
  }
}

Future<bool> renewToken(BuildContext context) async {
  final messenger = ScaffoldMessenger.maybeOf(context);
  final navigator = Navigator.of(context);
  final prefs = await SharedPreferences.getInstance();
  String type = prefs.getString('loginType') ?? "";
  if (type == "jwxt") {
    if (await checkTokenValid()) {
      return true;
    }
    try {
      String user = prefs.getString('user') ?? "1";
      String password = prefs.getString('password') ?? "1";
      return await loginHut(user, password);
    } on DioException catch (error) {
      debugPrint('教务系统登录续期网络错误: $error');
      _showRefreshFailure(messenger, '刷新失败，请检查网络后重试');
      return false;
    } catch (error) {
      debugPrint('教务系统登录续期失败: $error');
      await _returnToLoginAfterAuthenticationExpired(
        navigator,
        prefs,
        messenger,
      );
      return false;
    }
  }

  if (await checkTokenValid()) {
    return true;
  }
  if (!context.mounted) return false;
  try {
    final result = await HutCasTokenRetriever.getJwxtTokenAndCookie(context);
    final refreshedToken = result?['token']?.trim() ?? '';
    if (refreshedToken.isEmpty) {
      await _returnToLoginAfterAuthenticationExpired(
        navigator,
        prefs,
        messenger,
      );
      return false;
    }
    return true;
  } catch (error) {
    debugPrint('统一认证续期失败: $error');
    _showRefreshFailure(messenger, '刷新失败，请检查网络后重试');
    return false;
  }
}

Future<void> _returnToLoginAfterAuthenticationExpired(
  NavigatorState navigator,
  SharedPreferences prefs,
  ScaffoldMessengerState? messenger,
) async {
  await prefs.setBool('isFirstOpen', true);
  await HutCasTokenRetriever.clearCachedSession();
  _showRefreshFailure(messenger, '登录状态已失效，请重新登录');
  await Future<void>.delayed(const Duration(milliseconds: 800));
  if (!navigator.mounted) return;
  navigator.pushAndRemoveUntil(
    MaterialPageRoute<void>(builder: (_) => const UnifiedLoginPage()),
    (Route<dynamic> route) => false,
  );
}

void _showRefreshFailure(ScaffoldMessengerState? messenger, String message) {
  if (messenger?.mounted == true) {
    messenger!.showSnackBar(SnackBar(content: Text(message)));
  }
}
