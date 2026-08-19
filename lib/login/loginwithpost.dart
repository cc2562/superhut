import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../utils/pwd.dart';
import '../utils/token.dart';

Future<bool> loginHut(String userNo, String orgPassword) async {
  final encryptedPassword = encryptPassword(orgPassword, academicPasswordKey);
  final pwd = base64Encode(utf8.encode(encryptedPassword));
  final dio = Dio();
  dio.options.baseUrl = 'https://jwxtsj.hut.edu.cn';
  dio.options.connectTimeout = const Duration(seconds: 5);
  dio.options.receiveTimeout = const Duration(seconds: 3);
  dio.options.headers = {
    'User-Agent':
        'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/91.0.4472.124 Safari/537.36 Edg/91.0.864.64',
    'Accept': '*/*',
    'Accept-Encoding': 'gzip, deflate, br',
  };
  final response = await dio.post('/njwhd/login?userNo=$userNo&pwd=$pwd');
  final data = response.data as Map;
  final userData = data['data'] as Map;
  final name = userData['name'] as String;
  final token = userData['token'] as String;
  final entranceYear = userData['entranceYear'] as String;
  final academyName = userData['academyName'] as String;
  final clsName = userData['clsName'] as String;
  final prefs = await SharedPreferences.getInstance();
  saveToken(token);
  prefs.setString('user', userNo);
  prefs.setString('password', orgPassword);
  await prefs.setBool('isFirstOpen', false);
  await prefs.setString('name', name);
  await prefs.setString('entranceYear', entranceYear);
  await prefs.setString('academyName', academyName);
  await prefs.setString('clsName', clsName);
  return true;
}
