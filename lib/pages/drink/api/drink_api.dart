import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// 慧生活798 接口统一返回结构
class DrinkApiResult<T> {
  const DrinkApiResult({
    required this.success,
    required this.code,
    this.msg = "",
    this.data,
  });

  final bool success;
  final int code;
  final String msg;
  final T? data;

  /// 服务端约定 -99 表示登录态失效
  bool get isSessionExpired => code == -99;
}

/// 设备运行状态（ui/app/dev/status）
class DrinkDeviceStatus {
  const DrinkDeviceStatus({
    required this.deviceStatus,
    required this.geneStatus,
  });

  /// 设备链路状态，0 表示离线
  final int deviceStatus;

  /// 业务状态，99 空闲、98 禁用、其余视为运行中
  final int geneStatus;

  bool get isOffline => deviceStatus == 0;

  bool get isDisabled => geneStatus == 98;

  bool get isAvailable => deviceStatus != 0 && geneStatus == 99;
}

class DrinkApi {
  DrinkApi._privateConstructor();

  static final DrinkApi _instance = DrinkApi._privateConstructor();

  factory DrinkApi() {
    return _instance;
  }

  /// 与官方客户端保持一致的网关地址
  static const String _baseUrl = "https://i.ilife798.com/api/v1/";

  /// 参考实现 ApiConfig.VERSION_CODE
  static const String _versionCode = "3.1.9";

  /// 参考实现 ApiConfig.USER_AGENT
  static const String _userAgent = "Android_ilife798_$_versionCode";

  /// 参考实现 ApiConfig.APP_TYPE_DEVICE
  static const String _appTypeDevice = "1,1";

  /// 官方客户端标识，仓库内拿不到真实值，沿用旧值
  static const String _cid = "sbsbsbsbsbsbsbsbsbsbsb";

  static const String _tokenKey = "drink798UsrApiToken";
  static const String _loginFlagKey = "hui798IsLogin";

  final Dio _dio = Dio(
    BaseOptions(
      baseUrl: _baseUrl,
      connectTimeout: const Duration(seconds: 15),
      receiveTimeout: const Duration(seconds: 15),
      contentType: Headers.jsonContentType,
      headers: {
        "Accept-Language": "zh-Hans-CN;q=1",
        "User-Agent": _userAgent,
        "VersionCode": _versionCode,
      },
    ),
  );

  final Map<String, dynamic> _token = {"uid": "", "eid": "", "token": ""};

  Future<void>? _initFuture;

  /// 登录态失效回调，由 controller 注册
  void Function()? onSessionExpired;

  /// Token 懒加载，避免构造完成后立刻发起请求时读到空 token
  Future<void> _ensureInit() {
    return _initFuture ??= _initToken();
  }

