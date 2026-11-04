import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:umeng_apm_sdk/src/processor/api_data_processor.dart';
import 'package:umeng_apm_sdk/src/core/apm_method_channel.dart';
import 'package:umeng_apm_sdk/src/event/event.dart';
import 'package:umeng_apm_sdk/src/data/data.dart';
import 'package:umeng_apm_sdk/src/recorder/base_recorder.dart';
import 'package:umeng_apm_sdk/src/core/apm_pubsub_event_center.dart';
import 'package:umeng_apm_sdk/src/core/apm_shared.dart';
import 'package:umeng_apm_sdk/src/utils/helpers.dart';

import '../core/apm_flutter_error.dart';

class HttpClientRequestWithChecker implements HttpClientRequest {
  final HttpClientRequest _realRequest;
  final Stopwatch _stopwatch;

  HttpClientRequestWithChecker(this._realRequest, this._stopwatch);

  @override
  bool get bufferOutput => _realRequest.bufferOutput;

  @override
  int get contentLength => _realRequest.contentLength;

  @override
  Encoding get encoding => _realRequest.encoding;

  @override
  bool get followRedirects => _realRequest.followRedirects;

  @override
  int get maxRedirects => _realRequest.maxRedirects;

  @override
  bool get persistentConnection => _realRequest.persistentConnection;

  @override
  void add(List<int> data) {
    _realRequest.add(data);
  }

  @override
  void addError(Object error, [StackTrace? stackTrace]) {
    _realRequest.addError(error, stackTrace);
  }

  @override
  Future addStream(Stream<List<int>> stream) {
    return _realRequest.addStream(stream);
  }

  @override
  Future<HttpClientResponse> close() async {
    return _realRequest.close().then((HttpClientResponse response) {
      _checkResponse(_realRequest, response);
      return response;
    }).catchError((dynamic error, dynamic stackTrace) {
      throw ApmFlutterError(error, stackTrace);
    }, test: (error) {
      nativeTryCatch(handler: () async{
        _stopwatch.stop();
        String message;
        if (error is HttpException) {
          message = error.message;
        } else {
          message = error.toString(); // 信息可能更长
        }
        // PerformanceDataCenter().push(RequestUploadData(
        //   message: message,
        //   uri: _realRequest.uri,
        //   method: method,
        //   requestHeaders: _realRequest.headers,
        //   status: -1,
        //   spent: _stopwatch.elapsedMilliseconds,
        //   pageInfoData: pageInfoData,
        //   src: 'request.err'
        // ));
        //APM请求直接上报
        String uri = _realRequest.uri.toString();
        var needUpload = uri.contains("errlog.umeng.com");
        if (needUpload == true) {
          return;
        }
        //非APM请求记录
        Map<String, dynamic>? nativeInfo =
        await ApmMethodChannel.getNativeParams();
        ApiDataProcessor apiDataProcessor = ApiDataProcessor(nativeInfo);
        final apiData = ApiData(_realRequest.uri.toString(),
            _realRequest.method,
            -1,
            _stopwatch.elapsedMilliseconds,
            _realRequest.headers.contentLength + _realRequest.contentLength,
            -1,
            3,
          message
        );
        apiDataProcessor.push(apiData: apiData);
        ApmPubsubEventCenter().dispatchEvent(ACTIONS.SEND_API_LOG, null);
      });
      return true;
    });
  }

  @override
  HttpConnectionInfo? get connectionInfo => _realRequest.connectionInfo;

  @override
  List<Cookie> get cookies => _realRequest.cookies;

  @override
  Future<HttpClientResponse> get done async {
    return close();
  }

  @override
  Future flush() {
    return _realRequest.flush();
  }

  @override
  HttpHeaders get headers => _realRequest.headers;

  @override
  String get method => _realRequest.method;

  @override
  Uri get uri => _realRequest.uri;

  @override
  void write(Object? obj) {
    _realRequest.write(obj);
  }

  @override
  void writeAll(Iterable objects, [String separator = '']) {
    _realRequest.writeAll(objects, separator);
  }

  @override
  void writeCharCode(int charCode) {
    _realRequest.writeCharCode(charCode);
  }

  @override
  void writeln([Object? obj = '']) {
    _realRequest.writeln(obj);
  }

