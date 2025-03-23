import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart' as tget;
import 'package:get/get_core/src/get_main.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:superhut/login/loginwithpost.dart';
import 'package:superhut/utils/withhttp.dart';

import '../login/hut_cas_login_page.dart';
import '../login/webview_login_screen.dart';

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
  String token =await getToken();
  print(token);
  configureDio(token);
  Response response;
  response =await postDio('/njwhd/noticeTab', {});
  Map data = response.data;
  print(data);
  if(data['code']=="1"){
    return true;
  }else{
    return false;
  }
}

Future<String> renewToken(context) async {
  final prefs = await SharedPreferences.getInstance();
  String type = prefs.getString('loginType')??"";
  if(type=="jwxt") {
    bool isValid = await checkTokenValid();
    var su;
    print("REEE");
    print(isValid);
    if (isValid) {

    } else {
      String user = prefs.getString('user') ?? "1";
      String password = prefs.getString('password') ?? "1";
      print(1122);
      Get.snackbar(
        '请稍候',
        '正在刷新token',
        snackPosition: tget.SnackPosition.BOTTOM,
        duration: Duration(seconds: 1),
        margin: EdgeInsets.all(10),
        borderRadius: 10,
      );
      await loginHut(user, password);
    }
    return "1123";
  }else{
    bool isValid = await checkTokenValid();
    print(isValid);
    if(isValid){}else {
      await HutCasTokenRetriever.getJwxtToken(context);
      print("刷新完成");

    }
    return "1123";
  }

}
