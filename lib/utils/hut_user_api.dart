import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:dio_cache_interceptor/dio_cache_interceptor.dart';
import 'package:encrypt/encrypt.dart';
import 'package:html/dom.dart';
import 'package:html/parser.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:superhut/login/loginwithpost.dart';
import 'package:uuid/uuid.dart';
// ignore: depend_on_referenced_packages
import 'package:pointycastle/asymmetric/api.dart';

/// Utility for transforming response data
class ResponseUtils {
  /// Transforms response data to a standardized format
  /// Extracts data from common API response structures
  static Map<String, dynamic> transformObj(Response response) {
    if (response.data is String) {
      return jsonDecode(response.data);
    } else if (response.data is Map) {
      // If data already has a 'data' field, return that
      if (response.data.containsKey('data')) {
        return response.data['data'];
      } else {
        return response.data;
      }
    }
    return {};
  }
}

/// Request Manager for handling HTTP requests
class RequestManager {
  final Dio _dio = Dio();
  final CacheOptions cacheOptions = CacheOptions(
    // Set cache options as needed
    store: MemCacheStore(),
    policy: CachePolicy.request,
    hitCacheOnErrorExcept: [401, 403],
    maxStale: const Duration(days: 7),
    priority: CachePriority.normal,
  );

  RequestManager() {
    _dio.options.followRedirects = true;

    _dio.interceptors.add(DioCacheInterceptor(options: cacheOptions));
  }

  Future<Response<T>> get<T>(
    String url, {
    Map<String, dynamic>? params,
    Options? options,
    CancelToken? cancelToken,
    ProgressCallback? onReceiveProgress,
  }) async {
    return _dio.get<T>(
      url,
      queryParameters: params,
      options: options,
      cancelToken: cancelToken,
      onReceiveProgress: onReceiveProgress,
    );
  }

  Future<Response<T>> post<T>(
    String url, {
    dynamic data,
    Map<String, dynamic>? params,
    Options? options,
    CancelToken? cancelToken,
    ProgressCallback? onSendProgress,
    ProgressCallback? onReceiveProgress,
  }) async {
    return _dio.post<T>(
      url,
      data: data,
      queryParameters: params,
      options: options,
      cancelToken: cancelToken,
      onSendProgress: onSendProgress,
      onReceiveProgress: onReceiveProgress,
    );
  }
}

/// Data Storage Manager for handling persistent storage operations


class HutUserApi {



  String generateDeviceIdAlphabet() {
    const chars = 'abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ';
    final random = Random.secure();
    return List.generate(24, (index) {
      return chars[random.nextInt(chars.length)]; // 从字母表中随机选取
    }).join();
  }
  String generateUuidV4() {
    final random = Random.secure();
    final bytes = List<int>.generate(16, (i) => random.nextInt(256));

    // 设置UUID版本和变体（符合v4规范）
    bytes[6] = (bytes[6] & 0x0F) | 0x40; // 版本4
    bytes[8] = (bytes[8] & 0x3F) | 0x80; // 变体为DCE 1.1

    // 转换为十六进制并移除连字符
    return bytes.map((byte) => byte.toRadixString(16).padLeft(2, '0')).join();
  }


  String generateJSessionId() {
    final random = Random.secure(); // 创建安全的随机数生成器
    final bytes = Uint8List(16);    // 生成16字节（128位）的数组

    // 逐个填充字节（正确方式）
    for (var i = 0; i < bytes.length; i++) {
      bytes[i] = random.nextInt(256); // 生成0-255（包含）的随机整数
    }

    // 转换为大写的32位十六进制字符串
    return bytes.map((byte) => byte.toRadixString(16).padLeft(2, '0').toUpperCase()).join();
  }


  //static final HutUserApi _instance = HutUserApi._privateConstructor();

  //factory HutUserApi() {
 //   return _instance;
 // }

  // 网络管家
  final _request = RequestManager();
  // 用户凭证数据
  final Map<String, dynamic> _token = {
    "idToken": "",
  };

