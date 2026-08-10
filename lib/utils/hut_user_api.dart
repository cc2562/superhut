import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:dio_cache_interceptor/dio_cache_interceptor.dart';
import 'package:html/dom.dart';
import 'package:html/parser.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';

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

/// Result of a pure HUT SMS auth path/response helper (no storage side effects).
///
/// Reverse-engineered from the official iOS `SWSuperApp` binary:
/// `smsInit` / `smsSend` / `smsLogin` under `/token/passwordless/...`.
class HutAuthResult {
  const HutAuthResult({
    required this.success,
    this.message = '',
    this.nonce,
    this.needMfa = false,
  });

  final bool success;
  final String message;
  final String? nonce;
  final bool needMfa;
}

const String _kDefaultHutAuthFailureMessage = '操作失败，请稍后重试';

String buildHutSmsInitPath() => '/token/passwordless/smsInit';

String buildHutSmsSendPath({required String mobile, required String nonce}) {
  return '/token/passwordless/smsSend?'
      'mobile=${Uri.encodeQueryComponent(mobile)}'
      '&nonce=${Uri.encodeQueryComponent(nonce)}';
}

/// Builds the `smsLogin` query path.
///
/// Field contract matched against the official iOS client
/// (`+[SWUserModel smsLoginWithMobile:smscode:complete:]`):
///   * `osType` MUST be `"iOS"` — sending `"android"` can be rejected by the
///     mycas SSO origin/device check before a usable session is issued.
///   * `clientId` defaults to `"CLIENT_ID"` when the app has not persisted one.
///   * `deviceId` mirrors the official UUID.
String buildHutSmsLoginPath({
  required String mobile,
  required String smscode,
  required String appId,
  required String deviceId,
  required String osType,
  required String geo,
  required String nonce,
  String clientId = 'CLIENT_ID',
}) {
  return '/token/passwordless/smsLogin?'
      'mobile=${Uri.encodeQueryComponent(mobile)}'
      '&smscode=${Uri.encodeQueryComponent(smscode)}'
      '&appId=${Uri.encodeQueryComponent(appId)}'
      '&deviceId=${Uri.encodeQueryComponent(deviceId)}'
      '&osType=${Uri.encodeQueryComponent(osType)}'
      '&geo=${Uri.encodeQueryComponent(geo)}'
      '&nonce=${Uri.encodeQueryComponent(nonce)}'
      '&clientId=${Uri.encodeQueryComponent(clientId)}';
}

String normalizeHutMobile(String mobile) => mobile.trim().replaceAll(' ', '');

bool isPlausibleHutMobile(String mobile) {
  return RegExp(r'^1\d{10}$').hasMatch(normalizeHutMobile(mobile));
}

HutAuthResult parseHutSmsInitResponse(dynamic data) {
  if (data is! Map) {
    return const HutAuthResult(
      success: false,
      message: _kDefaultHutAuthFailureMessage,
    );
  }

  final envelope = Map<dynamic, dynamic>.from(data);
  final payload = envelope['data'];
  final payloadMap = payload is Map ? Map<dynamic, dynamic>.from(payload) : null;
  final message = _hutAuthMessage(envelope, payloadMap);
  final needMfa = hutResponseIndicatesNeedMfa(envelope);

  if (!_isHutSuccessCode(envelope['code']) || payloadMap == null) {
    return HutAuthResult(success: false, message: message, needMfa: needMfa);
  }

  final nonce = payloadMap['nonce']?.toString();
  if (nonce == null || nonce.isEmpty) {
    return HutAuthResult(success: false, message: message, needMfa: needMfa);
  }

  return HutAuthResult(
    success: true,
    message: message == _kDefaultHutAuthFailureMessage ? '' : message,
    nonce: nonce,
    needMfa: needMfa,
  );
}

HutAuthResult parseHutSmsSendResponse(dynamic data) {
  if (data is! Map) {
    return const HutAuthResult(
      success: false,
      message: _kDefaultHutAuthFailureMessage,
    );
  }

  final envelope = Map<dynamic, dynamic>.from(data);
  final payload = envelope['data'];
  final payloadMap = payload is Map ? Map<dynamic, dynamic>.from(payload) : null;
  final message = _hutAuthMessage(envelope, payloadMap);
  final needMfa = hutResponseIndicatesNeedMfa(envelope);

  if (!_isHutSuccessCode(envelope['code'])) {
    return HutAuthResult(success: false, message: message, needMfa: needMfa);
  }

  // Some deployments rotate/echo nonce on send success; prefer it when present.
  final sendNonce = payloadMap?['nonce']?.toString();
  return HutAuthResult(
    success: true,
    message: message == _kDefaultHutAuthFailureMessage ? '' : message,
    nonce: (sendNonce != null && sendNonce.isNotEmpty) ? sendNonce : null,
    needMfa: needMfa,
  );
}

