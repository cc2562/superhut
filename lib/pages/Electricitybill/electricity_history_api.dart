import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:superhut/pages/Electricitybill/electricity_history_models.dart';
import 'package:superhut/utils/hut_user_api.dart';

/// 智慧工大登录态失效（token 拿不到，或接口回了网页登录页）。
class ElectricityHistoryAuthException implements Exception {
  const ElectricityHistoryAuthException([
    this.message = '登录状态已失效，请重新登录智慧工大',
  ]);

  final String message;

  @override
  String toString() => message;
}

/// 网络/服务端异常，页面只提示可重试。
class ElectricityHistoryException implements Exception {
  const ElectricityHistoryException(this.message);

  final String message;

  @override
  String toString() => message;
}

/// 账户搜索结果（带总数，供弹层做分页）。
class ElectricityAccountPage {
  const ElectricityAccountPage({required this.total, required this.accounts});

  final int total;
  final List<ElectricityAccount> accounts;

  bool get hasMore => accounts.length < total;
}

/// 智慧工大「电费查询」子系统客户端。
///
/// 这一套接口不是 v8mobile 那套充值接口，而是网页版 `hq-nygk.hut.edu.cn`：
/// 智慧工大打开该网页时会把登录 token 以 query 参数（`keyjm`）注入，所以这里
/// 复用同一个 token，并用 portal 服务列表里的 `tokenAccept` 校正参数名。
class ElectricityHistoryApi {
  ElectricityHistoryApi({HutUserApi? hutApi, Dio? dio})
    : _hutApi = hutApi ?? HutUserApi(),
      _dio = dio ?? _buildDio();

  static const String serviceHost = 'hq-nygk.hut.edu.cn';
  static const String _baseUrl = 'https://$serviceHost';
  static const String _acDetailPath = '/Home/AcDetail';
  static const String _accountPath = '/Home/GetAccountInfo';
  static const String _usagePath = '/Home/GetAcData';

  /// 明细一次最多取 3 页（每页 60 条），30 天区间实际只需 1 页。
  static const int _usagePageSize = 60;
  static const int _usageMaxPages = 3;

  final HutUserApi _hutApi;
  final Dio _dio;

  String? _token;
  String _tokenKey = 'keyjm';
  _TokenCarrier _carrier = _TokenCarrier.url;

  /// 子系统（CAS/Forms 认证）在重定向链上种下的所有 cookie。
  final Map<String, String> _cookies = {};

  bool _sessionPrimed = false;
  Future<void>? _priming;

  /// 入口页打开后是不是登录页（说明 keyjm 没被子系统认可）。
  bool _primeLooksLikeLogin = false;

  /// 已确认可用的请求形态，后续请求直接复用。
  _RequestShape? _workingShape;

  /// 门户下发的子系统入口地址（可能自带 keyjm 票据）。
  String? _serviceUrl;

  /// 预热落地的地址，用作后续接口的 Referer。
  String? _refererUrl;

  static Dio _buildDio() {
    return Dio(
      BaseOptions(
        baseUrl: _baseUrl,
        connectTimeout: const Duration(seconds: 8),
        sendTimeout: const Duration(seconds: 8),
        // 首次打开子系统页面要等服务端建会话，接收超时留宽一点。
        receiveTimeout: const Duration(seconds: 15),
      ),
    );
  }

  /// 搜索宿舍账户。
  Future<ElectricityAccountPage> searchAccounts(
    String keyword, {
    int page = 1,
    int rows = 20,
  }) async {
    final data = await _postJson(_accountPath, {
      'q': keyword,
      'page': '$page',
      'rows': '$rows',
    });
    final accounts = _rows(data)
        .map(ElectricityAccount.fromApiRow)
        .where((account) => account.isValid)
        .toList();
    return ElectricityAccountPage(
      total: int.tryParse('${data['total']}') ?? accounts.length,
      accounts: accounts,
    );
  }