  /// 获取指纹
  /// return 指纹
  Future<String> getFingerprint() async {
    var uuid = const Uuid();
    return uuid.v4().replaceAll("-", "");
  }

  /// 开始登录
  /// [username] 用户名
  /// [password] 密码
  /// return 是否成功
  Future<bool> userLogin(
      {required String username, required String password}) async {
    String passwordBase = Uri.encodeComponent(password);
    String deviceId =generateDeviceIdAlphabet();
    String clientId = generateUuidV4();
    String loginUrl = "/token/password/passwordLogin?username=$username&password=$passwordBase&appId=com.supwisdom.hut&geo&deviceId=$deviceId&osType=android&clientId=$clientId&mfaState";
    final dio = Dio();
    dio.options.baseUrl = 'https://mycas.hut.edu.cn';
    dio.options.connectTimeout = Duration(seconds: 5);
    dio.options.receiveTimeout = Duration(seconds: 3);
    dio.options.headers = {
      'User-Agent':
      'SWSuperApp/1.1.3(XiaomidadaXiaomi15)',
      'Accept': '*/*',
      'Accept-Encoding': 'gzip, deflate, br',
    };
    Response response;
    try {
      response = await dio.post(loginUrl, data: {});
    } on Error catch (e) {
      return false;
    }

    Map data = response.data;
    if(data.keys.first != 'code'){
      //登录失败
      return false;
    }
    Map tokenData =data['data'];
    String idToken = tokenData['idToken'];
    String refreshToken = tokenData['refreshToken'];
    print(idToken);
    // 设置Token
    final prefs = await SharedPreferences.getInstance();
    prefs.setString('hutToken', idToken);
    prefs.setString('hutRefreshToken', refreshToken);
    prefs.setString('deviceId', deviceId);
    prefs.setString('hutUsername', username);
    prefs.setString('hutPassword', password);
    prefs.setBool('hutIsLogin', true);
    //print(response.data);
    return true;

  }

  /// 获取Token
  /// return Token
  Future<String> getToken() async {
    final prefs = await SharedPreferences.getInstance();
    if (prefs.getString('hutToken') != null) {
      _token["idToken"] = prefs.getString('hutToken')!;
    }
    return _token["idToken"];
  }

  ///检查Token是否有效
  Future<bool> checkTokenValidity() async {
    String token = await getToken();
    final prefs = await SharedPreferences.getInstance();
    String deviceId = prefs.getString('deviceId')??'null';
    String username = prefs.getString('hutUsername')??'null';
    String url = "/token/login/userOnlineDetect?appId=com.supwisdom.hut&deviceId=$deviceId&username=$username";
    final dio = Dio();
    dio.options.baseUrl = 'https://mycas.hut.edu.cn';
    dio.options.connectTimeout = Duration(seconds: 5);
    dio.options.receiveTimeout = Duration(seconds: 3);
    dio.options.headers = {
      'User-Agent':
      'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/91.0.4472.124 Safari/537.36 Edg/91.0.864.64',
      'Accept': '*/*',
      'Accept-Encoding': 'gzip, deflate, br',
      'X-Id-Token':token,
    };
    Response response;
    response = await dio.post(url, data: {});
    Map data = response.data;
    bool isValid = false;
    print(data);
    if(data['code']==-1){
      isValid = false;
    }else if(data['code']==0){
      isValid = true;
    }
    print(data['code']);
    return isValid;
   }

  /// 设置Token
  /// [token] Token
  //Future<void> setToken({required String token}) async {
 //   _token["idToken"] = token;
 //   await _storage.setString("hutUsrApiToken", jsonEncode(_token));
 // }

