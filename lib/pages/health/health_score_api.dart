import 'dart:async';
import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:superhut/pages/health/health_score_models.dart';
import 'package:superhut/pages/health/health_score_parser.dart';
import 'package:superhut/security/credential_store.dart';
import 'package:superhut/utils/hut_user_api.dart';

/// 体测子系统站点（`/spQuery` 所在 host）。
const String kHealthBaseUrl = 'https://tzcs.hut.edu.cn';

/// 统一认证站点。
const String kHealthCasBaseUrl = 'https://mycas.hut.edu.cn';

/// CAS 票据校验成功后要落到 sso 的 index 页，由它建立体测子系统的会话，
/// 再由它跳到 `/weixin/main.jsp`；直接把 targetUrl 写成 main.jsp 会跳过
/// 这一步，导致后续 `/spQuery` 又被 302 回登录流程。
const String kHealthSsoIndexPath = '/sso/index.jsp';

const String kHealthMainPath = '/weixin/main.jsp';
const String kHealthSsoPath = '/sso/login.jsp';
const String kHealthQueryPath = '/spQuery';

/// 登录态不可用（没有智慧工大 token、CAS 未放行、页面回到登录页）。
class HealthScoreAuthException implements Exception {
  const HealthScoreAuthException([this.message = '体测系统登录状态已失效，请重新登录']);

  final String message;

  @override
  String toString() => message;
}

/// 网络、服务端或页面解析失败，页面只需提示可重试。
class HealthScoreException implements Exception {
  const HealthScoreException(this.message);

  final String message;

  @override
  String toString() => message;
}

/// 体测子系统 CAS 回调地址（service 参数）。
///
/// 文档里的链路是 `/cas/login?service=...` → `/sso/login.jsp?targetUrl=...&ticket=...`，
/// 因此 service 指向 sso 入口，targetUrl 指向登录后的 main.jsp。
String buildHealthServiceUrl({String baseUrl = kHealthBaseUrl}) {
  final Uri target = Uri.parse('$baseUrl$kHealthSsoIndexPath');
  return Uri.parse('$baseUrl$kHealthSsoPath')
      .replace(
        queryParameters: <String, String>{'targetUrl': target.toString()},
      )
      .toString();
}

/// 组出带智慧工大 idToken 的 CAS 静默登录地址（参数形态与教务登录一致）。
String buildHealthCasLoginUrl({
  required String idToken,
  String? serviceUrl,
  String baseUrl = kHealthBaseUrl,
}) {
  final String service = serviceUrl ?? buildHealthServiceUrl(baseUrl: baseUrl);
  return Uri.parse('$kHealthCasBaseUrl/cas/login')
      .replace(
        queryParameters: <String, String>{
          'idToken': idToken,
          'service': service,
          'token': idToken,
        },
      )
      .toString();
}

/// 拼接 Cookie 头；按名称排序保证结果稳定、便于排查。
String buildHealthCookieHeader(Map<String, String> cookies) {
  if (cookies.isEmpty) return '';
  final List<String> names = cookies.keys.toList()..sort();
  return names.map((name) => '$name=${cookies[name]}').join('; ');
}

/// 学号转 base64（接口隐藏域与 POST body 都使用这种形式）。
String encodeHealthStudentNo(String studentNo) {
  final String text = studentNo.trim();
  if (text.isEmpty) return '';
  return base64Encode(utf8.encode(text));
}

/// 页面是不是登录页 / 会话失效页。
bool looksLikeHealthLoginPage(String html) {
  if (html.trim().isEmpty) return false;
  final String lower = html.toLowerCase();
  if (lower.contains('type="password"') || lower.contains("type='password'")) {
    return true;
  }
  if (lower.contains('/cas/login') ||
      lower.contains('/sso/login.jsp') ||
      lower.contains('login?service=')) {
    return true;
  }
  return html.contains('请登录') ||
      html.contains('登录已过期') ||
      html.contains('未登录或登录已失效') ||
      html.contains('用户未登录');
}