  /// 拉取某个账户在区间内的逐日明细（升序）。
  Future<List<UsageRecord>> fetchUsage({
    required String acguid,
    required UsageRange range,
  }) async {
    final collected = <UsageRecord>[];
    var total = 0;
    for (var page = 1; page <= _usageMaxPages; page++) {
      final data = await _postJson(_usagePath, {
        'dateStatr': range.startParam,
        'dateEnd': range.endParam,
        'acid': acguid,
        'time_t': 'AD',
        'page': '$page',
        'rows': '$_usagePageSize',
        'sort': 'stattime',
        'order': 'desc',
      });
      total = int.tryParse('${data['total']}') ?? total;
      final pageRecords = _rows(data).map(UsageRecord.fromApiRow).toList();
      if (pageRecords.isEmpty) break;
      collected.addAll(pageRecords);
      if (collected.length >= total) break;
    }
    return mergeUsageRecords(collected);
  }

  // ---------------------------------------------------------------------------
  // 鉴权
  // ---------------------------------------------------------------------------

  /// 取登录 token，并尽量从智慧工大服务列表里确认 token 的注入方式。
  Future<String> _ensureToken() async {
    final cached = _token;
    if (cached != null && cached.isNotEmpty) return cached;

    var token = await _hutApi.getToken();
    if (token.isEmpty) {
      throw const ElectricityHistoryAuthException();
    }
    _token = token;

    try {
      final service = _findService(await _hutApi.getFunctionList());
      if (service != null) {
        if (service.tokenAccept.isNotEmpty) {
          _applyTokenAccept(service.tokenAccept);
        }
        _serviceUrl = service.serviceUrl.trim();
        // 门户下发的入口地址里通常已经带好了子系统自己的票据（48 位十六进制），
        // 它才是 `keyjm`；App 的 hutToken 是 authx 的 JWT，子系统不认。
        final embedded = _extractTicket(_serviceUrl!);
        if (embedded != null && embedded.isNotEmpty) {
          token = embedded;
          _token = embedded;
        }
      }
    } on HutAuthenticationRequiredException {
      _token = null;
      throw const ElectricityHistoryAuthException();
    } catch (_) {
      // 服务列表拿不到不影响查询：`keyjm` 是抓包里确认过的默认参数名。
    }
    return token;
  }

  FunctionItem? _findService(List<Map> serviceList) {
    FunctionItem? fallback;
    for (final category in serviceList) {
      final services = category['services'];
      if (services is! List) continue;
      for (final service in services) {
        if (service is! FunctionItem) continue;
        final url = service.serviceUrl;
        final matched = url.contains(serviceHost) ||
            (service.serviceName.contains('电费') && url.contains('hq-nygk'));
        if (!matched) continue;
        // 优先取落到明细页（AcDetail）的入口，它带的就是查询用票据。
        if (url.toLowerCase().contains('acdetail')) return service;
        fallback ??= service;
      }
    }
    return fallback;
  }

  /// 与 type2webview 的 `doWithAccept()` 同规则。
  void _applyTokenAccept(String raw) {
    try {
      final decoded = jsonDecode(raw);
      if (decoded is! List) return;
      for (final item in decoded) {
        if (item is! Map) continue;
        final type = (item['tokenType'] ?? '').toString();
        final key = (item['tokenKey'] ?? '').toString().trim();
        if (key.isEmpty) continue;
        switch (type) {
          case 'url':
            _carrier = _TokenCarrier.url;
            _tokenKey = key;
            return;
          case 'header':
            _carrier = _TokenCarrier.header;
            _tokenKey = key;
            return;
          case 'cookie':
            _carrier = _TokenCarrier.cookie;
            _tokenKey = key;
            return;
        }
      }
    } catch (_) {
      // tokenAccept 格式不认识时保持默认 keyjm。
    }
  }

