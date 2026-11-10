import 'package:flutter/material.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import 'package:url_launcher/url_launcher.dart';

import 'package:superhut/theme/glass/glass_scaffold.dart';

import 'campus_card_api.dart';

/// 校园卡充值 WebView 页。
///
/// 承载完美校园（17wanxiao）校园卡 H5 轻应用：金额输入、支付方式
/// （微信 / 农行掌银）与收银台均为 H5 内建能力，本页只做承载、
/// 外部支付 scheme 放行与加载失败回落。
class CampusCardRechargePage extends StatefulWidget {
  const CampusCardRechargePage({
    super.key,
    required this.entryUrl,
    this.openExternalUrl,
    this.alipayFallbackUrl = CampusCardApi.alipayFallbackUrl,
  });

  /// 校园卡 H5 入口 URL（由 [CampusCardApi.buildEntryUrl] 构建）。
  final Uri entryUrl;

  /// 外部 URL/scheme 打开器，测试可注入；默认 [launchUrl]。
  final Future<bool> Function(Uri url)? openExternalUrl;

  /// 加载失败时「改用支付宝小程序」的兜底 URL。
  final String alipayFallbackUrl;

  @override
  State<CampusCardRechargePage> createState() => _CampusCardRechargePageState();
}

class _CampusCardRechargePageState extends State<CampusCardRechargePage> {
  InAppWebViewController? _controller;
  bool _pageLoading = true;
  String? _loadErrorMessage;
  bool _isLaunchingExternal = false;

  Future<bool> _openExternal(Uri url) async {
    final opener = widget.openExternalUrl ?? launchUrl;
    return opener(url);
  }

  void _handleLoadFailure(String message) {
    if (!mounted) {
      return;
    }
    setState(() {
      _pageLoading = false;
      _loadErrorMessage = message;
    });
  }

  Future<void> _retry() async {
    final controller = _controller;
    if (controller == null) {
      return;
    }
    setState(() {
      _loadErrorMessage = null;
      _pageLoading = true;
    });
    await controller.loadUrl(
      urlRequest: URLRequest(url: WebUri(widget.entryUrl.toString())),
    );
  }

  Future<void> _openAlipayFallback() async {
    if (_isLaunchingExternal) {
      return;
    }
    _isLaunchingExternal = true;
    final navigator = Navigator.of(context);
    final messenger = ScaffoldMessenger.of(context);
    try {
      final opened = await _openExternal(Uri.parse(widget.alipayFallbackUrl));
      if (!mounted) {
        return;
      }
      if (!opened) {
        messenger.showSnackBar(const SnackBar(content: Text('无法打开支付宝，请稍后重试')));
        return;
      }
      navigator.pop();
    } catch (_) {
      messenger.showSnackBar(const SnackBar(content: Text('无法打开支付宝，请稍后重试')));
    } finally {
      _isLaunchingExternal = false;
    }
  }

  Future<void> _openExternalScheme(Uri url) async {
    if (_isLaunchingExternal) {
      return;
    }
    _isLaunchingExternal = true;
    final messenger = ScaffoldMessenger.of(context);
    try {
      final opened = await _openExternal(url);
      if (!mounted) {
        return;
      }
      if (!opened) {
        messenger.showSnackBar(const SnackBar(content: Text('无法打开该应用')));
      }
    } catch (_) {
      messenger.showSnackBar(const SnackBar(content: Text('无法打开该应用')));
    } finally {
      _isLaunchingExternal = false;
    }
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return GlassScaffold(
      title: '校园卡充值',
      // WebView 是原生视图，玻璃镜片采样不到它的画面，关掉滚动边缘色带，
      // 避免顶栏下方横一条与网页内容无关的底色带（与 type1webview 同款处理）。
      showScrollEdge: false,
      insetBody: true,
      body: Stack(
        children: [
          InAppWebView(
            initialUrlRequest: URLRequest(
              url: WebUri(widget.entryUrl.toString()),
            ),
            initialSettings: InAppWebViewSettings(
              javaScriptEnabled: true,
              useShouldOverrideUrlLoading: true,
            ),
            onWebViewCreated: (controller) {
              _controller = controller;
            },
            onLoadStart: (controller, url) {
              if (!mounted) {
                return;
              }
              setState(() {
                _pageLoading = true;
                _loadErrorMessage = null;
              });
            },
            onLoadStop: (controller, url) {
              if (!mounted) {
                return;
              }
              setState(() {
                _pageLoading = false;
              });
            },
            onReceivedError: (controller, request, error) {
              final isMain = request.isForMainFrame ?? true;
              if (isMain) {
                _handleLoadFailure(
                  error.description.isEmpty ? '页面加载失败' : error.description,
                );
              }
            },
            onReceivedHttpError: (controller, request, errorResponse) {
              final isMain = request.isForMainFrame ?? true;
              final statusCode = errorResponse.statusCode ?? 0;
              if (isMain && statusCode >= 400) {
                _handleLoadFailure('服务器返回错误（$statusCode）');
              }
            },
            shouldOverrideUrlLoading: (controller, navigationAction) async {
              final url = navigationAction.request.url;
              if (url == null) {
                return NavigationActionPolicy.ALLOW;
              }
              final scheme = url.scheme.toLowerCase();
              if (scheme == 'http' || scheme == 'https') {
                return NavigationActionPolicy.ALLOW;
              }
              // 微信 / 支付宝 / 掌银等外部 scheme：交由系统打开（微信 H5
              // 支付收银台 wx.tenpay.com 仍为 https 页面，在 WebView 内打开）。
              await _openExternalScheme(url);
              return NavigationActionPolicy.CANCEL;
            },
          ),
          if (_pageLoading && _loadErrorMessage == null)
            Positioned.fill(
              child: Container(
                color: scheme.surface.withValues(alpha: 0.6),
                child: Center(
                  child: CircularProgressIndicator(
                    strokeWidth: 2.4,
                    color: scheme.primary,
                  ),
                ),
              ),
            ),
          if (_loadErrorMessage != null)
            Positioned.fill(
              child: CampusCardErrorView(
                message: _loadErrorMessage!,
                onRetry: _retry,
                onAlipayFallback: _openAlipayFallback,
              ),
            ),
        ],
      ),
    );
  }
}

/// 加载失败视图：提供重试与支付宝小程序兜底。
class CampusCardErrorView extends StatelessWidget {
  const CampusCardErrorView({
    super.key,
    required this.message,
    required this.onRetry,
    required this.onAlipayFallback,
  });

  final String message;
  final VoidCallback onRetry;
  final VoidCallback onAlipayFallback;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Material(
      color: colorScheme.surface,
      child: Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.wifi_off_rounded,
                size: 56,
                color: colorScheme.outline,
              ),
              const SizedBox(height: 16),
              Text('校园卡页面加载失败', style: Theme.of(context).textTheme.titleMedium),
              const SizedBox(height: 8),
              Text(
                message,
                textAlign: TextAlign.center,
                style: Theme.of(
                  context,
                ).textTheme.bodySmall?.copyWith(color: colorScheme.outline),
              ),
              const SizedBox(height: 24),
              FilledButton.icon(
                onPressed: onRetry,
                icon: const Icon(Icons.refresh),
                label: const Text('重试'),
              ),
              const SizedBox(height: 12),
              OutlinedButton.icon(
                onPressed: onAlipayFallback,
                icon: const Icon(Icons.open_in_new),
                label: const Text('改用支付宝小程序'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
