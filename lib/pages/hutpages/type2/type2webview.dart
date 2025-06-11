import 'dart:convert';

import 'package:enhanced_future_builder/enhanced_future_builder.dart';
import 'package:flutter/material.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import 'package:ionicons/ionicons.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:superhut/utils/hut_user_api.dart';
import 'package:url_launcher/url_launcher.dart';

class Type2Webview extends StatefulWidget {
  final String serviceUrl, serviceName, tokenAccept;

  const Type2Webview({
    super.key,
    required this.serviceUrl,
    required this.serviceName,
    required this.tokenAccept,
  });

  @override
  State<Type2Webview> createState() => _Type2WebviewState();
}

class _Type2WebviewState extends State<Type2Webview> {
  final api = HutUserApi();
  InAppWebViewController? _webViewController;
  bool _canGoBack = false;
  bool _isPageLoading = false;
  bool _isRequestingPermission = false;
  bool _permissionRequested = false; // 添加标志，表示权限已请求过
  late Future<bool> _initialSetupFuture;

  Map<String, String> headerMap = {
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
    "cookie": "userToken=; Domain=xzhngydx.hut.edu.cn; Path=/",
    "priority": "u=0, i",
  };
  String resultUrl = '';
  String token = '';

  String enCodeUrl(String url) {
    String encoded = Uri.encodeComponent(url);
    print(encoded);
    return encoded;
  }

  List getTokenAccept(String tokenAccept) {
    try {
      List<dynamic> parsedList = json.decode(tokenAccept);
      List<Map<String, dynamic>> result =
          parsedList.cast<Map<String, dynamic>>();
      return result;
    } catch (e) {
      return [];
    }
  }

  bool doWithAccept() {
    List tokenAcceptList = getTokenAccept(widget.tokenAccept);
    print(tokenAcceptList);
    for (var item in tokenAcceptList) {
      print(item);
      if (item['tokenType'] == 'header') {
        headerMap.addAll({item['tokenKey']: token});
      } else if (item['tokenType'] == 'url') {
        Uri uri = Uri.parse(resultUrl);

        // 2. 获取现有查询参数并添加新参数
        Map<String, String> queryParams = Map.from(uri.queryParameters);
        queryParams[item['tokenKey']] = token; // 添加新参数
        // 3. 构建新 URL（保留路径和其他部分）
        Uri newUri = uri.replace(queryParameters: queryParams);
        resultUrl = newUri.toString();
      }
    }
    print(headerMap);
    return true;
  }

  Future<bool> getDetail() async {
    token = await api.getToken();
    resultUrl = widget.serviceUrl;
    print(resultUrl);
    doWithAccept();
    return true;
  }

  @override
  void initState() {
    super.initState();
    // 在 initState 中初始化而不是在 build 中重复调用
    _initialSetupFuture = _performInitialSetup();
  }

  // 初始化设置，包括权限请求和数据加载
  Future<bool> _performInitialSetup() async {
    await _handleLocationPermission();
    return await getDetail();
  }

