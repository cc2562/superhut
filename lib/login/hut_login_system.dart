import 'package:clarity_flutter/clarity_flutter.dart';
import 'package:flutter/material.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';

import 'auth_status_view.dart';

bool isHutCasAuthenticationPage(String url) {
  final uri = Uri.tryParse(url);
  if (uri == null ||
      uri.host.toLowerCase() != 'mycas.hut.edu.cn' ||
      uri.path != '/cas/login') {
    return false;
  }
  return true;
}

class HutLoginSystem extends StatefulWidget {
  /// The initial idToken to pass to the CAS login URL
  final String initialIdToken;

  /// Callback function when token and cookie are successfully extracted
  final Function(Map<String, String>) onTokenAndCookieExtracted;

  /// Callback function when an error occurs during the login process
  final Function(String)? onError;

  /// Called when CAS displays its interactive login page instead of completing
  /// the token exchange.
  final VoidCallback? onAuthenticationRequired;

  const HutLoginSystem({
    Key? key,
    required this.initialIdToken,
    required this.onTokenAndCookieExtracted,
    this.onError,
    this.onAuthenticationRequired,
  }) : super(key: key);

  @override
  State<HutLoginSystem> createState() => _HutLoginSystemState();
}

class _HutLoginSystemState extends State<HutLoginSystem> {
  InAppWebViewController? _webViewController;
  bool _isLoading = true;

  /// 是否已经成功加载过至少一页。
  ///
  /// CAS 会连续重定向（mycas → jwxtsj），只有第一次才需要整页占位；
  /// 之后仅用顶部细进度条反馈，避免整屏反复闪烁。
  bool _hasCompletedFirstLoad = false;

  /// 网页加载失败时的说明；非空时整页显示错误态。
  String? _loadError;

  String _currentUrl = '';
  final String _targetDomain = 'jwxtsj.hut.edu.cn';
  final String _initialUrl = 'https://mycas.hut.edu.cn/cas/login';
  bool _authenticationFailureReported = false;

  /// CAS 登录入口：带上智慧工大 idToken，成功后由教务系统回跳并带上 token。
  String get _loginUrl =>
      '$_initialUrl?idToken=${widget.initialIdToken}'
      '&service=https%3A%2F%2Fjwxtsj.hut.edu.cn%2Fnjwhd%2FloginSso'
      '&token=${widget.initialIdToken}';

  /// 失败后重新载入认证入口。
  void _retryLoad() {
    setState(() {
      _loadError = null;
      _isLoading = true;
      _hasCompletedFirstLoad = false;
    });
    _webViewController?.loadUrl(urlRequest: URLRequest(url: WebUri(_loginUrl)));
  }

  void _reportAuthenticationRequired() {
    if (_authenticationFailureReported) return;
    _authenticationFailureReported = true;
    widget.onAuthenticationRequired?.call();
  }

  @override
  void initState() {
    super.initState();
  }

  // 检查URL并提取token和cookie
  void _checkUrlAndExtractTokenAndCookie(String url) async {
    _currentUrl = url;

    if (url.contains(_targetDomain) && url.contains('token=')) {
      try {
        // 解析URL获取token
        Uri uri = Uri.parse(url);
        String? token;

        // 如果URL包含片段(#)，需要特殊处理
        String fragment = uri.fragment;
        if (fragment.isNotEmpty && fragment.contains('token=')) {
          // 处理 #/casLogin?token=theNewToken&userType=2&toMenu=null 这种格式
          int tokenStartIndex =
              fragment.indexOf('token=') + 6; // 'token='.length
          int tokenEndIndex = fragment.indexOf('&', tokenStartIndex);

          if (tokenEndIndex == -1) {
            // 如果token是最后一个参数
            tokenEndIndex = fragment.length;
          }

          token = fragment.substring(tokenStartIndex, tokenEndIndex);
        } else {
          // 正常查询参数处理
          token = uri.queryParameters['token'];
        }

        if (token != null && token.isNotEmpty && _webViewController != null) {
          // 获取cookie
          String? myClientTicket = await _getCookie('my_client_ticket');

          // 创建结果Map
          Map<String, String> result = {
            'token': token,
            'my_client_ticket': myClientTicket ?? '',
          };

          widget.onTokenAndCookieExtracted(result);
        }
      } catch (e) {
        if (widget.onError != null) {
          widget.onError!('Token和Cookie提取错误: $e');
        }
      }
    }
  }

