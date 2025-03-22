import 'package:dio/dio.dart';

final dio = Dio(); // With default `Options`.

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

Future<Response> postDio(String path, Map postData) async {
  Response response;
  response = await dio.post(path, data: postData);
  //print(response.data);
  return response;
}
