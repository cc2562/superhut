import 'package:flutter/material.dart';
import 'package:superhut/login/hut_cas_login_page.dart';
import 'package:shared_preferences/shared_preferences.dart';

class HutLoginExample extends StatefulWidget {
  const HutLoginExample({Key? key}) : super(key: key);

  @override
  State<HutLoginExample> createState() => _HutLoginExampleState();
}

class _HutLoginExampleState extends State<HutLoginExample> {
  String? _token;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _checkExistingToken();
  }

  Future<void> _checkExistingToken() async {
    setState(() {
      _isLoading = true;
    });

    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('token');
    
    setState(() {
      _token = token;
      _isLoading = false;
    });
  }

  Future<void> _loginWithCAS() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final token = await HutCasTokenRetriever.getJwxtToken(context);
      
      setState(() {
        _token = token;
        _isLoading = false;
      });
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('登录失败：$e'), backgroundColor: Colors.red),
      );
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _clearToken() async {
    setState(() {
      _isLoading = true;
    });

    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('token');
    
    setState(() {
      _token = null;
      _isLoading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('教务系统登录示例'),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Center(
              child: Padding(
                padding: const EdgeInsets.all(20.0),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    if (_token != null) ...[
                      const Icon(
                        Icons.check_circle_outline,
                        color: Colors.green,
                        size: 64,
                      ),
                      const SizedBox(height: 16),
                      const Text(
                        '已登录教务系统',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Token: ${_token!.length > 20 ? '${_token!.substring(0, 20)}...' : _token}',
                        style: const TextStyle(fontSize: 14),
                      ),
                      const SizedBox(height: 24),
                      ElevatedButton(
                        onPressed: _clearToken,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.red,
                          foregroundColor: Colors.white,
                        ),
                        child: const Text('退出登录'),
                      ),
                    ] else ...[
                      const Icon(
                        Icons.account_circle_outlined,
                        color: Colors.orange,
                        size: 64,
                      ),
                      const SizedBox(height: 16),
                      const Text(
                        '未登录教务系统',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 24),
                      ElevatedButton(
                        onPressed: _loginWithCAS,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.blue,
                          foregroundColor: Colors.white,
                        ),
                        child: const Text('登录教务系统'),
                      ),
                    ],
                  ],
                ),
              ),
            ),
    );
  }
}

// 示例：如何在其他页面中获取并使用教务系统token
class JwxtApiExample {
  static Future<Map<String, dynamic>> getCourseData(BuildContext context) async {
    // 先获取token（如果未登录，会自动跳转到登录页面）
    final token = await HutCasTokenRetriever.getJwxtToken(context);
    
    if (token == null) {
      // 用户取消了登录
      return {'success': false, 'message': '未能获取到登录凭证'};
    }
    
    // 使用token调用教务系统API
    // 这里只是示例，实际实现需要根据具体API进行调整
    try {
      // 这里应该是实际的API调用代码
      // final response = await dio.get('https://jwxtsj.hut.edu.cn/api/...',
      //   options: Options(headers: {'Authorization': 'Bearer $token'}));
      
      // 模拟API结果
      return {
        'success': true,
        'data': {
          'courses': [
            {'name': '高等数学', 'teacher': '张教授', 'time': '周一 1-2节'},
            {'name': '大学物理', 'teacher': '李教授', 'time': '周二 3-4节'},
          ]
        }
      };
    } catch (e) {
      return {'success': false, 'message': '获取课程数据失败：$e'};
    }
  }
}