  /// 先走一遍子系统的登录/建会话链路（拿不到就直接用 token 请求）。
  ///
  /// 网页版电费页不是「带 keyjm 直接就能查」：打开 AcDetail 时服务端会 302 到
  /// SSO、种下 Forms 认证 cookie，最后才回到 AcDetail。只发一次不跟随重定向的
  /// GET 拿不到这些 cookie，后续接口就会因为会话里没有用户而 500。
  Future<void> _ensureSession() {
    if (_sessionPrimed) return Future<void>.value();
    return _priming ??= _primeSession().whenComplete(() {
      _sessionPrimed = true;
      _priming = null;
    });
  }

  Future<void> _primeSession() async {
    try {
      final token = _token;
      if (token == null || token.isEmpty) return;

      var uri = _entryUri();

      var pageBody = '';
      for (var hop = 0; hop < 5; hop++) {
        final response = await _dio.getUri<dynamic>(
          uri,
          options: Options(
            followRedirects: false,
            responseType: ResponseType.plain,
            // 3xx/4xx/5xx 都要自己判断，不能抛异常打断整条链路。
            validateStatus: (_) => true,
            headers: _headers(navigation: true),
          ),
        );
        _collectCookies(response.headers);
        pageBody = response.data?.toString() ?? '';

        final status = response.statusCode ?? 0;
        final location = response.headers.value('location');
        if (status < 300 || status >= 400) break;
        if (location == null || location.isEmpty) break;

        final next = uri.resolve(location);
        // 少数子系统会先用入口 token 换一张一次性票据，再 302 回 AcDetail。
        // 后续接口必须用重定向地址里的票据，否则会被判为未登录。
        final ticket = _extractTicket(next.toString());
        if (ticket != null && ticket.isNotEmpty) {
          _token = ticket;
        }
        uri = next;
      }
      _refererUrl = uri.toString();

      _primeLooksLikeLogin = _looksLikeLoginPage(pageBody);
    } catch (_) {
      // 会话只是锦上添花，失败后继续用 token 请求。
    }
  }

  String? _extractTicket(String location) {
    try {
      final uri = Uri.parse(location);
      return uri.queryParameters[_tokenKey] ?? uri.queryParameters['keyjm'];
    } catch (_) {
      return null;
    }
  }

  void _collectCookies(Headers headers) {
    final raw = headers.map['set-cookie'];
    if (raw == null) return;
    for (final cookie in raw) {
      final first = cookie.split(';').first.trim();
      final separator = first.indexOf('=');
      if (separator <= 0) continue;
      final name = first.substring(0, separator).trim();
      final value = first.substring(separator + 1).trim();
      if (name.isEmpty) continue;
      if (value.isEmpty) {
        // 服务端用空值注销 cookie。
        _cookies.remove(name);
      } else {
        _cookies[name] = value;
      }
    }
  }

  Map<String, dynamic> _withToken(Map<String, dynamic> query) {
    final result = Map<String, dynamic>.from(query);
    if (_carrier == _TokenCarrier.url) {
      result[_tokenKey] = _token;
    }
    return result;
  }