/// 未登录访问 `/spQuery` 时平台会返回「暂未开放查询」，而不是跳登录页。
///
/// 这既可能是会话没建立，也可能是查询窗口未开放；页面按「登录失效」处理，
/// 给用户重新登录与重试两条路，不把它当成正常成绩页。
bool looksLikeHealthUnavailablePage(String html) {
  if (html.trim().isEmpty) return false;
  return html.contains('暂未开放查询') ||
      html.contains('查询暂未开放') ||
      html.contains('功能暂未开放');
}

/// 体测子系统客户端。
///
/// 与教务链路完全独立：独立 Dio、独立 Cookie 分桶，不复用
/// `utils/withhttp.dart` 的全局实例，避免影响成绩 / 课表 / 空教室。
class HealthScoreApi {
  HealthScoreApi({HutUserApi? hutApi, Dio? dio})
    : _hutApi = hutApi ?? HutUserApi(),
      _dio = dio ?? _buildDio();

  static const String _userAgent =
      'Mozilla/5.0 (Linux; Android 15; 24129PN74C Build/AQ3A.240812.002; wv) '
      'AppleWebKit/537.36 (KHTML, like Gecko) Version/4.0 '
      'Chrome/134.0.6998.39 Mobile Safari/537.36 SuperApp';

  /// 最多跟随的跳数（mycas → sso → main 通常 2–3 跳）。
  static const int _maxHops = 6;

  final HutUserApi _hutApi;
  final Dio _dio;

  /// host -> cookie 名值。mycas 与 tzcs 的会话互不干扰。
  final Map<String, Map<String, String>> _cookieJar =
      <String, Map<String, String>>{};

  String? _landingUrl;
  String? _studentNo;
  String? _stuNoBase64;
  String _schoolId = kHealthDefaultSchoolId;

  /// 智慧工大 idToken；tzcs 的部分接口用它做用户识别（X-Id-Token）。
  String? _hutToken;
  bool _sessionPrimed = false;
  Future<void>? _priming;

  static Dio _buildDio() {
    return Dio(
      BaseOptions(
        baseUrl: kHealthBaseUrl,
        connectTimeout: const Duration(seconds: 8),
        sendTimeout: const Duration(seconds: 8),
        receiveTimeout: const Duration(seconds: 15),
      ),
    );
  }

  /// 丢弃当前会话，下次请求重新走一遍 CAS 链。
  void resetSession() {
    _cookieJar.clear();
    _landingUrl = null;
    _studentNo = null;
    _stuNoBase64 = null;
    _schoolId = kHealthDefaultSchoolId;
    _hutToken = null;
    _sessionPrimed = false;
    _priming = null;
  }

  /// 查询历年体测记录（总览与趋势共用这一份数据）。
  Future<HealthScoreSnapshot> fetchSnapshot() async {
    await _ensureSession();
    final _ListPage page = await _fetchListPage();
    final String plainNo = parseHealthStudentNo(page.body);
    final String studentNo =
        plainNo.isNotEmpty ? plainNo : (_studentNo ?? _decodeStudentNo() ?? '');
    return HealthScoreSnapshot(
      studentNo: studentNo,
      schoolId: _schoolId,
      records: page.records,
    );
  }

  /// 查询某一学年学期的项目详情。
  Future<HealthDetailTable> fetchDetail(HealthTermRecord record) async {
    if (!record.hasDetail) {
      throw const HealthScoreException('该学年缺少详情参数，无法查看');
    }
    await _ensureSession();

    final Map<String, String> query = <String, String>{
      'method': 'scoreDetails',
      'schoolid': _schoolId,
      if (_stuNoBase64 != null && _stuNoBase64!.isNotEmpty)
        'stuNo': _stuNoBase64!,
      'year': record.year,
      if (record.term.isNotEmpty) 'term': record.term,
    };
    final Uri uri = Uri.parse(
      '$kHealthBaseUrl$kHealthQueryPath',
    ).replace(queryParameters: query);

    final Response<String> response;
    try {
      response = await _dio.getUri<String>(
        uri,
        options: Options(
          headers: _headersFor(uri),
          followRedirects: false,
          responseType: ResponseType.plain,
          validateStatus: (_) => true,
        ),
      );
    } on DioException catch (error) {
      throw HealthScoreException(_describeDioError(error));
    }

    _collectCookies(uri.host, response.headers);
    final int status = response.statusCode ?? 0;
    final String body = response.data ?? '';
    if (status >= 300 && status < 400) {
      // 会话失效时详情页会 302 回 CAS / sso，不再跟随以免把登录页当成绩页。
      throw const HealthScoreAuthException();
    }
    if (status >= 400) {
      throw HealthScoreException('体测服务返回异常（$status），请稍后重试');
    }
    if (looksLikeHealthLoginPage(body)) {
      throw const HealthScoreAuthException();
    }
    if (looksLikeHealthUnavailablePage(body)) {
      throw const HealthScoreAuthException('体测详情暂未开放，或登录状态已失效，请稍后重试');
    }
    try {
      return parseDetailTable(body);
    } on HealthParseException catch (error) {
      throw HealthScoreException('体测详情页面无法识别（${error.message}），请稍后重试');
    }
  }

