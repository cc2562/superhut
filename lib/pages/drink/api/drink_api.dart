import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:superhut/pages/drink/api/oct_signature.dart';
import 'package:superhut/security/credential_store.dart';

/// acc/login 的签名实现已完全还原，见 [octComputeSignature]。
///
/// 旧版本用 `--dart-define=DRINK_SIGN_SALT` 注入盐再算
/// `md5("authCode=..&un=..<salt>")`，那套推测是错的：
/// 官方真正的算法是 `blake3_keyed(secret8 + strD + strB + strC, strF)`，
/// 与盐无关，也不再需要任何构建期注入。

/// acc/login 的请求体：只有短信码与手机号。
///
/// 不能带 `cid` / `openCode`：那是广告渠道标识，混进登录体会让服务端在
/// 会话建立阶段回「请升级到新版本」（见 ilife798 提交 8703df5 的实测结论）。
Map<String, dynamic> drinkLoginBody({
  required String phone,
  required String code,
}) {
  return {"authCode": code, "un": phone};
}

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

  /// 官方客户端的 versionName，服务端按它做版本校验。
  ///
  /// 官方请求头是 `VersionCode: <versionName>` + `User-Agent: Android_ilife798_<versionName>`，
  /// 值取自 APK 的 `packageInfo.versionName`（见官方 `k4/a.a()`）。
  /// 当前官方最新包 versionName = 3.1.10（versionCode 31010），旧包 3.1.7。
  /// 之前的 3.1.9 不是任何已发布版本，服务端会回「请升级最新版应用」。
  /// 需要快速对比不同版本时：`--dart-define=DRINK_VERSION_CODE=3.1.7`。
  static const String _versionCode = String.fromEnvironment(
    "DRINK_VERSION_CODE",
    defaultValue: "3.1.10",
  );

  /// 参考实现 ApiConfig.USER_AGENT
  ///
  /// 服务端按 UA 前缀识别平台（`Android_` / `iOS_`），并据此选择服务端侧的校验分支：
  /// 本项目按安卓客户端声明，签名算法也是从安卓版的 `liboct.so` 还原的。
  static const String _userAgent = "Android_ilife798_$_versionCode";

  /// 参考实现 ApiConfig.APP_TYPE_DEVICE
  static const String _appTypeDevice = "1,1";

  /// 登录接口路径（签名里的 `strC` 由它推导：去掉非字母数字后取后 8 位）。
  static const String _loginPath = "/api/v1/acc/login";

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

  /// 服务端与本机的时钟差（秒）。签名里的 `strD` 取的是**服务端时间**，
  /// 由任意响应的 `Date` 头推算，登录前先打过图形码 / 短信码接口即可完成对齐。
  int _serverOffsetSeconds = 0;

  /// 是否已成功对齐服务端时钟；未对齐时签名可能落在错误的 30 秒窗口。
  bool _serverClockSynced = false;

  /// 登录态失效回调，由 controller 注册
  void Function()? onSessionExpired;

  /// Token 懒加载，避免构造完成后立刻发起请求时读到空 token
  Future<void> _ensureInit() {
    return _initFuture ??= _initToken();
  }

  Future<void> _initToken() async {
    // 饮水 token 属于凭据，走系统安全存储而不是 SharedPreferences。
    final raw = await CredentialStore.instance.read(_tokenKey);
    if (raw == null) {
      await CredentialStore.instance.write(_tokenKey, jsonEncode(_token));
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
    await CredentialStore.instance.write(_tokenKey, jsonEncode(_token));
  }

  /// 清除本地登录态（凭据 + 登录标记）
  Future<void> clearLoginState() async {
    await _ensureInit();
    _token["uid"] = "";
    _token["eid"] = "";
    _token["token"] = "";
    await CredentialStore.instance.write(_tokenKey, jsonEncode(_token));
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_loginFlagKey, false);
  }

  int _nowMillis() => DateTime.now().millisecondsSinceEpoch;

  /// 当前的服务端时间（epoch 秒，未对齐 30 秒）。
  int _serverEpochSeconds() =>
      DateTime.now().millisecondsSinceEpoch ~/ 1000 + _serverOffsetSeconds;

  static const Map<String, int> _httpMonths = {
    "JAN": 1,
    "FEB": 2,
    "MAR": 3,
    "APR": 4,
    "MAY": 5,
    "JUN": 6,
    "JUL": 7,
    "AUG": 8,
    "SEP": 9,
    "OCT": 10,
    "NOV": 11,
    "DEC": 12,
  };

  /// 解析 RFC 1123 形式的 `Date` 头（`Mon, 09 Nov 2026 03:29:32 GMT`）。
  ///
  /// 不用 `HttpDate`：`dart:io` 在 Web 端不可用，而这里只需要这一个格式。
  DateTime? _parseHttpDate(String raw) {
    final m = RegExp(
      r'^[A-Za-z]{3},\s*(\d{1,2})\s+([A-Za-z]{3})\s+(\d{4})\s+'
      r'(\d{2}):(\d{2}):(\d{2})',
    ).firstMatch(raw.trim());
    if (m == null) return null;
    final month = _httpMonths[m.group(2)!.toUpperCase()];
    if (month == null) return null;
    return DateTime.utc(
      int.parse(m.group(3)!),
      month,
      int.parse(m.group(1)!),
      int.parse(m.group(4)!),
      int.parse(m.group(5)!),
      int.parse(m.group(6)!),
    );
  }

  void _syncServerClock(String? dateHeader) {
    if (dateHeader == null || dateHeader.isEmpty) return;
    final server = _parseHttpDate(dateHeader);
    if (server == null) return;
    _serverOffsetSeconds = server.difference(DateTime.now()).inSeconds;
    if (!_serverClockSynced && kDebugMode) {
      debugPrint(
        "[drink] 服务端时钟对齐: offset=${_serverOffsetSeconds}s (Date=$dateHeader)",
      );
    }
    _serverClockSynced = true;
  }

  /// 打印一次登录签名的全部中间量，方便把手机端日志直接贴出来比对。
  ///
  /// 只在 debug 构建输出：`kDebugMode` 是编译期常量，release 下整段被裁掉。
  void _printSignDiagnostics(OctSignature signature) {
    if (!kDebugMode) return;
    final now = DateTime.now();
    debugPrint("[oct] ================ acc/login 签名诊断 ================");
    debugPrint(
      "[oct] 本机时间 ${now.toIso8601String()} "
      "(epoch ${now.millisecondsSinceEpoch ~/ 1000})",
    );
    debugPrint(
      "[oct] 服务端偏移 ${_serverOffsetSeconds}s 已对齐=$_serverClockSynced",
    );
    debugPrint(
      "[oct] epoch=${signature.epoch} 对齐后=${signature.alignedEpoch} "
      "path=${signature.path}",
    );
    for (final line in signature.describe().split("\n")) {
      debugPrint("[oct] $line");
    }
    debugPrint(
      "[oct] sign 长度=${signature.sign.length} "
      "VersionCode=$_versionCode UA=$_userAgent",
    );
    debugPrint("[oct] ====================================================");
  }

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
    // 官方客户端在初始化时就把 Authorization 写进全局头（未登录时为空串），
    // 登录这类未鉴权接口同样会带上这个空头，这里保持一致。
    headers["Authorization"] = _token["token"] ?? "";

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
      _syncServerClock(response.headers.value("date"));
      return await _parseBody<T>(path, response.realUri, response.data, parse);
    } on DioException catch (e) {
      _syncServerClock(e.response?.headers.value("date"));
      final message = _networkErrorMessage(e);
      debugPrint("[drink] $method ${e.requestOptions.uri} 请求失败: $message");
      final rawError = e.response?.data;
      if (rawError != null) {
        debugPrint(
          "[drink] $method ${e.requestOptions.uri} 响应: ${_clipLog(rawError)}",
        );
      }
      return DrinkApiResult<T>(success: false, code: -1, msg: message);
    }
  }

  /// 失败日志里响应体的最大保留长度，避免刷屏
  static const int _maxLogChars = 800;

  String _clipLog(dynamic raw) {
    final text = raw is String ? raw : raw?.toString() ?? "";
    if (text.length <= _maxLogChars) return text;
    return "${text.substring(0, _maxLogChars)}...(已截断)";
  }

  Future<DrinkApiResult<T>> _parseBody<T>(
    String path,
    Uri? uri,
    dynamic raw,
    T? Function(dynamic data)? parse,
  ) async {
    if (raw is! Map) {
      debugPrint("[drink] $path 返回格式异常: ${_clipLog(raw)}");
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
      // 失败时把完整地址与响应原文打出来：服务端只回一句「请升级到新版本」时，
      // 靠 code 与原始 body 才能判断是协议被拒还是验签失败。
      debugPrint("[drink] ${uri ?? path} 失败: code=$code msg=$text");
      debugPrint("[drink] ${uri ?? path} 响应: ${_clipLog(raw)}");
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

  /// 开始登录（设备通道 ApplicationType 1,1）
  ///
  /// 协议对齐官方客户端（参考 ilife798 提交 8703df5）：
  /// - body 就是裸的 `{"authCode": 短信码, "un": 手机号}`，**不能**带 cid / openCode：
  ///   cid 是广告渠道标识，混进登录体会让服务端在会话建立阶段直接回
  ///   「请升级到新版本」，与本项目此前失效的现象一致；
  /// - 签名放 query：`acc/login?sign=<32 位小写 hex>`，算法见 [octComputeSignature]；
  /// - `strD` 取服务端时间，所以签名前要先完成时钟对齐
  ///   （登录前必然先请求过图形码 / 短信码接口，[Date] 头已把偏移校准）。
  Future<DrinkApiResult<dynamic>> userLogin({
    required String phone,
    required String messageCode,
  }) async {
    final signature = octComputeSignature(
      params: {"authCode": messageCode, "un": phone},
      path: _loginPath,
      epochSeconds: _serverEpochSeconds(),
      token: (_token["token"] as String?) ?? "",
    );
    _printSignDiagnostics(signature);

    final result = await _request<Map<String, dynamic>>(
      "acc/login",
      method: "POST",
      withAppType: true,
      query: {"sign": signature.sign},
      body: drinkLoginBody(phone: phone, code: messageCode),
      parse: (data) {
        if (data is! Map) return null;
        return Map<String, dynamic>.from(data);
      },
    );

    if (!result.success) {
      // 服务端只回一句「请升级到新版本」时，靠这几项才能区分
      // 「协议被拒」「签名不被接受」「VersionCode 与 UA 不匹配」。
      debugPrint(
        "[drink] acc/login 诊断: ApplicationType=$_appTypeDevice "
        "VersionCode=$_versionCode sign=${signature.sign} UA=$_userAgent",
      );
      return result;
    }

    final al = result.data?["al"];
    if (al is! Map) {
      return const DrinkApiResult(
        success: false,
        code: -1,
        msg: "登录失败：未获取到账号凭据",
      );
    }

    _token["uid"] = al["uid"]?.toString() ?? "";
    _token["eid"] = al["eid"]?.toString() ?? "";
    _token["token"] = al["token"]?.toString() ?? "";
    if ((_token["token"] as String).isEmpty) {
      return const DrinkApiResult(success: false, code: -1, msg: "登录失败：凭据为空");
    }

    await CredentialStore.instance.write(_tokenKey, jsonEncode(_token));
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_loginFlagKey, true);
    if (kDebugMode) {
      debugPrint(
        "[oct] 登录成功：服务端已接受该 sign（uid=${_token["uid"]} token 长度="
        "${(_token["token"] as String).length}）",
      );
    }
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
      return DrinkApiResult(success: false, code: -99, msg: "登录已失效，请重新登录");
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
  Future<DrinkApiResult<DrinkDeviceStatus>> deviceStatus({required String id}) {
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
