import 'dart:async';

import 'package:flutter/material.dart';
import 'package:superhut/security/credential_store.dart';
import 'package:superhut/theme/glass/glass_scaffold.dart';
import 'package:superhut/utils/hut_user_api.dart';
import 'package:superhut/utils/token.dart';

import 'hut_login_system.dart';

class HutCasLoginPage extends StatefulWidget {
  /// 登录完成后的回调函数
  final Function(Map<String, String>)? onLoginComplete;

  /// 是否在登录成功后自动返回
  final bool popOnSuccess;

  /// 用于储存和获取token的键名
  final String tokenKey;

  /// 用于储存和获取my_client_ticket的键名
  final String cookieKey;

  const HutCasLoginPage({
    Key? key,
    this.onLoginComplete,
    this.popOnSuccess = true,
    this.tokenKey = 'token',
    this.cookieKey = 'my_client_ticket',
  }) : super(key: key);

  @override
  State<HutCasLoginPage> createState() => _HutCasLoginPageState();
}

class _HutCasLoginPageState extends State<HutCasLoginPage> {
  final HutUserApi _api = HutUserApi();
  bool _isLoading = true;
  String _idToken = '';
  String? _errorMessage;
  bool _isFinishing = false;

  @override
  void initState() {
    super.initState();
    _getIdToken();
  }

  // 获取用于CAS登录的idToken
  Future<void> _getIdToken() async {
    try {
      _idToken = await _api.getToken();
      /*
      _api.checkTokenValidity().then((isValid) async {
        if (!isValid) {
          await _api.refreshToken();
          _idToken = await _api.getToken();
        }
      });

       */
      final refreshed = await _api.refreshToken();
      if (!refreshed) {
        await _finishWithAuthenticationFailure();
        return;
      }
      _idToken = await _api.getToken();
      if (_idToken.trim().isEmpty) {
        await _finishWithAuthenticationFailure();
        return;
      }
      if (!mounted) return;
      setState(() {
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _isLoading = false;
        _errorMessage = '获取认证令牌失败: $e';
      });
    }
  }

  Future<void> _finishWithAuthenticationFailure() async {
    if (_isFinishing) return;
    _isFinishing = true;
    await HutCasTokenRetriever.clearCachedSession();
    if (mounted) {
      Navigator.of(context).pop<Map<String, String>?>(null);
    }
  }

  Future<void> _handleCasAuthenticationRequired() async {
    await _api.clearAuthenticationState();
    await _finishWithAuthenticationFailure();
  }

  // 保存获取到的新token和cookie
  Future<void> _saveTokenAndCookie(Map<String, String> data) async {
    try {
      String token = data['token'] ?? '';
      String myClientTicket = data['my_client_ticket'] ?? '';

      // 保存token（凭据走系统安全存储；键名由调用方传入，可能不是固定的）
      if (token.isNotEmpty) {
        await CredentialStore.instance.write(widget.tokenKey, token);
      }

      // 保存cookie
      if (myClientTicket.isNotEmpty) {
        await CredentialStore.instance.write(widget.cookieKey, myClientTicket);
      }

      if (widget.onLoginComplete != null) {
        widget.onLoginComplete!(data);
      }

      if (widget.popOnSuccess && mounted) {
        Navigator.of(context).pop(data);
      }
    } catch (e) {
      if (mounted) {
        // ScaffoldMessenger.of(context).showSnackBar(
        //   SnackBar(content: Text('保存token和cookie失败: $e'), backgroundColor: Colors.red),
        // );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return GlassScaffold(
        title: 'HUT统一认证',
        showBackButton: false,
        insetBody: true,
        body: const Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              CircularProgressIndicator(),
              SizedBox(height: 16),
              Text('正在准备登录...'),
            ],
          ),
        ),
      );
    }

    if (_errorMessage != null) {
      return GlassScaffold(
        title: 'HUT统一认证',
        showBackButton: false,
        insetBody: true,
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.error_outline,
                color: Theme.of(context).colorScheme.error,
                size: 48,
              ),
              const SizedBox(height: 16),
              Text(_errorMessage!, textAlign: TextAlign.center),
              const SizedBox(height: 24),
              ElevatedButton(
                onPressed: () {
                  setState(() {
                    _errorMessage = null;
                    _isLoading = true;
                  });
                  _getIdToken();
                },
                child: const Text('重试'),
              ),
            ],
          ),
        ),
      );
    }

    return HutLoginSystem(
      initialIdToken: _idToken,
      onTokenAndCookieExtracted: _saveTokenAndCookie,
      onAuthenticationRequired: _handleCasAuthenticationRequired,
      onError: (errorMessage) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(errorMessage),
              backgroundColor: Theme.of(context).colorScheme.errorContainer,
            ),
          );
        }
      },
    );
  }
}

// 使用示例
class HutCasLoginExample extends StatelessWidget {
  const HutCasLoginExample({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return ElevatedButton(
      onPressed: () async {
        final result = await Navigator.of(context).push(
          MaterialPageRoute(
            builder:
                (context) => const HutCasLoginPage(
                  tokenKey: 'token',
                  cookieKey: 'my_client_ticket',
                ),
          ),
        );
        if (result != null && result is Map<String, String>) {
          // 使用获取到的token和cookie（不再打印，认证数据一律不进日志）
        }
      },
      child: const Text('登录教务系统'),
    );
  }
}

// 另一种使用方式 - 获取token和cookie不返回
class HutCasTokenRetriever {
  /// Clears the cached academic-system session before switching HUT accounts.
  static Future<void> clearCachedSession() async {
    final store = CredentialStore.instance;
    await store.delete('token');
    await store.delete('my_client_ticket');
  }

  static Future<Map<String, String>?> getJwxtTokenAndCookie(
    BuildContext context,
  ) async {
    // 先检查是否有缓存的token（在系统安全存储里）
    final store = CredentialStore.instance;
    final cachedToken = await store.readOrEmpty('token');
    final cachedCookie = await store.readOrEmpty('my_client_ticket');
    print('开始');
    if (cachedToken.isNotEmpty) {
      // 使用token.dart中的checkTokenValid方法验证token有效性
      bool isTokenValid = await checkTokenValid();
      if (isTokenValid) {
        return {'token': cachedToken, 'my_client_ticket': cachedCookie};
      }
      // Token无效，需要重新登录
    }
    print('流程');
    if (!context.mounted) return null;
    // 如果没有缓存或缓存无效，进行登录流程
    final completer = Completer<Map<String, String>?>();

    Navigator.of(context)
        .push(
          MaterialPageRoute(
            builder:
                (context) => HutCasLoginPage(
                  popOnSuccess: true,
                  onLoginComplete: (data) {
                    completer.complete(data);
                  },
                ),
          ),
        )
        .then((value) {
          // 如果用户取消或返回，且completer尚未完成，则完成completer为null
          if (!completer.isCompleted) {
            completer.complete(value as Map<String, String>?);
          }
        });

    return completer.future;
  }

  // 保持向后兼容性的方法
  static Future<String?> getJwxtToken(BuildContext context) async {
    Map<String, String>? result = await getJwxtTokenAndCookie(context);
    return result?['token'];
  }
}
