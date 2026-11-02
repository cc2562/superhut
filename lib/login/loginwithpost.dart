import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../security/credential_store.dart';
import '../utils/pwd.dart';
import '../utils/token.dart';

Future<bool> loginHut(String userNo, String orgPassword) async {
  print("Started");
  // 加密密码
  final encryptedPassword = encryptPassword(orgPassword, Sw);

  // 二次Base64编码
  final pwd = base64Encode(utf8.encode(encryptedPassword));
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
  // 账号密码属于凭据，写系统安全存储；姓名/学院/班级只是展示型缓存，留在 prefs。
  await CredentialStore.instance.write('user', userNo);
  await CredentialStore.instance.write('password', orgPassword);
  await prefs.setBool('isFirstOpen', false);
  await prefs.setString('name', name);
  await prefs.setString('entranceYear', entranceYear);
  await prefs.setString('academyName', academyName);
  await prefs.setString('clsName', clsName);
  print("Finished");
  return true;
}