  // 处理位置权限一次性请求
  Future<void> _handleLocationPermission() async {
    if (_permissionRequested) return; // 如果已经请求过，不再请求

    setState(() {
      _isRequestingPermission = true;
      _permissionRequested = true;
    });

    try {
      final status = await Permission.location.status;

      // 已经有权限，不需要再请求
      if (status == PermissionStatus.granted) {
        return;
      }

      // 请求权限
      final result = await Permission.location.request();
      if (result != PermissionStatus.granted) {
        // 只在首次拒绝时显示提示，避免重复显示
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('某些功能可能需要位置权限才能正常使用'),
              duration: Duration(seconds: 3),
            ),
          );
        }
      }
    } catch (e) {
      print('请求位置权限错误: $e');
    } finally {
      if (mounted) {
        setState(() {
          _isRequestingPermission = false;
        });
      }
    }
  }

  // 处理WebView的回退逻辑
  Future<bool> _handleBackPressed() async {
    if (_webViewController != null && await _webViewController!.canGoBack()) {
      _webViewController!.goBack();
      return false; // 不关闭页面，只是返回上一个网页
    } else {
      return true; // 关闭页面
    }
  }

  // 更新是否可以回退的状态
  void _updateCanGoBackState() async {
    if (_webViewController != null) {
      bool canGoBack = await _webViewController!.canGoBack();
      if (canGoBack != _canGoBack) {
        setState(() {
          _canGoBack = canGoBack;
        });
      }
    }
  }

  // 删除网页中的导航栏返回按钮
  void _removeNavigationElement() async {
    if (_webViewController != null) {
      // 使用JavaScript删除指定元素
      await _webViewController!.evaluateJavascript(
        source: '''
        (function() {
          function removeElement() {
            var elements = document.querySelectorAll('.van-nav-bar__left');
            if (elements.length > 0) {
              for (var i = 0; i < elements.length; i++) {
                elements[i].style.display = 'none';
              }
              return true;
            }
            return false;
          }
          
          // 立即尝试移除元素
          if (!removeElement()) {
            // 如果元素尚未加载，设置一个观察器来监视DOM变化
            var observer = new MutationObserver(function(mutations) {
              if (removeElement()) {
                observer.disconnect(); // 成功移除后停止观察
              }
            });
            
            observer.observe(document.body, {
              childList: true,
              subtree: true
            });
            
            // 60秒后停止观察以避免内存泄漏
            setTimeout(function() {
              observer.disconnect();
            }, 60000);
          }
        })();
      ''',
      );
    }
  }

  // 监听页面中的支付宝链接
  void _setupAlipayLinkListener() async {
    if (_webViewController != null) {
      await _webViewController!.evaluateJavascript(
        source: '''
        (function() {
          // 拦截所有的a标签点击
          document.addEventListener('click', function(e) {
            var target = e.target;
            // 遍历父元素找到最近的a标签
            while(target && target.tagName !== 'A') {
              target = target.parentElement;
            }
            
            if (target && target.href) {
              var url = target.href;
              if (url.startsWith('alipays://')) {
                // 通知Flutter处理支付宝链接
                window.flutter_inappwebview.callHandler('alipayLink', url);
                e.preventDefault();
                return false;
              }
            }
          }, true);
          
          // 拦截window.location变更
          var originalAssign = window.location.assign;
          window.location.assign = function(url) {
            if (url && url.toString().startsWith('alipays://')) {
              window.flutter_inappwebview.callHandler('alipayLink', url);
              return;
            }
            originalAssign.apply(this, arguments);
          };
          
          var originalReplace = window.location.replace;
          window.location.replace = function(url) {
            if (url && url.toString().startsWith('alipays://')) {
              window.flutter_inappwebview.callHandler('alipayLink', url);
              return;
            }
            originalReplace.apply(this, arguments);
          };
          
          // 拦截window.open
          var originalOpen = window.open;
          window.open = function(url, target, features) {
            if (url && url.toString().startsWith('alipays://')) {
              window.flutter_inappwebview.callHandler('alipayLink', url);
              return null;
            }
            return originalOpen.call(this, url, target, features);
          };
          
          // 监控DOM变化，查找动态添加的支付宝链接
          var observer = new MutationObserver(function(mutations) {
            mutations.forEach(function(mutation) {
              if (mutation.type === 'attributes' && mutation.attributeName === 'href') {
                var element = mutation.target;
                if (element.href && element.href.startsWith('alipays://')) {
                  element.addEventListener('click', function(e) {
                    window.flutter_inappwebview.callHandler('alipayLink', element.href);
                    e.preventDefault();
                  });
                }
              }
            });
          });
          
          observer.observe(document.body, {
            attributes: true,
            attributeFilter: ['href'],
            childList: true,
            subtree: true
          });
        })();
      ''',
      );

      // 注册处理程序来接收JavaScript的回调
      _webViewController!.addJavaScriptHandler(
        handlerName: 'alipayLink',
        callback: (args) {
          if (args.isNotEmpty && args[0] is String) {
            String url = args[0];
            if (url.startsWith('alipays://')) {
              // 不要尝试使用_handleAlipayUrl的返回值
              _handleAlipayUrl(url);
            }
          }
          // 确保回调始终返回一个值给JavaScript
          return true;
        },
      );
    }
  }

  void _handleAlipayUrl(String url) async {
    try {
      final Uri uri = Uri.parse(url);
      print(url);
      if (!await launchUrl(uri)) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('无法打开支付宝: $url')));
        throw Exception('Could not launch $uri');
      } else {
        if (context.mounted) {
          Navigator.of(context).pop();
        }
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('打开链接时发生错误: $e')));
      }
      print('Error launching URL: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: !_canGoBack,
      onPopInvoked: (didPop) async {
        if (didPop) return;

        final shouldPop = await _handleBackPressed();
        if (shouldPop && context.mounted) {
          Navigator.of(context).pop();
        }
      },
      child: SafeArea(
        child: Scaffold(
          extendBodyBehindAppBar: true,
          // 移除AppBar，使用Stack来实现悬浮返回按钮
          body: Stack(
            children: [
              // WebView占满整个屏幕
              Positioned.fill(
                child: EnhancedFutureBuilder(
                  future: _initialSetupFuture,
                  rememberFutureResult: true,
                  whenDone: (v) {
                    return InAppWebView(
                      initialUrlRequest: URLRequest(
                        url: WebUri(resultUrl),
                        headers: headerMap, // 自定义 Header
                      ),
                      initialSettings: InAppWebViewSettings(
                        javaScriptEnabled: true,
                        geolocationEnabled: true,
                        // 启用地理位置功能
                        supportZoom: true,
                        mediaPlaybackRequiresUserGesture: false,
                        // 允许自动播放媒体
                        allowsInlineMediaPlayback: true,
                        useShouldOverrideUrlLoading: true,
                        useOnLoadResource: true,
                      ),
                      onGeolocationPermissionsShowPrompt: (
                        controller,
                        origin,
                      ) async {
                        // 直接允许所有地理位置请求，不再弹出系统对话框
                        return GeolocationPermissionShowPromptResponse(
                          origin: origin,
                          allow: true,
                          retain: true,
                        );
                      },
                      onLoadStart: (controller, url) {
                        setState(() {
                          _isPageLoading = true;
                        });
                        print('Start loading: $url');
                      },
                      onWebViewCreated: (controller) {
                        _webViewController = controller;
                      },
                      onLoadStop: (controller, url) {
                        setState(() {
                          _isPageLoading = false;
                        });
                        _updateCanGoBackState();
                        _removeNavigationElement();
                        _setupAlipayLinkListener(); // 添加支付宝链接监听
                        print('Stop loading: $url');
                      },
                      onUpdateVisitedHistory: (
                        controller,
                        url,
                        androidIsReload,
                      ) {
                        _updateCanGoBackState();
                        print('History updated: $url');
                      },
                      shouldOverrideUrlLoading: (
                        controller,
                        navigationAction,
                      ) async {
                        final url = navigationAction.request.url.toString();

                        // 检查是否是支付宝协议链接
                        if (url.startsWith('alipays://')) {
                          _handleAlipayUrl(url);
                          return NavigationActionPolicy.CANCEL;
                        }

                        return NavigationActionPolicy.ALLOW;
                      },
                    );
                  },
                  whenNotDone: const Center(child: CircularProgressIndicator()),
                ),
              ),

              // 悬浮返回按钮，放在左上角，不会阻挡其他内容的点击
              Positioned(
                top: 8,
                left: 8,
                child: Container(
                  decoration: BoxDecoration(
                    color: Colors.black.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: IconButton(
                    icon: const Icon(
                      Ionicons.arrow_back_circle_outline,
                      color: Colors.white,
                      size: 28,
                    ),
                    onPressed: () async {
                      if (await _handleBackPressed()) {
                        if (context.mounted) {
                          Navigator.of(context).pop();
                        }
                      }
                    },
                  ),
                ),
              ),

              // 网页加载指示器
              if (_isPageLoading)
                Positioned.fill(
                  child: Container(
                    color: Colors.black.withOpacity(0.3),
                    child: Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const CircularProgressIndicator(
                            valueColor: AlwaysStoppedAnimation<Color>(
                              Colors.white,
                            ),
                          ),
                          const SizedBox(height: 16),
                          Text(
                            '加载中...',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              // 权限请求指示器
              if (_isRequestingPermission)
                Positioned.fill(
                  child: Container(
                    color: Colors.black.withOpacity(0.3),
                    child: Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const CircularProgressIndicator(
                            valueColor: AlwaysStoppedAnimation<Color>(
                              Colors.white,
                            ),
                          ),
                          const SizedBox(height: 16),
                          const Text(
                            '请求位置权限...',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