HutAuthResult parseHutSmsLoginTokenData(dynamic data) {
  if (data is! Map) {
    return const HutAuthResult(
      success: false,
      message: _kDefaultHutAuthFailureMessage,
    );
  }

  final envelope = Map<dynamic, dynamic>.from(data);
  final payload = envelope['data'];
  final payloadMap = payload is Map ? Map<dynamic, dynamic>.from(payload) : null;
  final message = _hutAuthMessage(envelope, payloadMap);
  final needMfa = hutResponseIndicatesNeedMfa(envelope);

  // Passwordless success is a single-step token store: the official iOS
  // success handler stores `data.idToken` VERBATIM. It never decodes the JWT
  // (HutPortalSession.fromLoginData did that and could return an embedded
  // idToken mycas never issued → "登录状态已失效"). We just need a non-empty
  // token here; the raw value is persisted by the caller.
  if (!_isHutSuccessCode(envelope['code']) || payloadMap == null) {
    return HutAuthResult(success: false, message: message, needMfa: needMfa);
  }

  final idToken = payloadMap['idToken']?.toString().trim() ?? '';
  if (idToken.isEmpty) {
    return HutAuthResult(success: false, message: message, needMfa: needMfa);
  }

  return HutAuthResult(
    success: true,
    message: message == _kDefaultHutAuthFailureMessage ? '' : message,
    needMfa: needMfa,
  );
}

bool hutResponseIndicatesNeedMfa(dynamic data) {
  if (data is! Map) {
    return false;
  }

  final envelope = Map<dynamic, dynamic>.from(data);
  if (_mapIndicatesNeedMfa(envelope)) {
    return true;
  }

  final payload = envelope['data'];
  if (payload is Map) {
    return _mapIndicatesNeedMfa(Map<dynamic, dynamic>.from(payload));
  }
  return false;
}

bool _isHutSuccessCode(dynamic code) => code?.toString() == '0';

bool _isTruthyHutFlag(dynamic value) {
  if (value == true || value == 1) {
    return true;
  }
  final text = value?.toString().trim().toLowerCase();
  return text == 'true' || text == '1';
}

bool _mapIndicatesNeedMfa(Map<dynamic, dynamic> map) {
  return _isTruthyHutFlag(map['needMfa']) ||
      _isTruthyHutFlag(map['need_mfa']) ||
      _isTruthyHutFlag(map['need']);
}

const String _kHutSmsSessionInvalidMessage = '验证码已失效，请重新获取';

/// True when mycas returned a bare/opaque failure that usually means the SMS
/// session (nonce) is no longer usable for login.
bool isHutSmsSessionInvalidMessage(String message) {
  final trimmed = message.trim();
  if (trimmed.isEmpty) {
    return false;
  }
  final lower = trimmed.toLowerCase();
  if (lower == 'bad request' ||
      lower == 'badrequest' ||
      lower.contains('nonce invalid') ||
      lower.contains('nonce expire') ||
      lower.contains('invalid nonce')) {
    return true;
  }
  return trimmed == '请求无效' ||
      trimmed == '请求参数错误' ||
      trimmed.contains('验证码已失效') ||
      trimmed.contains('验证码已过期') ||
      trimmed.contains('验证码失效') ||
      trimmed.contains('验证码过期') ||
      (trimmed.contains('nonce') &&
          (trimmed.contains('无效') ||
              trimmed.contains('过期') ||
              trimmed.contains('失效')));
}

String localizeHutAuthMessage(String message) {
  final trimmed = message.trim();
  if (trimmed.isEmpty) {
    return _kDefaultHutAuthFailureMessage;
  }
  if (isHutSmsSessionInvalidMessage(trimmed)) {
    return _kHutSmsSessionInvalidMessage;
  }

  final lower = trimmed.toLowerCase();
  if (lower.contains('phone number not equals') ||
      trimmed.contains('与接收验证码的手机号码不一致')) {
    return '手机号与获取验证码时不一致，请使用原手机号或重新获取';
  }
  if (lower.contains('secure mobile invalid') || trimmed.contains('安全手机无效')) {
    return '该手机号未绑定智慧工大安全手机';
  }
  if (lower == 'unauthorized' ||
      lower.contains('bad credentials') ||
      trimmed == '未授权') {
    return '账号或密码错误';
  }
  if (lower == 'request parameter error' || trimmed == '请求参数错误') {
    return '请求参数错误，请重新获取验证码后再试';
  }
  return trimmed;
}

String _hutAuthMessage(
  Map<dynamic, dynamic> envelope, [
  Map<dynamic, dynamic>? data,
]) {
  final fromData = data?['message']?.toString().trim();
  if (fromData != null && fromData.isNotEmpty) {
    return localizeHutAuthMessage(fromData);
  }
  final fromEnvelope = envelope['message']?.toString().trim();
  if (fromEnvelope != null && fromEnvelope.isNotEmpty) {
    return localizeHutAuthMessage(fromEnvelope);
  }
  // mycas passwordless endpoints often return {"code":-1,"error":"..."} only.
  final fromError = envelope['error']?.toString().trim();
  if (fromError != null &&
      fromError.isNotEmpty &&
      fromError.toLowerCase() != 'bad request' &&
      fromError.toLowerCase() != 'unauthorized' &&
      fromError.toLowerCase() != 'internal server error') {
    return localizeHutAuthMessage(fromError);
  }
  if (fromError != null && fromError.toLowerCase() == 'bad request') {
    return _kHutSmsSessionInvalidMessage;
  }
  return _kDefaultHutAuthFailureMessage;
}