  /// 获取openid
  /// return openid
  Future<List> getOpenid() async {
    String token =await getToken();
    String url = "https://v8mobile.hut.edu.cn/zdRedirect/toSingleMenu";
    Options options =
        _request.cacheOptions.copyWith(policy: CachePolicy.noCache).toOptions();
    options.validateStatus = (status) {
      return status! < 500;
    };
    options.followRedirects = false;
    options.headers = {
      "X-Id-Token": token,
    };
    Map<String, dynamic> params = {
      "code": "openWater",
      "token": token,
    };
    // 发送请求并处理响应
    // 1. 若响应数据非空，直接返回空字符串
    // 2. 解析Location响应头中的URL，提取OpenID参数值
    return await _request
        .get(url, params: params, options: options)
        .then((value) {
      if (value.data != "") {
        return [];
      }
      // 提取Set-Cookie头
      final setCookieHeader = value.headers['set-cookie'];
      final cookieString = setCookieHeader?.firstWhere(
            (cookie) => cookie.startsWith("JSESSIONID="),
        orElse: () => "",
      );

      // 提取JSESSIONID值
      String jSessionId = "";

        final parts = cookieString?.split(';');
        jSessionId = parts![0].split('=').length > 1
            ? parts[0].split('=')[1]
            : "";

      print("|JJJJJJJJJJJJJSSSSSSSSSSSSSSS");
      print(jSessionId);
      print('END');
      String url = value.headers.value("location")!;
      // logger.i(url.split("openid=")[1]);
      print(url.split("openid=")[1]);
      return [url.split("openid=")[1], jSessionId];
    });
  }

  /// 获取洗澡设备
  /// return 设备列表
  Future<Map<String, dynamic>> getHotWaterDevice() async {
    bool isV = await checkTokenValidity();
    print(isV);
    print(isV);
    String token =await getToken();
    List openidls = await getOpenid();
    String openid = openidls[0];
    String JSESSIONID = openidls[1];
    print(JSESSIONID);
    String url = "/bathroom/getOftenUsetermList?openid=$openid";
    final dio = Dio();
    dio.interceptors.clear();
    dio.options.baseUrl = 'https://v8mobile.hut.edu.cn';
    dio.options.connectTimeout = Duration(seconds: 5);
    dio.options.receiveTimeout = Duration(seconds: 3);
    dio.options.headers = {
      "User-Agent": "Mozilla/5.0 (Linux; Android 15; 24129PN74C Build/AQ3A.240812.002; wv) AppleWebKit/537.36 (KHTML, like Gecko) Version/4.0 Chrome/134.0.6998.39 Mobile Safari/537.36 SuperApp",
      "Connection": "keep-alive",
      "Accept": "application/json, text/javascript, */*; q=0.01",
      "Accept-Encoding": "gzip, deflate, br, zstd",
      "Content-Type": "application/json",
      "sec-ch-ua-platform": "\"Android\"",
      "x-requested-with": "XMLHttpRequest",
      "sec-ch-ua": "\"Chromium\";v=\"134\", \"Not:A-Brand\";v=\"24\", \"Android WebView\";v=\"134\"",
      "sec-ch-ua-mobile": "?1",
      "Origin": "https://v8mobile.hut.edu.cn",
      "Sec-Fetch-Site": "same-origin",
      "Sec-Fetch-Mode": "cors",
      "Sec-Fetch-Dest": "empty",
      "Referer": "https://v8mobile.hut.edu.cn/waterpage/waterHomePage?openid=$openid",
      "Accept-Language": "zh-CN,zh;q=0.9,en-US;q=0.8,en;q=0.7",
      "Cookie": "userToken=$token; Domain=v8mobile.hut.edu.cn; Path=/; JSESSIONID=$JSESSIONID"
    };
    dio.options.followRedirects = true;
    dio.options.validateStatus = (status) {
      return status! < 500;
    };
    Response response;
    response = await dio.post(url, data: {
      "openid": openid,
    });
    print("DDDDDDDDDDDDDDD");
    print(response.data);
    if (response.data == "") {
      return {
        "code": 500,
      };
    }

    var data = response.data;
    // logger.i(data);
    return {
      "code": 200,
      "data": data["resultData"]["data"].reversed.toList(),
    };









  }

