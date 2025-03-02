import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:superhut/command/withhttp.dart';

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
  bool isValid = await checkTokenValid();
  var su;
  print("REEE");
  print(isValid);
  if(isValid){

  }else{
    final prefs = await SharedPreferences.getInstance();
    String user = prefs.getString('user')??"1";
    String password = prefs.getString('password')??"1";
    print(1122);
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder:
            (context) => WebViewLoginScreen(
          userNo: user,
          password: password,
          showText: "正在刷新...",
              renew: true,
        ),
      ),
    );

  }
  return "1123";
}