  // 获取指定名称的cookie
  Future<String?> _getCookie(String cookieName) async {
    if (_webViewController == null) return null;

    try {
      CookieManager cookieManager = CookieManager.instance();
      List<Cookie> cookies = await cookieManager.getCookies(
        url: WebUri(_currentUrl),
      );

      for (Cookie cookie in cookies) {
        if (cookie.name == cookieName) {
          return cookie.value;
        }
      }

      // 如果在当前域名没找到，尝试从其他相关域名获取
      List<String> relatedDomains = [
        'https://mycas.hut.edu.cn',
        'https://jwxtsj.hut.edu.cn',
      ];

      for (String domain in relatedDomains) {
        try {
          List<Cookie> domainCookies = await cookieManager.getCookies(
            url: WebUri(domain),
          );
          for (Cookie cookie in domainCookies) {
            if (cookie.name == cookieName) {
              return cookie.value;
            }
          }
        } catch (e) {
          // 忽略单个域名的错误，继续尝试下一个
          print('获取域名 $domain 的cookie时出错: $e');
        }
      }

      return null;
    } catch (e) {
      print('获取cookie时出错: $e');
      return null;
    }
  }

  @override
  Widget build(BuildContext context) {
    final ColorScheme colors = Theme.of(context).colorScheme;
    return Scaffold(
      backgroundColor: colors.surface,
      // 认证流程内不允许返回，避免中断登录；失败态另给「返回」按钮。
      body: SafeArea(
        child: Stack(
          fit: StackFit.expand,
          children: <Widget>[
            // 统一认证网页包含学号密码，整块遮罩，避免被 Clarity 会话录制采集。
            ClarityMask(
              child: InAppWebView(
                initialUrlRequest: URLRequest(
                  url: WebUri(_loginUrl),
                  headers: {
                    "User-Agent":
                        "Mozilla/5.0 (Linux; Android 15; 24129PN74C Build/AQ3A.240812.002; wv) AppleWebKit/537.36 (KHTML, like Gecko) Version/4.0 Chrome/134.0.6998.39 Mobile Safari/537.36 SuperApp",
                    "Connection": "keep-alive",
                    "Accept":
                        "text/html,application/xhtml+xml,application/xml;q=0.9,image/avif,image/webp,image/apng,*/*;q=0.8,application/signed-exchange;v=b3;q=0.7",
                    "Accept-Encoding": "gzip, deflate, br, zstd",
                    "sec-ch-ua":
                        "\"Chromium\";v=\"134\", \"Not:A-Brand\";v=\"24\", \"Android WebView\";v=\"134\"",
                    "sec-ch-ua-mobile": "?1",
                    "sec-ch-ua-platform": "\"Android\"",
                    "upgrade-insecure-requests": "1",
                    "x-requested-with": "com.supwisdom.hut",
                    "sec-fetch-site": "none",
                    "sec-fetch-mode": "navigate",
                    "sec-fetch-user": "?1",
                    "sec-fetch-dest": "document",
                    "accept-language": "zh-CN,zh;q=0.9,en-US;q=0.8,en;q=0.7",
                  },
                ),
                initialOptions: InAppWebViewGroupOptions(
                  crossPlatform: InAppWebViewOptions(
                    useShouldOverrideUrlLoading: true,
                    useOnLoadResource: true,
                    javaScriptEnabled: true,
                    cacheEnabled: true,
                  ),
                ),
                onWebViewCreated: (controller) {
                  _webViewController = controller;
                },
                shouldOverrideUrlLoading: (controller, navigationAction) async {
                  final url = navigationAction.request.url.toString();
                  _checkUrlAndExtractTokenAndCookie(url);
                  return NavigationActionPolicy.ALLOW;
                },
                onLoadStart: (controller, url) {
                  if (url != null) {
                    setState(() {
                      _isLoading = true;
                      _loadError = null;
                      _currentUrl = url.toString();
                    });
                    _checkUrlAndExtractTokenAndCookie(_currentUrl);
                  }
                },
                onLoadStop: (controller, url) {
                  if (url != null) {
                    final loadedUrl = url.toString();
                    setState(() {
                      _isLoading = false;
                      _hasCompletedFirstLoad = true;
                      _loadError = null;
                      _currentUrl = loadedUrl;
                    });
                    if (isHutCasAuthenticationPage(loadedUrl)) {
                      _reportAuthenticationRequired();
                      return;
                    }
                    _checkUrlAndExtractTokenAndCookie(_currentUrl);

                    // 不再打印当前 URL 与页面 console：其中的 code / ticket 参数
                    // 本身就是凭据，认证相关的任何内容都不应进日志。
                  }
                },
                onLoadError: (controller, url, code, message) {
                  setState(() {
                    _isLoading = false;
                    // 首次就没加载成功时也要结束整页占位，转到错误态。
                    _hasCompletedFirstLoad = true;
                    // 固定文案：message 与 URL 里可能带 idToken / ticket。
                    _loadError = '认证页面加载失败，请检查网络后重试';
                  });
                  if (widget.onError != null) {
                    widget.onError!('页面加载错误: $message');
                  }
                },
              ),
            ),
            // 首次加载：整页不透明占位，避免露出半张空白网页。
            if (!_hasCompletedFirstLoad && _loadError == null)
              ColoredBox(
                color: colors.surface,
                child: const AuthStatusView(
                  icon: Icons.lock_outline_rounded,
                  title: '正在进入统一认证',
                  description: '正在加载登录页面，首次进入可能需要几秒',
                  showProgress: true,
                ),
              ),
            // 加载失败：覆盖网页，给出重试与返回。
            if (_loadError != null)
              ColoredBox(
                color: colors.surface,
                child: AuthStatusView(
                  icon: Icons.cloud_off_rounded,
                  title: '认证页面加载失败',
                  description: _loadError!,
                  isError: true,
                  actions: <Widget>[
                    FilledButton(
                      onPressed: _retryLoad,
                      child: const Text('重新尝试'),
                    ),
                    TextButton(
                      onPressed: () => Navigator.of(context).maybePop(),
                      child: const Text('返回'),
                    ),
                  ],
                ),
              ),
            // 后续重定向：半透明遮罩 + 与首次加载一致的状态页。
            if (_isLoading && _hasCompletedFirstLoad && _loadError == null)
              ColoredBox(
                color: colors.surface.withValues(alpha: 0.85),
                child: const AuthStatusView(
                  icon: Icons.lock_outline_rounded,
                  title: '正在登录教务系统',
                  description: '正在与教务系统完成认证，请稍候',
                  showProgress: true,
                ),
              ),
          ],
        ),
      ),
    );
  }
}

// 使用示例：

class HutLoginExample extends StatelessWidget {
  final String idToken;

  const HutLoginExample({Key? key, required this.idToken}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return HutLoginSystem(
      initialIdToken: idToken,
      onTokenAndCookieExtracted: (result) {
        // 处理提取到的token和cookie（认证数据不打印）
        // 这里可以保存token和cookie或导航到其他页面
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('登录成功！')));
        Navigator.of(context).pop(result); // 返回包含token和cookie的Map并关闭页面
      },
      onError: (errorMessage) {
        // ScaffoldMessenger.of(context).showSnackBar(
        //   SnackBar(content: Text(errorMessage), backgroundColor: Colors.red),
        // );
      },
    );
  }
}