  // ---------------------------------------------------------------------------
  // 会话
  // ---------------------------------------------------------------------------

  Future<void> _ensureSession() {
    if (_sessionPrimed) return Future<void>.value();
    return _priming ??= _primeSession().whenComplete(() {
      _priming = null;
    });
  }

  Future<void> _primeSession() async {
    _cookieJar.clear();
    _landingUrl = null;
    _stuNoBase64 = null;
    _studentNo = null;
    _schoolId = kHealthDefaultSchoolId;

    // 与「智慧工大」功能一致：取持久化的 hutToken；为空才刷新一次。
    String token = await _hutApi.getToken();
    if (token.isEmpty) {
      try {
        if (await _hutApi.refreshToken()) token = await _hutApi.getToken();
      } catch (_) {
        // 交给下面的空 token 判断。
      }
    }
    if (token.isEmpty) {
      throw const HealthScoreAuthException('尚未登录智慧工大，请先登录后再查询体测');
    }

    // 服务列表内部会校验并在必要时刷新 token，拿它做一次统一的续期。
    try {
      await _hutApi.getFunctionList();
    } on HutAuthenticationRequiredException {
      // 继续走 CAS，由落点判定是否真的失效。
    } catch (_) {
      // 门户接口失败不影响 CAS 登录。
    }
    final String latestToken = await _hutApi.getToken();
    if (latestToken.isNotEmpty) token = latestToken;

    _hutToken = token;
    // tzcs 网关和 v8mobile 一样认 userToken Cookie + X-Id-Token 头。
    _cookieJar['tzcs.hut.edu.cn'] = <String, String>{'userToken': token};

    // CAS 用 idToken 换 ST 票据，随后 sso/login.jsp 会下发 JSESSIONID。
    final Uri casEntry = Uri.parse(buildHealthCasLoginUrl(idToken: token));
    final _FetchedPage page = await _followNavigation(casEntry);

    // sso/index.jsp 是空 body，但会话已经在 Cookie 里；再打开 main.jsp
    // 读取查询表单的 stuNo / schoolid。
    HealthMainForm? form = parseMainForm(page.body);
    _FetchedPage mainPage = page;
    if (form == null && page.uri.host == 'tzcs.hut.edu.cn') {
      mainPage = await _fetchMainPage();
      form = parseMainForm(mainPage.body);
    }

    if (form == null) {
      if (page.uri.host != 'tzcs.hut.edu.cn' ||
          looksLikeHealthLoginPage(mainPage.body)) {
        throw const HealthScoreAuthException();
      }
      // 页面没有隐藏域时用本地学号兜底；拿不到就明确报错。
      final String localNo = await CredentialStore.instance.readOrEmpty('user');
      final String encoded = encodeHealthStudentNo(localNo);
      if (encoded.isEmpty) {
        throw const HealthScoreException('登录后返回的页面无法识别，请稍后重试');
      }
      _stuNoBase64 = encoded;
      _schoolId = kHealthDefaultSchoolId;
      _studentNo = localNo.trim();
      _sessionPrimed = true;
      return;
    }

    _stuNoBase64 = form.stuNo;
    _schoolId = form.schoolId;
    _studentNo = parseHealthStudentNo(mainPage.body);
    _sessionPrimed = true;
  }