  /// 检测未关闭的设备
  /// return 未关闭的设备
  Future<List> checkHotWaterDevice() async {
    String token =await getToken();
    String url = "https://v8mobile.hut.edu.cn/bathroom/selectCloseDeviceValve";
    Options options =
        _request.cacheOptions.copyWith(policy: CachePolicy.noCache).toOptions();
    List openidls = await getOpenid();
    String openid = openidls[0];
    String JSESSIONID = openidls[1];
    options.headers = {
      "openid": openid,
      "User-Agent": "Mozilla/5.0 (Linux; Android 15; 24129PN74C Build/AQ3A.240812.002; wv) AppleWebKit/537.36 (KHTML, like Gecko) Version/4.0 Chrome/134.0.6998.39 Mobile Safari/537.36 SuperApp",
      "Connection": "keep-alive",
      "Accept": "application/json, text/javascript, */*; q=0.01",
      "Accept-Encoding": "gzip, deflate, br, zstd",
      "Content-Type": "application/json",
      "sec-ch-ua-platform": "\"Android\"",
      "x-requested-with": "XMLHttpRequest",
      "sec-ch-ua": "\"Chromium\";v=\"134\", \"Not:A-Brand\";v=\"24\", \"Android WebView\";v=\"134\"",
      "sec-ch-ua-mobile": "?1",
      "Origin": "https://v8mobile.hut.edu.cn",
      "Sec-Fetch-Site": "same-origin",
      "Sec-Fetch-Mode": "cors",
      "Sec-Fetch-Dest": "empty",
      "Referer": "https://v8mobile.hut.edu.cn/bathroom/selectCloseDeviceValve?openid=$openid",
      "Accept-Language": "zh-CN,zh;q=0.9,en-US;q=0.8,en;q=0.7",
      "Cookie": "userToken=$token; Domain=v8mobile.hut.edu.cn; Path=/; JSESSIONID=$JSESSIONID"
    };
    Map<String, dynamic> params = {
      "openid": openid,
    };
    Map<String, dynamic> data = {
      "openid": openid,
    };

    return await _request
        .post(url, params: params, data: data, options: options)
        .then((value) {
      var data = ResponseUtils.transformObj(value);
      bool isHave = data["result"] == "000000";
      if (isHave) {
        // logger.i(data["data"].first["poscode"]);
        String poscode = data["data"].first["poscode"];
        return [poscode];
      } else {
        return [];
      }
    });
  }

  /// 开始洗澡
  /// [device] 设备
  /// return 是否成功
  Future<bool> startHotWater({required String device}) async {
    String token =await getToken();
    String url = "https://v8mobile.hut.edu.cn/boiling/termcodeOpenValve";
    Options options =
        _request.cacheOptions.copyWith(policy: CachePolicy.noCache).toOptions();
    List openidls = await getOpenid();
    String openid = openidls[0];
    String JSESSIONID = openidls[1];
    options.headers = {
      "openid": openid,
      "User-Agent": "Mozilla/5.0 (Linux; Android 15; 24129PN74C Build/AQ3A.240812.002; wv) AppleWebKit/537.36 (KHTML, like Gecko) Version/4.0 Chrome/134.0.6998.39 Mobile Safari/537.36 SuperApp",
      "Connection": "keep-alive",
      "Accept": "application/json, text/javascript, */*; q=0.01",
      "Accept-Encoding": "gzip, deflate, br, zstd",
      "Content-Type": "application/json",
      "sec-ch-ua-platform": "\"Android\"",
      "x-requested-with": "XMLHttpRequest",
      "sec-ch-ua": "\"Chromium\";v=\"134\", \"Not:A-Brand\";v=\"24\", \"Android WebView\";v=\"134\"",
      "sec-ch-ua-mobile": "?1",
      "Origin": "https://v8mobile.hut.edu.cn",
      "Sec-Fetch-Site": "same-origin",
      "Sec-Fetch-Mode": "cors",
      "Sec-Fetch-Dest": "empty",
      "Referer": "https://v8mobile.hut.edu.cn/boiling/termcodeOpenValve?openid=$openid",
      "Accept-Language": "zh-CN,zh;q=0.9,en-US;q=0.8,en;q=0.7",
      "Cookie": "userToken=$token; Domain=v8mobile.hut.edu.cn; Path=/; JSESSIONID=$JSESSIONID"
    };
    Map<String, dynamic> params = {
      "openid": openid,
    };
    Map<String, dynamic> data = {
      "openid": openid,
      "poscode": device,
    };
    return await _request
        .post(url, params: params, data: data, options: options)
        .then((value) {
      // logger.i(value);
      var data = ResponseUtils.transformObj(value);
      // logger.i(data["resultData"]["result"] == "000000");
      return data["success"];
    });
  }

