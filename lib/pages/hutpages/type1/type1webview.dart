import 'package:enhanced_future_builder/enhanced_future_builder.dart';
import 'package:flutter/material.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import 'package:loading_animation_widget/loading_animation_widget.dart';
import 'package:superhut/utils/hut_user_api.dart';

class Type1Webview extends StatefulWidget {
  final String serviceUrl, serviceName;

  const Type1Webview({
    super.key,
    required this.serviceUrl,
    required this.serviceName,
  });

  @override
  State<Type1Webview> createState() => _Type1WebviewState();
}

class _Type1WebviewState extends State<Type1Webview> {
  final String baseUrl = 'https://mycas.hut.edu.cn/cas/login?service=';
  final api = HutUserApi();
  String resultUrl = '';
  String token = '';
  bool _isPageLoading = false;

  String enCodeUrl(String url) {
    String encoded = Uri.encodeComponent(url);
    print(encoded);
    return encoded;
  }

  Future<bool> getDetail() async {
    token = await api.getToken();
    resultUrl = "$baseUrl${enCodeUrl(widget.serviceUrl)}&idToken=$token";
    print(resultUrl);
    return true;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text("智慧工大")),
      body: EnhancedFutureBuilder(
        future: getDetail(),
        rememberFutureResult: true,
        whenDone: (v) {
          return Stack(
            children: [
              InAppWebView(
                initialUrlRequest: URLRequest(
                  url: WebUri(resultUrl),
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
                    "Upgrade-Insecure-Requests": "1",
                    "x-id-token": token,
                    "X-Requested-With": "com.supwisdom.hut",
                    "Sec-Fetch-Site": "none",
                    "Sec-Fetch-Mode": "navigate",
                    "Sec-Fetch-User": "?1",
                    "Sec-Fetch-Dest": "document",
                    "Accept-Language": "zh-CN,zh;q=0.9,en-US;q=0.8,en;q=0.7",
                    "Cookie":
                        "userToken=$token; Domain=mycas.hut.edu.cn; Path=/",
                  }, // 自定义 Header
                ),

                onLoadStart: (controller, url) {
                  setState(() {
                    _isPageLoading = true;
                  });
                  print('Start loading: $url');
                },

                onLoadStop: (controller, url) {
                  setState(() {
                    _isPageLoading = false;
                  });
                },
              ),
              if (_isPageLoading)
                Positioned.fill(
                  child: Container(
                    color: Colors.black.withOpacity(0.3),
                    child: Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                           LoadingAnimationWidget.inkDrop(
                        color: Theme.of(context).primaryColor,
          size: 40,
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
            ],
          );
        },
        whenNotDone: Center(child: CircularProgressIndicator()),
      ),
    );
  }
}