  Map<String, String> _headers({bool navigation = false}) {
    final headers = <String, String>{
      'User-Agent':
          'Mozilla/5.0 (Linux; Android 15; 24129PN74C Build/AQ3A.240812.002; wv) '
          'AppleWebKit/537.36 (KHTML, like Gecko) Version/4.0 '
          'Chrome/134.0.6998.39 Mobile Safari/537.36 SuperApp',
      'Accept-Language': 'zh-CN,zh-Hans;q=0.9',
      'Origin': _baseUrl,
    };

    if (navigation) {
      // 与浏览器打开 AcDetail 时一致。
      headers.addAll({
        'Accept':
            'text/html,application/xhtml+xml,application/xml;q=0.9,'
            'image/avif,image/webp,*/*;q=0.8',
        'Sec-Fetch-Site': 'none',
        'Sec-Fetch-Mode': 'navigate',
        'Sec-Fetch-User': '?1',
        'Sec-Fetch-Dest': 'document',
        'Upgrade-Insecure-Requests': '1',
      });
    } else {
      // 抓包里 XHR 请求带的全部头，缺一个都不一定被 WAF 放过。
      headers.addAll({
        'Accept': 'application/json, text/javascript, */*; q=0.01',
        'X-Requested-With': 'XMLHttpRequest',
        'Sec-Fetch-Site': 'same-origin',
        'Sec-Fetch-Mode': 'cors',
        'Sec-Fetch-Dest': 'empty',
        'Priority': 'u=3, i',
      });
    }

    final token = _token;
    if (token != null && _carrier == _TokenCarrier.header) {
      headers[_tokenKey] = token;
    }

    final cookies = <String>[
      if (token != null && _carrier == _TokenCarrier.cookie)
        '$_tokenKey=$token',
      for (final entry in _cookies.entries) '${entry.key}=${entry.value}',
    ];
    if (cookies.isNotEmpty) headers['Cookie'] = cookies.join('; ');

    // Referer 必须是真实落地页（带票据），和浏览器里发出去的一致。
    headers['Referer'] =
        _refererUrl ??
        (token == null
            ? '$_baseUrl/'
            : '$_baseUrl$_acDetailPath?keyjm=$token');
    return headers;
  }

  /// 预热起点：优先用门户下发的入口地址，没有就退回 AcDetail。
  Uri _entryUri() {
    final serviceUrl = _serviceUrl;
    final parsed = serviceUrl == null ? null : Uri.tryParse(serviceUrl);
    final uri =
        (parsed != null && parsed.host.isNotEmpty)
            ? parsed
            : Uri.parse('$_baseUrl$_acDetailPath');

    final token = _token;
    if (_carrier == _TokenCarrier.url && token != null && token.isNotEmpty) {
      return uri.replace(
        queryParameters: {...uri.queryParameters, _tokenKey: token},
      );
    }
    return uri;
  }

  // ---------------------------------------------------------------------------
  // 请求
  // ---------------------------------------------------------------------------

  Future<Map<String, dynamic>> _postJson(
    String path,
    Map<String, dynamic> query,
  ) async {
    await _ensureToken();
    await _ensureSession();

    // 入口页直接就是登录页，说明 keyjm 没被认可，再发 4 次也是白费。
    if (_primeLooksLikeLogin) {
      throw const ElectricityHistoryAuthException();
    }

    final queryParameters = _withToken(query);
    Response<dynamic>? last;
    DioException? failure;

    // 抓包文档里参数标在 query，但请求体是 `{}`；网页实际也可能用表单
    // post。这里按成功过的形态优先，失败就换一种形态再试。
    final shapes =
        _workingShape != null ? [_workingShape!] : _RequestShape.values;
    for (final shape in shapes) {
      try {
        final response = await _send(path, queryParameters, shape);
        if (!_isFailure(response.statusCode)) {
          _workingShape = shape;
          return _decodeBody(response);
        }
        last = response;
      } on DioException catch (error) {
        // 单一形态失败不影响继续尝试其它形态。
        failure = error;
      }
    }

    if (last == null) {
      throw ElectricityHistoryException(
        _describeDioError(failure) ?? '电费服务暂时不可用，请稍后重试',
      );
    }

    final body = last.data?.toString() ?? '';
    if (_primeLooksLikeLogin || _looksLikeLoginPage(body)) {
      throw const ElectricityHistoryAuthException();
    }
    throw ElectricityHistoryException(
      '电费服务返回异常（${last.statusCode}），请稍后重试',
    );
  }