  void _checkResponse(HttpClientRequest request, HttpClientResponse response) {
    nativeTryCatch(handler: () async{
      String message = 'status ${response.statusCode}';
      message = '$message: ${response.reasonPhrase}';
      _stopwatch.stop();
      // PerformanceDataCenter().push(RequestUploadData(
      //   message: message,
      //   uri: request.uri,
      //   method: request.method,
      //   requestHeaders: request.headers,
      //   responseHeaders: response.headers,
      //   status: response.statusCode,
      //   spent: _stopwatch.elapsedMilliseconds,
      //   pageInfoData: pageInfoData,
      //   src: 'request.succ'
      // ));
      //APM请求直接上报
      String uri = request.uri.toString();
      var needUpload = uri.contains("errlog.umeng.com");
      if (needUpload == true) {
        return;
      }
      //非APM请求记录
      Map<String, dynamic>? nativeInfo =
      await ApmMethodChannel.getNativeParams();
      ApiDataProcessor apiDataProcessor = ApiDataProcessor(nativeInfo);
      //判断数据类型
      int type;
      if (response.statusCode >= 200 && response.statusCode < 400) {
        type = 1;
      } else {
        type = 2;
      }
      final apiData = ApiData(request.uri.toString(),
          request.method,
          response.statusCode,
          _stopwatch.elapsedMilliseconds,
          request.headers.contentLength + request.contentLength,
          response.headers.contentLength + response.contentLength,
          type,
          message
      );
      apiDataProcessor.push(apiData: apiData);
      ApmPubsubEventCenter().dispatchEvent(ACTIONS.SEND_API_LOG, null);
    });
  }

  @override
  set bufferOutput(bool _bufferOutput) {
    _realRequest.bufferOutput = _bufferOutput;
  }

  @override
  set contentLength(int _contentLength) {
    _realRequest.contentLength = _contentLength;
  }

  @override
  set encoding(Encoding _encoding) {
    _realRequest.encoding = _encoding;
  }

  @override
  set followRedirects(bool _followRedirects) {
    _realRequest.followRedirects = _followRedirects;
  }

  @override
  set maxRedirects(int _maxRedirects) {
    _realRequest.maxRedirects = _maxRedirects;
  }

  @override
  set persistentConnection(bool _persistentConnection) {
    _realRequest.persistentConnection = _persistentConnection;
  }

  @override
  void abort([Object? exception, StackTrace? stackTrace]) {
    _realRequest.abort(exception, stackTrace);
  }
}

class HttpClientWithChecker implements HttpClient {
  final HttpClient _realClient;

  Uri? url;
  String? method;

  HttpClientWithChecker(this._realClient);

  @override
  void set connectionFactory(
      Future<ConnectionTask<Socket>> Function(
              Uri url, String? proxyHost, int? proxyPort)?
          f) {
    // TODO: add impl here
    assert(false);
  }

  @override
  void set keyLog(Function(String line)? callback) {
    // TODO: add impl here
    assert(false);
  }

  @override
  bool get autoUncompress => _realClient.autoUncompress;

  @override
  set autoUncompress(bool value) => _realClient.autoUncompress = value;

  @override
  Duration? get connectionTimeout => _realClient.connectionTimeout;

  @override
  set connectionTimeout(Duration? value) =>
      _realClient.connectionTimeout = value;

  @override
  Duration get idleTimeout => _realClient.idleTimeout;

  @override
  set idleTimeout(Duration value) => _realClient.idleTimeout = value;

  @override
  int? get maxConnectionsPerHost => _realClient.maxConnectionsPerHost;

  @override
  set maxConnectionsPerHost(int? value) =>
      _realClient.maxConnectionsPerHost = value;

  @override
  String? get userAgent => _realClient.userAgent;

  @override
  set userAgent(String? value) => _realClient.userAgent = value;

  @override
  void addCredentials(
          Uri url, String realm, HttpClientCredentials credentials) =>
      _realClient.addCredentials(url, realm, credentials);

  @override
  void addProxyCredentials(String host, int port, String realm,
          HttpClientCredentials credentials) =>
      _realClient.addProxyCredentials(host, port, realm, credentials);

  @override
  set authenticate(
          Future<bool> Function(Uri url, String scheme, String? realm)? f) =>
      _realClient.authenticate = f;

  @override
  set authenticateProxy(
          Future<bool> Function(
                  String host, int port, String scheme, String? realm)?
              f) =>
      _realClient.authenticateProxy = f;

  @override
  set badCertificateCallback(
          bool Function(X509Certificate cert, String host, int port)?
              callback) =>
      _realClient.badCertificateCallback = callback;

  @override
  void close({bool force = false}) => _realClient.close(force: force);

  @override
  Future<HttpClientRequest> delete(String host, int port, String path) =>
      _realClient.delete(host, port, path);

  @override
  Future<HttpClientRequest> deleteUrl(Uri url) => _realClient.deleteUrl(url);

  @override
  set findProxy(String Function(Uri url)? f) => _realClient.findProxy = f;

  @override
  Future<HttpClientRequest> get(String host, int port, String path) =>
      _realClient.get(host, port, path);