/// Maps a Dio/transport failure into [HutAuthResult].
///
/// mycas often encodes business failures as HTTP 4xx/5xx with a JSON body
/// (`code` / `error` / `message`). Those must surface the body text — not the
/// generic network copy — because the server may already have side effects
/// (e.g. SMS already sent) before returning a non-2xx status.
HutAuthResult hutAuthResultFromTransportError({
  int? statusCode,
  dynamic responseData,
}) {
  if (responseData != null) {
    if (responseData is Map) {
      final envelope = Map<dynamic, dynamic>.from(responseData);
      final payload = envelope['data'];
      final payloadMap = payload is Map ? Map<dynamic, dynamic>.from(payload) : null;
      final message = _hutAuthMessage(envelope, payloadMap);
      return HutAuthResult(
        success: false,
        message: message,
        needMfa: hutResponseIndicatesNeedMfa(envelope),
      );
    }
    final text = responseData.toString().trim();
    if (text.isNotEmpty) {
      return HutAuthResult(
        success: false,
        message: localizeHutAuthMessage(text),
      );
    }
  }
  return const HutAuthResult(success: false, message: '网络异常，请稍后重试');
}

/// Data Storage Manager for handling persistent storage operations

class FunctionItem {
  final String id;
  final String serviceName;
  final String servicePicUrl;
  final String serviceUrl;
  final String serviceType;
  final String tokenAccept;
  final String iconUrl;