  /// 结束洗澡
  /// [device] 设备
  /// return 是否成功
  Future<bool> stopHotWater({required String device}) async {
    String token =await getToken();
    String url = "https://v8mobile.hut.edu.cn/boiling/endUse";
    Options options =
        _request.cacheOptions.copyWith(policy: CachePolicy.noCache).toOptions();
    List openidls = await getOpenid();
    String openid = openidls[0];
    String JSESSIONID = openidls[1];
    options.headers = {
      "openid": openid,
      "User-Agent": "Mozilla/5.0 (Linux; Android 15; 24129PN74C Build/AQ3A.240812.002; wv) AppleWebKit/537.36 (KHTML, like Gecko) Version/4.0 Chrome/134.0.6998.39 Mobile Safari/537.36 SuperApp",
      "Connection": "keep-alive",
      "Accept": "application/json, text/javascript, */*; q=0.01",
      "Accept-Encoding": "gzip, deflate, br, zstd",
      "Content-Type": "application/json",
      "sec-ch-ua-platform": "\"Android\"",
      "x-requested-with": "XMLHttpRequest",
      "sec-ch-ua": "\"Chromium\";v=\"134\", \"Not:A-Brand\";v=\"24\", \"Android WebView\";v=\"134\"",
      "sec-ch-ua-mobile": "?1",
      "Origin": "https://v8mobile.hut.edu.cn",
      "Sec-Fetch-Site": "same-origin",
      "Sec-Fetch-Mode": "cors",
      "Sec-Fetch-Dest": "empty",
      "Referer": "https://v8mobile.hut.edu.cn/boiling/endUse?openid=$openid",
      "Accept-Language": "zh-CN,zh;q=0.9,en-US;q=0.8,en;q=0.7",
      "Cookie": "userToken=$token; Domain=v8mobile.hut.edu.cn; Path=/; JSESSIONID=$JSESSIONID"
    };
    Map<String, dynamic> params = {
      "openid": openid,
    };
    Map<String, dynamic> data = {
      "openid": openid,
      "poscode": device,
      "openappid": "",
    };
    return await _request
        .post(url, params: params, data: data, options: options)
        .then((value) {
      // logger.i(value);
      var data = ResponseUtils.transformObj(value);
      // logger.i(data["resultData"]["result"] == "000000");
      return data["resultData"]["result"] == "000000";
    });
  }

  /// 获取校园卡余额
  /// return 余额
  Future<String> getCardBalance() async {
    String token = await getToken();
    String url = "https://v8mobile.hut.edu.cn/homezzdx/openHomePage";
    Options options =
        _request.cacheOptions.copyWith(policy: CachePolicy.noCache).toOptions();
    Map<String, dynamic> params = {
      "X-Id-Token": token,
    };
    return await _request
        .get(url, params: params, options: options)
        .then((value) {
      // logger.i(value.data);
      Document doc = parse(value.data);
      var list = doc.getElementsByTagName("span").where((element) {
        return element.attributes["name"] == "showbalanceid";
      }).toList();
      if (list.isNotEmpty) {
        return list.first.text.replaceAll("主钱包余额:￥", "");
      } else {
        return "null";
      }
    });
  }
}