  /// 手动跟随重定向链，收集每一跳的 Set-Cookie。
  Future<_FetchedPage> _followNavigation(Uri entry) async {
    Uri uri = entry;
    String body = '';
    for (int hop = 0; hop < _maxHops; hop++) {
      final Response<String> response;
      try {
        response = await _dio.getUri<String>(
          uri,
          options: Options(
            headers: _headersFor(uri, navigation: true),
            followRedirects: false,
            responseType: ResponseType.plain,
            validateStatus: (_) => true,
          ),
        );
      } on DioException catch (error) {
        throw HealthScoreException(_describeDioError(error));
      }

      _collectCookies(uri.host, response.headers);
      body = response.data ?? '';

      final int status = response.statusCode ?? 0;
      final String? location = response.headers.value('location');
      if (status >= 300 &&
          status < 400 &&
          location != null &&
          location.isNotEmpty) {
        uri = uri.resolve(location);
        continue;
      }
      break;
    }
    if (uri.host == 'tzcs.hut.edu.cn') {
      _landingUrl = uri.toString();
    }
    return _FetchedPage(uri: uri, body: body);
  }

  /// 直接打开学生服务平台首页，读取查询表单的隐藏域。
  Future<_FetchedPage> _fetchMainPage() async {
    final Uri uri = Uri.parse('$kHealthBaseUrl$kHealthMainPath');
    final Response<String> response;
    try {
      response = await _dio.getUri<String>(
        uri,
        options: Options(
          headers: _headersFor(uri, navigation: true),
          followRedirects: false,
          responseType: ResponseType.plain,
          validateStatus: (_) => true,
        ),
      );
    } on DioException catch (error) {
      throw HealthScoreException(_describeDioError(error));
    }
    _collectCookies(uri.host, response.headers);
    _landingUrl = uri.toString();
    return _FetchedPage(uri: uri, body: response.data ?? '');
  }

  void _collectCookies(String host, Headers headers) {
    final List<String>? raw = headers.map['set-cookie'];
    if (raw == null || raw.isEmpty) return;
    final Map<String, String> jar = _cookieJar.putIfAbsent(
      host,
      () => <String, String>{},
    );
    for (final String cookie in raw) {
      final String first = cookie.split(';').first.trim();
      final int separator = first.indexOf('=');
      if (separator <= 0) continue;
      final String name = first.substring(0, separator).trim();
      final String value = first.substring(separator + 1).trim();
      if (name.isEmpty) continue;
      if (value.isEmpty) {
        jar.remove(name);
      } else {
        jar[name] = value;
      }
    }
  }

  // ---------------------------------------------------------------------------
  // 请求
  // ---------------------------------------------------------------------------

  Future<_ListPage> _fetchListPage({bool retried = false}) async {
    // healthscore 是「当前学年明细」，历年列表在页面底部的
    // `/spQuery?method=scoreTotal` 表单里。
    final Uri uri = Uri.parse(
      '$kHealthBaseUrl$kHealthQueryPath',
    ).replace(queryParameters: const <String, String>{'method': 'scoreTotal'});
    // 与 main.jsp 表单提交一致：stuNo / schoolid 走表单编码。
    final Map<String, String> data = <String, String>{
      'stuNo': _stuNoBase64 ?? '',
      'schoolid': _schoolId,
    };

    Response<String> response;
    try {
      response = await _dio.postUri<String>(
        uri,
        data: data,
        options: Options(
          contentType: Headers.formUrlEncodedContentType,
          headers: _headersFor(uri),
          followRedirects: false,
          responseType: ResponseType.plain,
          validateStatus: (_) => true,
        ),
      );
    } on DioException catch (error) {
      throw HealthScoreException(_describeDioError(error));
    }

    _collectCookies(uri.host, response.headers);
    final int status = response.statusCode ?? 0;
    final String body = response.data ?? '';

    if (status >= 300 && status < 400) {
      final String? location = response.headers.value('location');
      if (!retried && location != null && location.isNotEmpty) {
        final Uri next = uri.resolve(location);
        if (next.host == 'tzcs.hut.edu.cn' && !next.path.contains('/spQuery')) {
          try {
            await _followNavigation(next);
          } on HealthScoreException {
            // 补会话失败不影响后面的重试判定。
          }
          return _fetchListPage(retried: true);
        }
      }
      throw const HealthScoreAuthException();
    }
    if (status >= 400) {
      throw HealthScoreException('体测服务返回异常（$status），请稍后重试');
    }
    if (looksLikeHealthLoginPage(body)) {
      throw const HealthScoreAuthException();
    }
    if (looksLikeHealthUnavailablePage(body)) {
      throw const HealthScoreAuthException('体测查询暂未开放，或登录状态已失效，请稍后重试');
    }

    try {
      final List<HealthTermRecord> records = parseTermRecords(body);
      return _ListPage(body: body, records: records);
    } on HealthParseException catch (error) {
      throw HealthScoreException('体测成绩页面无法识别（${error.message}），请稍后重试');
    }
  }

