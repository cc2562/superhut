import 'dart:async';

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:superhut/utils/hut_user_api.dart';
import 'package:superhut/utils/token.dart';

import 'hut_login_system.dart';

class HutCasLoginPage extends StatefulWidget {
  /// 登录完成后的回调函数
  final Function(String)? onLoginComplete;

  /// 是否在登录成功后自动返回
  final bool popOnSuccess;

  /// 用于储存和获取token的键名
  final String tokenKey;

  const HutCasLoginPage({
    Key? key,
    this.onLoginComplete,
    this.popOnSuccess = true,
    this.tokenKey = 'token',
  }) : super(key: key);

  @override
  State<HutCasLoginPage> createState() => _HutCasLoginPageState();
}

class _HutCasLoginPageState extends State<HutCasLoginPage> {
  final HutUserApi _api = HutUserApi();
  bool _isLoading = true;
  String _idToken = '';
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _getIdToken();
  }

  // 获取用于CAS登录的idToken
  Future<void> _getIdToken() async {
    try {
      _idToken = await _api.getToken();
      _api.checkTokenValidity().then((isValid) async {
        if (!isValid) {
          await _api.refreshToken();
          _idToken = await _api.getToken();
        }
      });
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

  // 保存获取到的新token
  Future<void> _saveToken(String token) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(widget.tokenKey, token);

      if (widget.onLoginComplete != null) {
        widget.onLoginComplete!(token);
      }

      if (widget.popOnSuccess && mounted) {
        Navigator.of(context).pop(token);
      }
    } catch (e) {
      if (mounted) {
        // ScaffoldMessenger.of(context).showSnackBar(
        //   SnackBar(content: Text('保存token失败: $e'), backgroundColor: Colors.red),
        // );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Scaffold(
        appBar: AppBar(title: const Text('HUT统一认证')),
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
      return Scaffold(
        appBar: AppBar(title: const Text('HUT统一认证')),
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.error_outline, color: Colors.red, size: 48),
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
      onTokenExtracted: _saveToken,
      onError: (errorMessage) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(errorMessage), backgroundColor: Colors.red),
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
            builder: (context) => const HutCasLoginPage(tokenKey: 'token'),
          ),
        );

        if (result != null) {
          // 使用获取到的token
          print('获取到的教务系统Token: $result');
        }
      },
      child: const Text('登录教务系统'),
    );
  }
}

// 另一种使用方式 - 获取token不返回
class HutCasTokenRetriever {
  static Future<String?> getJwxtToken(BuildContext context) async {
    // 先检查是否有缓存的token
    final prefs = await SharedPreferences.getInstance();
    final cachedToken = prefs.getString('token') ?? '';
    print('开始');
    if (cachedToken.isNotEmpty) {
      // 使用token.dart中的checkTokenValid方法验证token有效性
      bool isTokenValid = await checkTokenValid();
      print(isTokenValid);
      if (isTokenValid) {
        return cachedToken;
      }
      // Token无效，需要重新登录
    }
    print('流程');
    // 如果没有缓存或缓存无效，进行登录流程
    final completer = Completer<String?>();

    Navigator.of(context)
        .push(
          MaterialPageRoute(
            builder:
                (context) => HutCasLoginPage(
                  popOnSuccess: true,
                  onLoginComplete: (token) {
                    completer.complete(token);
                  },
                ),
          ),
        )
        .then((value) {
          // 如果用户取消或返回，且completer尚未完成，则完成completer为null
          if (!completer.isCompleted) {
            completer.complete(value as String?);
          }
        });

    return completer.future;
  }
}
