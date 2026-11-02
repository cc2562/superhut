import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:superhut/login/loginwithpost.dart';
import 'package:superhut/security/credential_store.dart';
import 'package:superhut/utils/withhttp.dart';

import '../login/hut_cas_login_page.dart';
import '../login/unified_login_page.dart';

Future<void> saveToken(String token) async {
  await CredentialStore.instance.write('token', token);
}

Future<String> getToken() async {
  return CredentialStore.instance.readOrEmpty('token');
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
      final store = CredentialStore.instance;
      final String user = await store.readOrEmpty('user');
      final String password = await store.readOrEmpty('password');
      if (user.isEmpty || password.isEmpty) {
        // 安全存储里没有凭据（换机、撤销权限、系统升级导致 KeyStore 失效等），
        // 直接引导重新登录，不要拿空账号去撞接口。
        await _returnToLoginAfterAuthenticationExpired(
          navigator,
          prefs,
          messenger,
        );
        return false;
      }
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