  Future<void> _initToken() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_tokenKey);
    if (raw == null) {
      await prefs.setString(_tokenKey, jsonEncode(_token));
      return;
    }
    try {
      final decoded = jsonDecode(raw);
      if (decoded is Map) {
        decoded.forEach((key, value) {
          if (key is String && _token.containsKey(key)) {
            _token[key] = value;
          }
        });
      }
    } catch (e) {
      debugPrint("[drink] 本地凭据解析失败: $e");
    }
  }

  Future<void> _saveToken() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_tokenKey, jsonEncode(_token));
  }

  /// 清除本地登录态（凭据 + 登录标记）
  Future<void> clearLoginState() async {
    await _ensureInit();
    _token["uid"] = "";
    _token["eid"] = "";
    _token["token"] = "";
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_tokenKey, jsonEncode(_token));
    await prefs.setBool(_loginFlagKey, false);
  }

  int _nowMillis() => DateTime.now().millisecondsSinceEpoch;

  int _toInt(dynamic value, {int fallback = -1}) {
    if (value is int) return value;
    if (value is num) return value.toInt();
    return int.tryParse(value?.toString() ?? "") ?? fallback;
  }

  String _networkErrorMessage(DioException e) {
    switch (e.type) {
      case DioExceptionType.connectionTimeout:
      case DioExceptionType.sendTimeout:
      case DioExceptionType.receiveTimeout:
        return "网络连接超时，请稍后重试";
      case DioExceptionType.connectionError:
        return "网络连接失败，请检查网络";
      default:
        final status = e.response?.statusCode;
        if (status != null) return "服务器返回异常（HTTP $status）";
        return "网络异常，请稍后重试";
    }
  }

  /// 统一请求入口：拼接鉴权头、解析业务码、处理 -99 登录态失效
  Future<DrinkApiResult<T>> _request<T>(
    String path, {
    String method = "GET",
    Map<String, dynamic>? query,
    Map<String, dynamic>? body,
    bool auth = false,
    bool withAppType = false,
    ResponseType? responseType,
    T? Function(dynamic data)? parse,
  }) async {
    await _ensureInit();

    final Map<String, dynamic> headers = {};
    if (auth || withAppType) {
      headers["ApplicationType"] = _appTypeDevice;
    }
    if (auth) {
      headers["Authorization"] = _token["token"];
    }

    try {
      final response = await _dio.request<dynamic>(
        path,
        data: body,
        queryParameters: query,
        options: Options(
          method: method,
          responseType: responseType,
          headers: headers.isEmpty ? null : headers,
        ),
      );
      return await _parseBody<T>(path, response.data, parse);
    } on DioException catch (e) {
      final message = _networkErrorMessage(e);
      debugPrint("[drink] $method $path 请求失败: $message");
      return DrinkApiResult<T>(success: false, code: -1, msg: message);
    }
  }

  Future<DrinkApiResult<T>> _parseBody<T>(
    String path,
    dynamic raw,
    T? Function(dynamic data)? parse,
  ) async {
    if (raw is! Map) {
      debugPrint("[drink] $path 返回格式异常");
      return DrinkApiResult<T>(success: false, code: -1, msg: "接口返回格式异常");
    }

    final body = Map<String, dynamic>.from(raw);
    final code = _toInt(body["code"]);
    final msg = (body["msg"] ?? body["message"] ?? "").toString().trim();

    if (code == -99) {
      await clearLoginState();
      onSessionExpired?.call();
    }

    if (code != 0) {
      final text = msg.isNotEmpty ? msg : "操作失败（code: $code）";
      debugPrint("[drink] $path 失败: code=$code msg=$text");
      return DrinkApiResult<T>(success: false, code: code, msg: text);
    }

    final rawData = body["data"];
    T? data;
    if (parse != null) {
      data = parse(rawData);
    } else if (rawData == null || rawData is T) {
      data = rawData;
    }
    return DrinkApiResult<T>(success: true, code: code, msg: msg, data: data);
  }

  /// 获取慧生活798图形验证码
  ///
  /// [key] 为图形验证码 key，需与发送短信验证码时传入的 s 保持一致。
  Future<Uint8List> userCaptcha({required String key}) async {
    await _ensureInit();
    try {
      final response = await _dio.get<dynamic>(
        "captcha/",
        queryParameters: {"s": key, "r": _nowMillis().toString()},
        options: Options(responseType: ResponseType.bytes),
      );
      final data = response.data;
      if (data is Uint8List) return data;
      if (data is List<int>) return Uint8List.fromList(data);
      return Uint8List(0);
    } on DioException catch (e) {
      debugPrint("[drink] captcha 获取失败: ${_networkErrorMessage(e)}");
      return Uint8List(0);
    }
  }

  /// 获取短信验证码
  Future<DrinkApiResult<dynamic>> userMessageCode({
    required String captchaKey,
    required String photoCode,
    required String phone,
  }) {
    return _request<dynamic>(
      "acc/login/code",
      method: "POST",
      body: {"s": captchaKey, "authCode": photoCode, "un": phone},
    );
  }

  /// 开始登录
  Future<DrinkApiResult<dynamic>> userLogin({
    required String phone,
    required String messageCode,
  }) async {
    final result = await _request<Map<String, dynamic>>(
      "acc/login",
      method: "POST",
      withAppType: true,
      body: {
        "openCode": "",
        "authCode": messageCode,
        "un": phone,
        "cid": _cid,
      },
      parse: (data) {
        if (data is! Map) return null;
        return Map<String, dynamic>.from(data);
      },
    );

    if (!result.success) return result;

    final al = result.data?["al"];
    if (al is! Map) {
      return const DrinkApiResult(success: false, code: -1, msg: "登录失败：未获取到账号凭据");
    }

    _token["uid"] = al["uid"]?.toString() ?? "";
    _token["eid"] = al["eid"]?.toString() ?? "";
    _token["token"] = al["token"]?.toString() ?? "";
    if ((_token["token"] as String).isEmpty) {
      return const DrinkApiResult(success: false, code: -1, msg: "登录失败：凭据为空");
    }

    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_tokenKey, jsonEncode(_token));
    await prefs.setBool(_loginFlagKey, true);
    return const DrinkApiResult(success: true, code: 0);
  }

  /// 获取设备列表（已收藏设备）
  Future<DrinkApiResult<List<Map<String, dynamic>>>> deviceList() async {
    final result = await _request<Map<String, dynamic>>(
      "ui/app/master",
      auth: true,
      parse: (data) {
        if (data is! Map) return null;
        return Map<String, dynamic>.from(data);
      },
    );

    if (!result.success) {
      return DrinkApiResult(success: false, code: result.code, msg: result.msg);
    }

    final data = result.data;
    if (data == null || data["account"] == null) {
      return DrinkApiResult(
        success: false,
        code: -99,
        msg: "登录已失效，请重新登录",
      );
    }

    final favos = data["favos"];
    if (favos is! List) {
      return DrinkApiResult(
        success: true,
        code: 0,
        data: <Map<String, dynamic>>[],
      );
    }

    final devices = <Map<String, dynamic>>[];
    for (final item in favos) {
      if (item is! Map) continue;
      final gene = item["gene"];
      final bm = item["bm"];
      devices.add({
        "id": item["id"]?.toString() ?? "",
        "name": item["name"]?.toString() ?? "",
        "geneStatus": _toInt(gene is Map ? gene["status"] : null, fallback: 0),
        "dtype": _toInt(bm is Map ? bm["dtype"] : null, fallback: 0),
      });
    }

    return DrinkApiResult(
      success: true,
      code: 0,
      data: devices.reversed.toList(),
    );
  }

  /// 收藏或取消收藏设备
  Future<DrinkApiResult<dynamic>> favoDevice({
    required String id,
    required bool isUnFavo,
  }) {
    return _request<dynamic>(
      "dev/favo",
      auth: true,
      query: {"did": id, "remove": isUnFavo ? "1" : "0"},
    );
  }

  /// 解析扫码结果，返回设备 ID
  Future<DrinkApiResult<String>> resolveQrDevice({required String id}) {
    if (id.isEmpty) {
      return Future.value(
        const DrinkApiResult(success: false, code: -1, msg: "设备编号为空"),
      );
    }
    return _request<String>(
      "qr/use",
      auth: true,
      query: {"id": id},
      parse: (data) {
        if (data is! Map) return "";
        final dev = data["dev"];
        return dev is Map ? dev["id"]?.toString() ?? "" : "";
      },
    );
  }

  /// 开始喝水
  ///
  /// [ptype] 91 为钱包支付，21 为支付宝免密支付。
  Future<DrinkApiResult<dynamic>> startDrink({
    required String id,
    int ptype = 91,
  }) {
    return _request<dynamic>(
      "dev/start",
      auth: true,
      query: {
        "did": id,
        "upgrade": "true",
        "ptype": ptype.toString(),
        "args": "",
        "rcp": "false",
        "cnt": "1",
      },
    );
  }

  /// 结束喝水
  Future<DrinkApiResult<dynamic>> endDrink({required String id}) {
    return _request<dynamic>(
      "dev/end",
      auth: true,
      query: {"did": id, "rcp": "false"},
    );
  }

  /// 检测设备状态
  Future<DrinkApiResult<DrinkDeviceStatus>> deviceStatus({
    required String id,
  }) {
    return _request<DrinkDeviceStatus>(
      "ui/app/dev/status",
      auth: true,
      query: {"did": id, "more": "false"},
      parse: (data) {
        if (data is! Map) return null;
        final device = data["device"];
        if (device is! Map) return null;
        final gene = device["gene"];
        return DrinkDeviceStatus(
          deviceStatus: _toInt(device["status"], fallback: 1),
          geneStatus: _toInt(gene is Map ? gene["status"] : null, fallback: 0),
        );
      },
    );
  }

  /// 获取Token
  Future<String> getToken() async {
    await _ensureInit();
    return _token["token"]?.toString() ?? "";
  }

  /// 设置Token
  Future<void> setToken({required String token}) async {
    await _ensureInit();
    _token["token"] = token;
    await _saveToken();
  }
}