  FunctionItem({
    required this.id,
    required this.serviceName,
    required this.servicePicUrl,
    required this.serviceUrl,
    required this.serviceType,
    required this.tokenAccept,
    required this.iconUrl,
  });
}

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
    final bytes = Uint8List(16); // 生成16字节（128位）的数组

    // 逐个填充字节（正确方式）
    for (var i = 0; i < bytes.length; i++) {
      bytes[i] = random.nextInt(256); // 生成0-255（包含）的随机整数
    }

    // 转换为大写的32位十六进制字符串
    return bytes
        .map((byte) => byte.toRadixString(16).padLeft(2, '0').toUpperCase())
        .join();
  }

  //static final HutUserApi _instance = HutUserApi._privateConstructor();

  //factory HutUserApi() {
  //   return _instance;
  // }

  // 网络管家
  final _request = RequestManager();

  // 用户凭证数据
  final Map<String, dynamic> _token = {"idToken": ""};

  /// 获取指纹
  /// return 指纹
  Future<String> getFingerprint() async {
    var uuid = const Uuid();
    return uuid.v4().replaceAll("-", "");
  }

  static const String _kMyCasBaseUrl = 'https://mycas.hut.edu.cn';
  static const String _kHutAppId = 'com.supwisdom.hut';
  // Matches the official iOS client version surfaced in X-Device-Infos.
  static const String _kHutAppVersion = '1.1.8';
  static const String _kHutLoginUserAgent = 'SWSuperApp/1.1.3(XiaomidadaXiaomi15)';

  /// Shared Dio for the mycas login/passwordless endpoints.
  ///
  /// mycas often encodes business failures (wrong code, invalid nonce, unbound
  /// mobile, …) as HTTP 4xx/5xx with a JSON body. Accept them so callers can
  /// parse `code`/`error`/`message` instead of collapsing to "网络异常".
  /// The official YYRequestManager injects `X-Device-Infos` on every request;
  /// mycas uses it for origin/device validation.
  Dio _smsLoginDio() {
    final dio = Dio();
    dio.options.baseUrl = _kMyCasBaseUrl;
    dio.options.connectTimeout = const Duration(seconds: 5);
    dio.options.receiveTimeout = const Duration(seconds: 15);
    dio.options.validateStatus = (status) => status != null && status < 600;
    dio.options.headers = {
      'User-Agent': _kHutLoginUserAgent,
      'Accept': 'application/json',
      'Accept-Language': 'zh-CN',
      'Content-Type': 'application/x-www-form-urlencoded',
      'X-Device-Infos':
          'packagename=$_kHutAppId;version=$_kHutAppVersion;system=iOS',
    };
    return dio;
  }

  /// 初始化密码less会话，获取 `nonce`。
  Future<HutAuthResult> smsInit() async {
    try {
      final response = await _smsLoginDio().get(buildHutSmsInitPath());
      return parseHutSmsInitResponse(response.data);
    } catch (error) {
      return _authResultFromTransportError(error);
    }
  }

  /// 发送短信验证码。
  Future<HutAuthResult> smsSend({
    required String mobile,
    required String nonce,
  }) async {
    final normalized = normalizeHutMobile(mobile);
    if (!isPlausibleHutMobile(normalized)) {
      return const HutAuthResult(success: false, message: '请输入正确的手机号');
    }
    try {
      // Official client posts form-urlencoded with empty body; params are query.
      final response = await _smsLoginDio().post(
        buildHutSmsSendPath(mobile: normalized, nonce: nonce),
        data: '',
      );
      return parseHutSmsSendResponse(response.data);
    } catch (error) {
      return _authResultFromTransportError(error);
    }
  }

  /// 短信验证码登录，成功后以 raw `data.idToken` 落盘。
  ///
  /// Matches the official iOS success handler (`sub_100079334` /
  /// `vercodeLoginSuccess`), which stores `data.idToken` VERBATIM into the
  /// token — it does NOT call `federation/federatedBinding` (that is for
  /// third-party federated login, not SMS) and does NOT JWT-decode the token.
  Future<HutAuthResult> smsLogin({
    required String mobile,
    required String smscode,
    required String nonce,
  }) async {
    final normalized = normalizeHutMobile(mobile);
    if (!isPlausibleHutMobile(normalized)) {
      return const HutAuthResult(success: false, message: '请输入正确的手机号');
    }
    if (smscode.trim().isEmpty) {
      return const HutAuthResult(success: false, message: '请输入验证码');
    }
    final deviceId = generateUuidV4();
    try {
      final response = await _smsLoginDio().post(
        buildHutSmsLoginPath(
          mobile: normalized,
          smscode: smscode.trim(),
          appId: _kHutAppId,
          deviceId: deviceId,
          osType: 'iOS',
          geo: '',
          nonce: nonce,
          clientId: 'CLIENT_ID',
        ),
        data: '',
      );
      return await _completeSmsLoginFromResponseData(
        responseData: response.data,
        mobile: normalized,
        deviceId: deviceId,
      );
    } catch (error) {
      return _authResultFromTransportError(error);
    }
  }

  Future<HutAuthResult> _completeSmsLoginFromResponseData({
    required dynamic responseData,
    required String mobile,
    required String deviceId,
  }) async {
    final parsed = parseHutSmsLoginTokenData(responseData);
    if (!parsed.success || responseData is! Map) {
      return parsed;
    }
    final data = responseData['data'];
    if (data is! Map) {
      return const HutAuthResult(success: false, message: '登录失败，请稍后重试');
    }
    // CRITICAL: store the RAW data.idToken, not a JWT-decoded variant, so
    // checkTokenValidity/CAS send exactly the token mycas issued.
    final idToken = data['idToken']?.toString().trim() ?? '';
    if (idToken.isEmpty) {
      return const HutAuthResult(success: false, message: '登录失败，请稍后重试');
    }
    final refreshToken = data['refreshToken']?.toString().trim() ?? '';

    final prefs = await SharedPreferences.getInstance();
    prefs.setString('hutToken', idToken);
    prefs.setString('hutRefreshToken', refreshToken);
    prefs.setString('deviceId', deviceId);
    // SMS sessions have no password; persist mobile so the page can refill it.
    prefs.setString('hutMobile', mobile);
    prefs.setString('loginType', 'hut');
    prefs.setBool('hutIsLogin', true);
    _token['idToken'] = idToken;
    return const HutAuthResult(success: true, message: '登录成功');
  }

  HutAuthResult _authResultFromTransportError(Object error) {
    if (error is DioException) {
      return hutAuthResultFromTransportError(
        statusCode: error.response?.statusCode,
        responseData: error.response?.data,
      );
    }
    return hutAuthResultFromTransportError();
  }

  /// 开始登录
  /// [username] 用户名
  /// [password] 密码
  /// return 是否成功
  Future<bool> userLogin({
    required String username,
    required String password,
  }) async {
    String passwordBase = Uri.encodeComponent(password);
    String deviceId = generateDeviceIdAlphabet();
    String clientId = generateUuidV4();
    print("开始登录");
    String loginUrl =
        "/token/password/passwordLogin?username=$username&password=$passwordBase&appId=com.supwisdom.hut&geo&deviceId=$deviceId&osType=android&clientId=$clientId&mfaState";
    final dio = Dio();
    dio.options.baseUrl = 'https://mycas.hut.edu.cn';
    dio.options.connectTimeout = Duration(seconds: 5);
    dio.options.receiveTimeout = Duration(seconds: 3);
    dio.options.headers = {
      'User-Agent': 'SWSuperApp/1.1.3(XiaomidadaXiaomi15)',
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
    if (data.keys.first != 'code') {
      //登录失败
      return false;
    }
    Map tokenData = data['data'];
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
    prefs.setString('loginType', 'hut');
    prefs.setBool('hutIsLogin', true);
    print(response.data);
    print("结束！！！！！！！！！！！！！！！！！！！！！！！！！！！！！！！！！！！！！！！！！！！！！！！！！！");
    return true;
  }

  /// 获取Token
  /// return Token
  Future<String> getToken() async {
    final prefs = await SharedPreferences.getInstance();
    if (prefs.getString('hutToken') != null) {
      //bool isv =await refreshToken();
      _token["idToken"] = prefs.getString('hutToken')!;
    }
    return _token["idToken"];
  }

  ///检查Token是否有效
  Future<bool> checkTokenValidity() async {
    String token = await getToken();
    if (token.isEmpty) {
      return false;
    }

    // SMS/passwordless sessions never persist hutUsername (they persist
    // hutMobile instead). The official iOS client does NOT run
    // userOnlineDetect right after an SMS login — it goes straight to
    // safety-check completion. userOnlineDetect with an empty username is
    // rejected by mycas ({"code":-1,...,"username error"}), which made a fresh
    // SMS token be falsely flagged as invalid. Trust fresh SMS tokens.
    final prefs = await SharedPreferences.getInstance();
    String username = prefs.getString('hutUsername')?.trim() ?? '';
    if (username.isEmpty) {
      return true;
    }

    String deviceId = prefs.getString('deviceId') ?? 'null';
    String url =
        "/token/login/userOnlineDetect?appId=com.supwisdom.hut&deviceId=$deviceId&username=$username";
    final dio = Dio();
    dio.options.baseUrl = 'https://mycas.hut.edu.cn';
    dio.options.connectTimeout = Duration(seconds: 5);
    dio.options.receiveTimeout = Duration(seconds: 3);
    dio.options.headers = {
      'User-Agent':
          'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/91.0.4472.124 Safari/537.36 Edg/91.0.864.64',
      'Accept': '*/*',
      'Accept-Encoding': 'gzip, deflate, br',
      'X-Id-Token': token,
    };
    Response response;
    response = await dio.post(url, data: {});
    Map data = response.data;
    bool isValid = false;
    //  print(data);
    if (data['code'] == -1) {
      isValid = false;
    } else if (data['code'] == 0) {
      isValid = true;
    }
    //  print(data['code']);
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
    String token = await getToken();
    String url = "https://v8mobile.hut.edu.cn/zdRedirect/toSingleMenu";
    Options options =
        _request.cacheOptions.copyWith(policy: CachePolicy.noCache).toOptions();
    options.validateStatus = (status) {
      return status! < 500;
    };
    options.followRedirects = false;
    options.headers = {"X-Id-Token": token};
    Map<String, dynamic> params = {"code": "openWater", "token": token};
    // 发送请求并处理响应
    // 1. 若响应数据非空，直接返回空字符串
    // 2. 解析Location响应头中的URL，提取OpenID参数值
    return await _request.get(url, params: params, options: options).then((
      value,
    ) {
      print(value.data);
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
      jSessionId =
          parts![0].split('=').length > 1 ? parts[0].split('=')[1] : "";

      //   print("|JJJJJJJJJJJJJSSSSSSSSSSSSSSS");
      //  print(jSessionId);
      //   print('END');
      String url = value.headers.value("location")!;
      // logger.i(url.split("openid=")[1]);
      //  print(url.split("openid=")[1]);
      return [url.split("openid=")[1], jSessionId];
    });
  }

  /// 获取洗澡设备
  /// return 设备列表
  Future<Map<String, dynamic>> getHotWaterDevice() async {
    bool isV = await checkTokenValidity();
    // print(isV);
    // print(isV);
    String token = await getToken();
    List openidls = await getOpenid();
    String openid = openidls[0];
    String JSESSIONID = openidls[1];
    // print(JSESSIONID);
    String url = "/bathroom/getOftenUsetermList?openid=$openid";
    final dio = Dio();
    dio.interceptors.clear();
    dio.options.baseUrl = 'https://v8mobile.hut.edu.cn';
    dio.options.connectTimeout = Duration(seconds: 5);
    dio.options.receiveTimeout = Duration(seconds: 3);
    dio.options.headers = {
      "User-Agent":
          "Mozilla/5.0 (Linux; Android 15; 24129PN74C Build/AQ3A.240812.002; wv) AppleWebKit/537.36 (KHTML, like Gecko) Version/4.0 Chrome/134.0.6998.39 Mobile Safari/537.36 SuperApp",
      "Connection": "keep-alive",
      "Accept": "application/json, text/javascript, */*; q=0.01",
      "Accept-Encoding": "gzip, deflate, br, zstd",
      "Content-Type": "application/json",
      "sec-ch-ua-platform": "\"Android\"",
      "x-requested-with": "XMLHttpRequest",
      "sec-ch-ua":
          "\"Chromium\";v=\"134\", \"Not:A-Brand\";v=\"24\", \"Android WebView\";v=\"134\"",
      "sec-ch-ua-mobile": "?1",
      "Origin": "https://v8mobile.hut.edu.cn",
      "Sec-Fetch-Site": "same-origin",
      "Sec-Fetch-Mode": "cors",
      "Sec-Fetch-Dest": "empty",
      "Referer":
          "https://v8mobile.hut.edu.cn/waterpage/waterHomePage?openid=$openid",
      "Accept-Language": "zh-CN,zh;q=0.9,en-US;q=0.8,en;q=0.7",
      "Cookie":
          "userToken=$token; Domain=v8mobile.hut.edu.cn; Path=/; JSESSIONID=$JSESSIONID",
    };
    dio.options.followRedirects = true;
    dio.options.validateStatus = (status) {
      return status! < 500;
    };
    Response response;
    response = await dio.post(url, data: {"openid": openid});
    //  print("DDDDDDDDDDDDDDD");
    // print(response.data);
    if (response.data == "") {
      return {"code": 500};
    }

    var data = response.data;
    // logger.i(data);
    return {"code": 200, "data": data["resultData"]["data"].reversed.toList()};
  }

  /// 检测未关闭的设备
  /// return 未关闭的设备
  Future<List> checkHotWaterDevice() async {
    String token = await getToken();
    String url = "https://v8mobile.hut.edu.cn/bathroom/selectCloseDeviceValve";
    Options options =
        _request.cacheOptions.copyWith(policy: CachePolicy.noCache).toOptions();
    List openidls = await getOpenid();
    String openid = openidls[0];
    String JSESSIONID = openidls[1];
    options.headers = {
      "openid": openid,
      "User-Agent":
          "Mozilla/5.0 (Linux; Android 15; 24129PN74C Build/AQ3A.240812.002; wv) AppleWebKit/537.36 (KHTML, like Gecko) Version/4.0 Chrome/134.0.6998.39 Mobile Safari/537.36 SuperApp",
      "Connection": "keep-alive",
      "Accept": "application/json, text/javascript, */*; q=0.01",
      "Accept-Encoding": "gzip, deflate, br, zstd",
      "Content-Type": "application/json",
      "sec-ch-ua-platform": "\"Android\"",
      "x-requested-with": "XMLHttpRequest",
      "sec-ch-ua":
          "\"Chromium\";v=\"134\", \"Not:A-Brand\";v=\"24\", \"Android WebView\";v=\"134\"",
      "sec-ch-ua-mobile": "?1",
      "Origin": "https://v8mobile.hut.edu.cn",
      "Sec-Fetch-Site": "same-origin",
      "Sec-Fetch-Mode": "cors",
      "Sec-Fetch-Dest": "empty",
      "Referer":
          "https://v8mobile.hut.edu.cn/bathroom/selectCloseDeviceValve?openid=$openid",
      "Accept-Language": "zh-CN,zh;q=0.9,en-US;q=0.8,en;q=0.7",
      "Cookie":
          "userToken=$token; Domain=v8mobile.hut.edu.cn; Path=/; JSESSIONID=$JSESSIONID",
    };
    Map<String, dynamic> params = {"openid": openid};
    Map<String, dynamic> data = {"openid": openid};

    return await _request
        .post(url, params: params, data: data, options: options)
        .then((value) {
          // print(value.data);
          if (value.data['result'] != "000000") {
            return [];
          }
          List data = value.data['data'];
          List openCodeList = [];
          for (var i = 0; i < data.length; i++) {
            openCodeList.add(data[i]["poscode"].toString());
          }
          bool isHave = data.isNotEmpty;
          if (isHave) {
            // logger.i(data["data"].first["poscode"]);
            // print(openCodeList);
            return openCodeList;
          } else {
            return [];
          }
        });
  }

  /// 开始洗澡
  /// [device] 设备
  /// return 是否成功
  Future<Map> startHotWater({required String device}) async {
    String token = await getToken();
    String url = "https://v8mobile.hut.edu.cn/boiling/termcodeOpenValve";
    Options options =
        _request.cacheOptions.copyWith(policy: CachePolicy.noCache).toOptions();
    List openidls = await getOpenid();
    String openid = openidls[0];
    String JSESSIONID = openidls[1];
    options.headers = {
      "openid": openid,
      "User-Agent":
          "Mozilla/5.0 (Linux; Android 15; 24129PN74C Build/AQ3A.240812.002; wv) AppleWebKit/537.36 (KHTML, like Gecko) Version/4.0 Chrome/134.0.6998.39 Mobile Safari/537.36 SuperApp",
      "Connection": "keep-alive",
      "Accept": "application/json, text/javascript, */*; q=0.01",
      "Accept-Encoding": "gzip, deflate, br, zstd",
      "Content-Type": "application/json",
      "sec-ch-ua-platform": "\"Android\"",
      "x-requested-with": "XMLHttpRequest",
      "sec-ch-ua":
          "\"Chromium\";v=\"134\", \"Not:A-Brand\";v=\"24\", \"Android WebView\";v=\"134\"",
      "sec-ch-ua-mobile": "?1",
      "Origin": "https://v8mobile.hut.edu.cn",
      "Sec-Fetch-Site": "same-origin",
      "Sec-Fetch-Mode": "cors",
      "Sec-Fetch-Dest": "empty",
      "Referer":
          "https://v8mobile.hut.edu.cn/boiling/termcodeOpenValve?openid=$openid",
      "Accept-Language": "zh-CN,zh;q=0.9,en-US;q=0.8,en;q=0.7",
      "Cookie":
          "userToken=$token; Domain=v8mobile.hut.edu.cn; Path=/; JSESSIONID=$JSESSIONID",
    };
    Map<String, dynamic> params = {"openid": openid};
    Map<String, dynamic> data = {"openid": openid, "poscode": device};
    return await _request
        .post(url, params: params, data: data, options: options)
        .then((value) {
          // logger.i(value);

          var data = ResponseUtils.transformObj(value);
          // logger.i(data["resultData"]["result"] == "000000");
          //print(data);
          //print(data["resultData"]["result"] == "000000");
          Map resultData = {
            "result": data["resultData"]["result"],
            "message": data["resultData"]["message"],
            "success": data["success"]
          };
          return resultData;
        });
  }

  /// 结束洗澡
  /// [device] 设备
  /// return 是否成功
  Future<bool> stopHotWater({required String device}) async {
    String token = await getToken();
    String url = "https://v8mobile.hut.edu.cn/boiling/endUse";
    Options options =
        _request.cacheOptions.copyWith(policy: CachePolicy.noCache).toOptions();
    List openidls = await getOpenid();
    String openid = openidls[0];
    String JSESSIONID = openidls[1];
    options.headers = {
      "openid": openid,
      "User-Agent":
          "Mozilla/5.0 (Linux; Android 15; 24129PN74C Build/AQ3A.240812.002; wv) AppleWebKit/537.36 (KHTML, like Gecko) Version/4.0 Chrome/134.0.6998.39 Mobile Safari/537.36 SuperApp",
      "Connection": "keep-alive",
      "Accept": "application/json, text/javascript, */*; q=0.01",
      "Accept-Encoding": "gzip, deflate, br, zstd",
      "Content-Type": "application/json",
      "sec-ch-ua-platform": "\"Android\"",
      "x-requested-with": "XMLHttpRequest",
      "sec-ch-ua":
          "\"Chromium\";v=\"134\", \"Not:A-Brand\";v=\"24\", \"Android WebView\";v=\"134\"",
      "sec-ch-ua-mobile": "?1",
      "Origin": "https://v8mobile.hut.edu.cn",
      "Sec-Fetch-Site": "same-origin",
      "Sec-Fetch-Mode": "cors",
      "Sec-Fetch-Dest": "empty",
      "Referer": "https://v8mobile.hut.edu.cn/boiling/endUse?openid=$openid",
      "Accept-Language": "zh-CN,zh;q=0.9,en-US;q=0.8,en;q=0.7",
      "Cookie":
          "userToken=$token; Domain=v8mobile.hut.edu.cn; Path=/; JSESSIONID=$JSESSIONID",
    };
    Map<String, dynamic> params = {"openid": openid};
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

  //添加洗澡设备
  Future<Map> addWaterDevice(String bindCode) async {
    // bool isV = await checkTokenValidity();
    //print(isV);
    //print(isV);
    String token = await getToken();
    List openidls = await getOpenid();
    String openid = openidls[0];
    String JSESSIONID = openidls[1];
    //  print(JSESSIONID);
    String url = "/bathroom/bindTerm?openid=$openid";
    final dio = Dio();
    dio.interceptors.clear();
    dio.options.baseUrl = 'https://v8mobile.hut.edu.cn';
    dio.options.connectTimeout = Duration(seconds: 5);
    dio.options.receiveTimeout = Duration(seconds: 3);
    dio.options.headers = {
      "User-Agent":
          "Mozilla/5.0 (Linux; Android 15; 24129PN74C Build/AQ3A.240812.002; wv) AppleWebKit/537.36 (KHTML, like Gecko) Version/4.0 Chrome/134.0.6998.39 Mobile Safari/537.36 SuperApp",
      "Connection": "keep-alive",
      "Accept": "application/json, text/javascript, */*; q=0.01",
      "Accept-Encoding": "gzip, deflate, br, zstd",
      "Content-Type": "application/json",
      "sec-ch-ua-platform": "\"Android\"",
      "x-requested-with": "XMLHttpRequest",
      "sec-ch-ua":
          "\"Chromium\";v=\"134\", \"Not:A-Brand\";v=\"24\", \"Android WebView\";v=\"134\"",
      "sec-ch-ua-mobile": "?1",
      "Origin": "https://v8mobile.hut.edu.cn",
      "Sec-Fetch-Site": "same-origin",
      "Sec-Fetch-Mode": "cors",
      "Sec-Fetch-Dest": "empty",
      "Referer":
          "https://v8mobile.hut.edu.cn/waterpage/waterManagePage?openid=$openid",
      "Accept-Language": "zh-CN,zh;q=0.9,en-US;q=0.8,en;q=0.7",
      "Cookie":
          "userToken=$token; Domain=v8mobile.hut.edu.cn; Path=/; JSESSIONID=$JSESSIONID",
    };
    dio.options.followRedirects = true;
    dio.options.validateStatus = (status) {
      return status! < 500;
    };
    Response response;
    response = await dio.post(
      url,
      data: {"openid": openid, "bindcode": bindCode},
    );
    Map data = response.data;
    Map resultData = data["resultData"];
    if (resultData["result"] == "000000") {
      return {'result': true, 'msg': resultData["message"]};
    } else {
      return {'result': false, 'msg': resultData["message"]};
    }
  }

  //删除洗澡设备
  Future<Map<String, dynamic>> delWaterDevice(String bindCode) async {
    String token = await getToken();
    List openidls = await getOpenid();
    String openid = openidls[0];
    String JSESSIONID = openidls[1];
    //print(JSESSIONID);
    String url = "/bathroom/cancelBindTerm?openid=$openid";
    final dio = Dio();
    dio.interceptors.clear();
    dio.options.baseUrl = 'https://v8mobile.hut.edu.cn';
    dio.options.connectTimeout = Duration(seconds: 5);
    dio.options.receiveTimeout = Duration(seconds: 3);
    dio.options.headers = {
      "User-Agent":
          "Mozilla/5.0 (Linux; Android 15; 24129PN74C Build/AQ3A.240812.002; wv) AppleWebKit/537.36 (KHTML, like Gecko) Version/4.0 Chrome/134.0.6998.39 Mobile Safari/537.36 SuperApp",
      "Connection": "keep-alive",
      "Accept": "application/json, text/javascript, */*; q=0.01",
      "Accept-Encoding": "gzip, deflate, br, zstd",
      "Content-Type": "application/json",
      "sec-ch-ua-platform": "\"Android\"",
      "x-requested-with": "XMLHttpRequest",
      "sec-ch-ua":
          "\"Chromium\";v=\"134\", \"Not:A-Brand\";v=\"24\", \"Android WebView\";v=\"134\"",
      "sec-ch-ua-mobile": "?1",
      "Origin": "https://v8mobile.hut.edu.cn",
      "Sec-Fetch-Site": "same-origin",
      "Sec-Fetch-Mode": "cors",
      "Sec-Fetch-Dest": "empty",
      "Referer":
          "https://v8mobile.hut.edu.cn/waterpage/waterManagePage?openid=$openid",
      "Accept-Language": "zh-CN,zh;q=0.9,en-US;q=0.8,en;q=0.7",
      "Cookie":
          "userToken=$token; Domain=v8mobile.hut.edu.cn; Path=/; JSESSIONID=$JSESSIONID",
    };
    dio.options.followRedirects = true;
    dio.options.validateStatus = (status) {
      return status! < 500;
    };
    Response response;
    response = await dio.post(
      url,
      data: {"openid": openid, "bindcode": bindCode},
    );
    Map data = response.data;
    //print(data);
    Map resultData = data["resultData"] ?? {};
    if (resultData.isEmpty) {
      return {'result': false, 'msg': data['message'] ?? "未知错误"};
    }
    if (resultData["result"] == "000000") {
      return {'result': true, 'msg': resultData["message"]};
    } else {
      return {'result': false, 'msg': resultData["message"]};
    }
  }

  /// 获取校园卡余额
  /// return 余额
  Future<String> getCardBalance() async {
    String token = await getToken();
    String url = "https://v8mobile.hut.edu.cn/homezzdx/openHomePage";
    Options options =
        _request.cacheOptions.copyWith(policy: CachePolicy.noCache).toOptions();
    Map<String, dynamic> params = {"X-Id-Token": token};
    return await _request.get(url, params: params, options: options).then((
      value,
    ) {
      // logger.i(value.data);
      Document doc = parse(value.data);
      var list =
          doc.getElementsByTagName("span").where((element) {
            return element.attributes["name"] == "showbalanceid";
          }).toList();
      if (list.isNotEmpty) {
        return list.first.text.replaceAll("主钱包余额:￥", "");
      } else {
        return "null";
      }
    });
  }

  ///获取功能列明
  Future<List<Map>> getFunctionList() async {
    bool isLogin = await checkTokenValidity();
    if (!isLogin) {
      print("LOG");
      final prefs = await SharedPreferences.getInstance();
      String _userName = prefs.getString('hutUsername') ?? "";
      print(_userName);
      String _orgPassword = prefs.getString('hutPassword') ?? "";
      print(_orgPassword);
      await userLogin(username: _userName, password: _orgPassword);
    }
    String token = await getToken();
    String url = "/portal-api/v1/service/list";
    final dio = Dio();
    dio.interceptors.clear();
    dio.options.baseUrl = 'https://portal.hut.edu.cn';
    dio.options.connectTimeout = Duration(seconds: 5);
    dio.options.receiveTimeout = Duration(seconds: 3);
    dio.options.headers = {
      "User-Agent":
          "Mozilla/5.0 (Linux; Android 15; 24129PN74C Build/AQ3A.240812.002; wv) AppleWebKit/537.36 (KHTML, like Gecko) Version/4.0 Chrome/134.0.6998.39 Mobile Safari/537.36 uni-app Html5Plus/1.0 (Immersed/36.923077)",
      "Connection": "Keep-Alive",
      "Accept": "application/json",
      "Accept-Encoding": "gzip",
      "Content-Type": "application/json",
      "X-Device-Info": "Xiaomi24129PN74C1.9.9.81096",
      "X-Device-Infos":
          "{\"packagename\":__UNI__AA068AD,\"version\":1.1.3,\"system\":Android 15}",
      "X-Id-Token": token,
      "X-Terminal-Info": "app",
    };
    dio.options.followRedirects = true;
    dio.options.validateStatus = (status) {
      return status! < 500;
    };
    Response response;
    response = await dio.post(url, data: {});
    Map data = response.data;
    List functionList = data["data"];
    List<Map> resultList = [];
    for (var element in functionList) {
      String label = element["label"];
      List services = element["services"];
      List<FunctionItem> tempList = [];
      if (services.isNotEmpty) {
        //有服务内容 添加
        for (var service in services) {
          FunctionItem tempItem = FunctionItem(
            id: service['id'],
            serviceName: service['serviceName'],
            servicePicUrl: service['servicePicUrl'],
            serviceUrl: service['serviceUrl'],
            serviceType: service['serviceType'],
            tokenAccept: service['tokenAccept'],
            iconUrl: service['iconUrl'],
          );
          tempList.add(tempItem);
          //把这个分类下所有服务添加到列表中
        }
        resultList.add({"label": label, "services": tempList});
      }
    }
    return resultList;
  }

  //刷新Token
  Future<bool> refreshToken() async {
    print("startRe");
    //bool isLogin = await checkTokenValidity();
    print("LOG");
    final prefs = await SharedPreferences.getInstance();
    String _userName = prefs.getString('hutUsername') ?? "";
    print(_userName);
    String _orgPassword = prefs.getString('hutPassword') ?? "";
    print(_orgPassword);
    await userLogin(username: _userName, password: _orgPassword);
    return true;
  }
}
