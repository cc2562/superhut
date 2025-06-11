import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:shared_preferences/shared_preferences.dart';

class DrinkApi {
  DrinkApi._privateConstructor() {
    _initToken();
  }

  static final DrinkApi _instance = DrinkApi._privateConstructor();

  factory DrinkApi() {
    return _instance;
  }

  final Dio _dio = Dio();
  final Map<String, dynamic> _token = {"uid": "", "eid": "", "token": ""};

  Future<void> _initToken() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    String? userInfoDataStr = prefs.getString("drink798UsrApiToken");
    if (userInfoDataStr != null) {
      Map<String, dynamic> map = jsonDecode(userInfoDataStr);
      map.forEach((key, value) {
        _token[key] = value;
      });
    } else {
      prefs.setString("drink798UsrApiToken", jsonEncode(_token));
    }
  }

  /// 获取慧生活798登录验证码
  Future<Uint8List> userCaptcha({
    required String doubleRandom,
    required String timestamp,
  }) async {
    Options options = Options(responseType: ResponseType.bytes);
    String url = "https://i.ilife798.com/api/v1/captcha/";
    Map<String, dynamic> params = {"s": doubleRandom, "r": timestamp};
    Response response = await _dio.get(
      url,
      queryParameters: params,
      options: options,
    );
    return response.data;
  }

  /// 获取短信验证码
  Future<bool> userMessageCode({
    required String doubleRandom,
    required String photoCode,
    required String phone,
  }) async {
    String url = "https://i.ilife798.com/api/v1/acc/login/code";
    Map<String, dynamic> data = {
      "s": doubleRandom,
      "authCode": photoCode,
      "un": phone,
    };
    Response response = await _dio.post(url, data: data);
    print(response.data);
    return response.data["code"] == 0;
  }

  /// 开始登录
  Future<bool> userLogin({
    required String phone,
    required String messageCode,
  }) async {
    String url = "https://i.ilife798.com/api/v1/acc/login";
    Map<String, dynamic> data = {
      "openCode": "",
      "authCode": messageCode,
      "un": phone,
      "cid": "sbsbsbsbsbsbsbsbsbsbsb",
    };
    Response response = await _dio.post(url, data: data);
    final result = response.data;
    _token["uid"] = result["data"]["al"]["uid"];
    _token["eid"] = result["data"]["al"]["eid"];
    _token["token"] = result["data"]["al"]["token"];
    SharedPreferences prefs = await SharedPreferences.getInstance();
    prefs.setString("drink798UsrApiToken", jsonEncode(_token));
    prefs.setBool("hui798IsLogin", true);
    return result["code"] == 0;
  }

  /// 获取设备列表
  Future<List<Map>> deviceList() async {
    String url = "https://i.ilife798.com/api/v1/ui/app/master";
    Options options = Options(headers: {"Authorization": _token["token"]});

    Response response = await _dio.get(url, options: options);
    final result = response.data;
    if (result["data"]["account"] == null) {
      return [
        {"id": "404", "name": "Account failure"},
      ];
    }

    if (result["data"]["favos"] == null) {
      return [];
    }

    final List favos = result["data"]["favos"];
    return favos
        .map((e) {
          return {"id": e["id"], "name": e["name"]};
        })
        .toList()
        .reversed
        .toList();
  }

  /// 收藏或取消收藏设备
  Future<bool> favoDevice({required String id, required bool isUnFavo}) async {
    String url = "https://i.ilife798.com/api/v1/dev/favo";
    Options options = Options(headers: {"Authorization": _token["token"]});

    Map<String, dynamic> params = {"did": id, "remove": isUnFavo};

    Response response = await _dio.get(
      url,
      queryParameters: params,
      options: options,
    );
    return response.data["code"] == 0;
  }

  /// 开始喝水
  Future<bool> startDrink({required String id}) async {
    String url = "https://i.ilife798.com/api/v1/dev/start";
    Options options = Options(headers: {"Authorization": _token["token"]});

    Map<String, dynamic> params = {
      "did": id,
      "upgrade": true,
      "rcp": false,
      "stype": 5,
    };

    Response response = await _dio.get(
      url,
      queryParameters: params,
      options: options,
    );
    return response.data["code"] == 0;
  }

  /// 结束喝水
  Future<bool> endDrink({required String id}) async {
    String url = "https://i.ilife798.com/api/v1/dev/end";
    Options options = Options(headers: {"Authorization": _token["token"]});

    Map<String, dynamic> params = {"did": id};

    Response response = await _dio.get(
      url,
      queryParameters: params,
      options: options,
    );
    return response.data["code"] == 0;
  }

  /// 检测设备状态
  Future<bool> isAvailableDevice({required String id}) async {
    String url = "https://i.ilife798.com/api/v1/ui/app/dev/status";
    Options options = Options(headers: {"Authorization": _token["token"]});

    Map<String, dynamic> params = {"did": id, "more": true, "promo": false};

    Response response = await _dio.get(
      url,
      queryParameters: params,
      options: options,
    );
    return response.data["data"]["device"]["gene"]["status"] == 99;
  }

  /// 获取Token
  Future<String> getToken() async {
    return _token["token"];
  }

  /// 设置Token
  Future<void> setToken({required String token}) async {
    _token["token"] = token;
    SharedPreferences prefs = await SharedPreferences.getInstance();
    prefs.setString("drink798UsrApiToken", jsonEncode(_token));
  }
}