  Map<String, String> _headersFor(Uri uri, {bool navigation = false}) {
    final Map<String, String> headers = <String, String>{
      'User-Agent': _userAgent,
      'Accept-Language': 'zh-CN,zh-Hans;q=0.9',
      'Accept':
          'text/html,application/xhtml+xml,application/xml;q=0.9,'
          'image/avif,image/webp,*/*;q=0.8',
      'Referer': _landingUrl ?? '$kHealthBaseUrl$kHealthMainPath',
    };
    if (uri.host == 'tzcs.hut.edu.cn') {
      headers['Origin'] = kHealthBaseUrl;
      final String token = _hutToken ?? '';
      if (token.isNotEmpty) {
        // 与 v8mobile / 热水接口一致：接口层用 X-Id-Token 识别用户。
        headers['X-Id-Token'] = token;
      }
    }
    if (uri.host == 'mycas.hut.edu.cn') {
      // 与 App 内 WebView 登录时携带的头一致，CAS 的 App 免密登录会做校验。
      headers['X-Requested-With'] = 'com.supwisdom.hut';
    }
    if (navigation) {
      headers['Sec-Fetch-Site'] = 'none';
      headers['Sec-Fetch-Mode'] = 'navigate';
      headers['Sec-Fetch-User'] = '?1';
      headers['Sec-Fetch-Dest'] = 'document';
      headers['Upgrade-Insecure-Requests'] = '1';
    } else {
      headers['Sec-Fetch-Site'] = 'same-origin';
      headers['Sec-Fetch-Mode'] = 'navigate';
      headers['Sec-Fetch-Dest'] = 'document';
      headers['Upgrade-Insecure-Requests'] = '1';
    }

    final Map<String, String>? jar = _cookieJar[uri.host];
    if (jar != null && jar.isNotEmpty) {
      headers['Cookie'] = buildHealthCookieHeader(jar);
    }
    return headers;
  }

  String? _decodeStudentNo() {
    final String encoded = _stuNoBase64 ?? '';
    if (encoded.isEmpty) return null;
    try {
      final String decoded = utf8.decode(base64Decode(encoded));
      return decoded.trim().isEmpty ? null : decoded.trim();
    } catch (_) {
      return null;
    }
  }

  String _describeDioError(DioException error) {
    final int? status = error.response?.statusCode;
    if (status != null) return '体测服务返回异常（$status），请稍后重试';
    switch (error.type) {
      case DioExceptionType.connectionTimeout:
      case DioExceptionType.sendTimeout:
      case DioExceptionType.receiveTimeout:
        return '连接体测服务超时，请稍后重试';
      case DioExceptionType.connectionError:
        return '网络连接失败，请检查网络后重试';
      default:
        return '体测服务暂时不可用，请稍后重试';
    }
  }
}

class _ListPage {
  const _ListPage({required this.body, required this.records});

  final String body;
  final List<HealthTermRecord> records;
}

class _FetchedPage {
  const _FetchedPage({required this.uri, required this.body});

  final Uri uri;
  final String body;
}
