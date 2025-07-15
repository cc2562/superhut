import 'package:dio/dio.dart';
import 'package:shared_preferences/shared_preferences.dart';

final dio = Dio(); // With default `Options`.
final hutDio = Dio(); // With default `Options`.

void configureDio(String token) {
  // Update default configs.
  dio.options.baseUrl = 'https://jwxtsj.hut.edu.cn';
  dio.options.connectTimeout = Duration(seconds: 5);
  dio.options.receiveTimeout = Duration(seconds: 3);
  dio.options.headers = {
    'User-Agent':
        'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/91.0.4472.124 Safari/537.36 Edg/91.0.864.64',
    'Accept': '*/*',
    'Accept-Encoding': 'gzip, deflate, br',
    'Token': token,
  };
}

// 新增：配置包含cookie的dio
Future<void> configureDioWithCookie(String token, {String? myClientTicket}) async {
  dio.options.baseUrl = 'https://jwxtsj.hut.edu.cn';
  dio.options.connectTimeout = Duration(seconds: 20);
  dio.options.receiveTimeout = Duration(seconds: 20);
  
  // 构建cookie字符串
  String cookieString = '';
  if (myClientTicket != null && myClientTicket.isNotEmpty) {
    cookieString = 'my_client_ticket=$myClientTicket';
  }
  
  dio.options.headers = {
    'User-Agent':
        'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/91.0.4472.124 Safari/537.36 Edg/91.0.864.64',
    'Accept': '*/*',
    'Accept-Encoding': 'gzip, deflate, br',
    'Token': token,
    if (cookieString.isNotEmpty) 'Cookie': cookieString,
  };
}

// 新增：从SharedPreferences获取token和cookie并配置dio
Future<void> configureDioFromStorage() async {
  final prefs = await SharedPreferences.getInstance();
  String token = prefs.getString('token') ?? '';
  String myClientTicket = prefs.getString('my_client_ticket') ?? '';
  
  await configureDioWithCookie(token, myClientTicket: myClientTicket);
}

Future<Response> postDio(String path, Map postData) async {
  dio.options.baseUrl = 'https://jwxtsj.hut.edu.cn';
  Response response;
  response = await dio.post(path, data: postData,options:Options(
      followRedirects: false,
      validateStatus: (status) { return status! < 500; }
  ),);
  print(response.data);
  return response;
}

// 新增：带有cookie的POST请求
Future<Response> postDioWithCookie(String path, Map postData, {String? customCookie}) async {
  // 先从存储中配置dio
  await configureDioFromStorage();
  
  // 如果提供了自定义cookie，则覆盖
  if (customCookie != null && customCookie.isNotEmpty) {
    dio.options.headers['Cookie'] = customCookie;
  }
  
  Response response;
  response = await dio.post(path, data: postData, options: Options(
      followRedirects: false,

  ));
  print(response.data);
  return response;
}

