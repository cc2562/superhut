import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:shared_preferences/shared_preferences.dart';


import '../utils/pwd.dart';
import '../utils/token.dart';

Future<bool> loginHut(String userNo, String orgPassword) async {
  print("Started");
  // 加密密码
  final encryptedPassword = encryptPassword(orgPassword, Sw);
  print('加密后的密码：  $encryptedPassword');

  // 二次Base64编码
  final pwd = base64Encode(utf8.encode(encryptedPassword));
  print('加密并Base64 编码后的密码：  $pwd');
  final dio = Dio();
  dio.options.baseUrl = 'https://jwxtsj.hut.edu.cn';
  dio.options.connectTimeout = Duration(seconds: 5);
  dio.options.receiveTimeout = Duration(seconds: 3);
  dio.options.headers = {
    'User-Agent':
    'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/91.0.4472.124 Safari/537.36 Edg/91.0.864.64',
    'Accept': '*/*',
    'Accept-Encoding': 'gzip, deflate, br',
  };
  Response response = await dio.post('/njwhd/login?userNo=$userNo&pwd=$pwd');
  Map data = response.data;
  Map userData = data['data'];
  String name = userData['name'];
  String token = userData['token'];
  String entranceYear = userData['entranceYear'];
  String academyName = userData['academyName'];
  String clsName = userData['clsName'];
  final prefs = await SharedPreferences.getInstance();
  saveToken(token);
  prefs.setString('user', userNo);
  prefs.setString('password', orgPassword);
  await prefs.setBool('isFirstOpen', false);
  await prefs.setString('name', name);
  await prefs.setString('entranceYear', entranceYear);
  await prefs.setString('academyName', academyName);
  await prefs.setString('clsName', clsName);
  print("Finished");
  return true;
}