  @override
  Future<HttpClientRequest> getUrl(Uri url) =>
      _addCheck(_realClient.getUrl(url), 'get', url);

  @override
  Future<HttpClientRequest> head(String host, int port, String path) =>
      _realClient.head(host, port, path);

  @override
  Future<HttpClientRequest> headUrl(Uri url) =>
      _addCheck(_realClient.headUrl(url), 'head', url);

  @override
  Future<HttpClientRequest> patch(String host, int port, String path) =>
      _realClient.patch(host, port, path);

  @override
  Future<HttpClientRequest> patchUrl(Uri url) =>
      _addCheck(_realClient.patchUrl(url), 'patch', url);

  @override
  Future<HttpClientRequest> post(String host, int port, String path) =>
      _realClient.post(host, port, path);

  @override
  Future<HttpClientRequest> postUrl(Uri url) =>
      _addCheck(_realClient.postUrl(url), 'post', url);

  @override
  Future<HttpClientRequest> put(String host, int port, String path) =>
      _realClient.put(host, port, path);

  @override
  Future<HttpClientRequest> putUrl(Uri url) =>
      _addCheck(_realClient.putUrl(url), 'put', url);

  @override
  Future<HttpClientRequest> open(
      String method, String host, int port, String path) {
    const int hashMark = 0x23;
    const int questionMark = 0x3f;
    int fragmentStart = path.length;
    int queryStart = path.length;
    for (int i = path.length - 1; i >= 0; i--) {
      final char = path.codeUnitAt(i);
      if (char == hashMark) {
        fragmentStart = i;
        queryStart = i;
      } else if (char == questionMark) {
        queryStart = i;
      }
    }
    String? query;
    if (queryStart < fragmentStart) {
      query = path.substring(queryStart + 1, fragmentStart);
      path = path.substring(0, queryStart);
    }
    final Uri uri =
        Uri(scheme: 'http', host: host, port: port, path: path, query: query);
    return _addCheck(_realClient.open(method, host, port, path), method, uri);
  }

  @override
  Future<HttpClientRequest> openUrl(String method, Uri url) =>
      _addCheck(_realClient.openUrl(method, url), method, url);

  Future<HttpClientRequest> _addCheck(
      Future<HttpClientRequest> _request, String method, Uri url) {
    final Stopwatch stopwatch = Stopwatch()..start();
    return _request
        .then((HttpClientRequest request) =>
            HttpClientRequestWithChecker(request, stopwatch))
        .catchError((dynamic error, dynamic stackTrace){
      throw ApmFlutterError(error, stackTrace);
    }, test: (error) {
      nativeTryCatch(handler: () async{
        stopwatch.stop();
        String message = error.toString();
        if (error is SocketException) {
          message = error.message;
        }
        // PerformanceDataCenter().push(RequestUploadData(
        //   message: message,
        //   uri: url,
        //   method: method,
        //   requestHeaders: null,
        //   status: -1,
        //   spent: stopwatch.elapsedMilliseconds,
        //   pageInfoData: pageInfoData,
        //   src: 'httpclient.err'
        // ));
        //APM请求直接上报
        String uri = url.toString();
        var needUpload = uri.contains("errlog.umeng.com");
        if (needUpload == true) {
          return;
        }
        //非APM请求记录
        Map<String, dynamic>? nativeInfo =
        await ApmMethodChannel.getNativeParams();
        ApiDataProcessor apiDataProcessor = ApiDataProcessor(nativeInfo);
        final apiData = ApiData(url.toString(),
            method,
            -1,
            stopwatch.elapsedMilliseconds,
            -1,
            -1,
            3,
            message);
        apiDataProcessor.push(apiData: apiData);
        ApmPubsubEventCenter().dispatchEvent(ACTIONS.SEND_API_LOG, null);
      });
      return true;
    });
  }
}

class _DefaultHttpOverrides extends HttpOverrides {}

class MyHttpOverrides extends HttpOverrides {
  HttpOverrides? _currentOverrides;

  MyHttpOverrides(this._currentOverrides) : super() {
    _currentOverrides ??= _DefaultHttpOverrides();
  }

  @override
  HttpClient createHttpClient(SecurityContext? context) {
    return HttpClientWithChecker(_currentOverrides!.createHttpClient(context));
  }

  @override
  String findProxyFromEnvironment(Uri url, Map<String, String>? environment) {
    return _currentOverrides!.findProxyFromEnvironment(url, environment);
  }
}

class RequestRecorder extends BaseRecorder {
  @override
  void onReceivedEvent(BaseEvent event) {}

  @override
  List<Type> subscribedEventList() {
    return [];
  }

  RequestRecorder() {
    HttpOverrides.global = MyHttpOverrides(HttpOverrides.current);
  }
}