  /// 四种候选形态：参数放 query / 放 body，编码用表单 / JSON。
  Future<Response<dynamic>> _send(
    String path,
    Map<String, dynamic> queryWithToken,
    _RequestShape shape,
  ) {
    final inBody = shape == _RequestShape.bodyForm ||
        shape == _RequestShape.bodyJson;
    final json = shape == _RequestShape.queryJson ||
        shape == _RequestShape.bodyJson;

    return _dio.post<dynamic>(
      path,
      queryParameters: inBody ? _tokenOnlyQuery() : queryWithToken,
      data: inBody ? Map<String, dynamic>.from(queryWithToken) : <String, dynamic>{},
      options: Options(
        contentType:
            json ? Headers.jsonContentType : Headers.formUrlEncodedContentType,
        headers: _headers(),
        // 全部状态码自己处理：500 之前被 dio 抛成异常，重试永远走不到。
        validateStatus: (_) => true,
      ),
    );
  }

  /// body 形态下，token 仍然留在 query（抓包 URL 里 keyjm 一直在）。
  Map<String, dynamic> _tokenOnlyQuery() {
    final query = <String, dynamic>{};
    if (_carrier == _TokenCarrier.url) query[_tokenKey] = _token;
    return query;
  }

  bool _isFailure(int? status) => status == null || status >= 400;

  bool _looksLikeLoginPage(String body) {
    if (body.isEmpty) return false;
    final lower = body.toLowerCase();
    if (lower.contains('type="password"') || lower.contains("type='password'")) {
      return true;
    }
    if (lower.contains('/cas/login') || lower.contains('login?service=')) {
      return true;
    }
    return body.contains('请登录') ||
        body.contains('登录已过期') ||
        body.contains('未登录或登录已失效');
  }

  String? _describeDioError(DioException? error) {
    if (error == null) return null;
    final status = error.response?.statusCode;
    if (status != null) return '电费服务返回异常（$status），请稍后重试';
    return switch (error.type) {
      DioExceptionType.connectionTimeout ||
      DioExceptionType.sendTimeout ||
      DioExceptionType.receiveTimeout => '连接电费服务超时，请稍后重试',
      DioExceptionType.connectionError => '网络连接失败，请检查网络后重试',
      _ => '电费服务暂时不可用，请稍后重试',
    };
  }

  Map<String, dynamic> _decodeBody(Response<dynamic> response) {
    dynamic data = response.data;
    if (data is String) {
      final text = data.trim();
      if (text.isEmpty) {
        throw const ElectricityHistoryAuthException();
      }
      try {
        data = jsonDecode(text);
      } catch (_) {
        if (_looksLikeServerError(text)) {
          throw const ElectricityHistoryException(
            '电费服务处理请求时出错，请稍后重试',
          );
        }
        // 返回的是登录页 HTML，说明 token 不被子系统认可。
        throw const ElectricityHistoryAuthException();
      }
    }
    if (data is! Map) {
      throw const ElectricityHistoryAuthException();
    }
    final map = Map<String, dynamic>.from(data);
    if (map['rows'] is! List) {
      final message = (map['message'] ?? map['msg'] ?? '').toString().trim();
      if (message.isNotEmpty) {
        throw ElectricityHistoryException(message);
      }
      throw const ElectricityHistoryAuthException();
    }
    return map;
  }

  bool _looksLikeServerError(String text) {
    final lower = text.toLowerCase();
    return lower.contains('server error') ||
        lower.contains('runtime error') ||
        lower.contains('exception') ||
        text.contains('服务器错误') ||
        text.contains('运行时错误');
  }

  List<Map<String, dynamic>> _rows(Map<String, dynamic> data) {
    final rows = data['rows'];
    if (rows is! List) return const [];
    return rows
        .whereType<Map>()
        .map((row) => Map<String, dynamic>.from(row))
        .toList();
  }
}

enum _TokenCarrier { url, header, cookie }

/// 参数载体与编码方式的候选组合。
enum _RequestShape { queryForm, queryJson, bodyForm, bodyJson }
