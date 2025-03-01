import 'package:flutter/material.dart';

import 'webview_login_screen.dart';

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  _LoginPageState createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final TextEditingController _userNoController = TextEditingController();
  final TextEditingController _pwdController = TextEditingController();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('登录')),
      body: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          children: [
            TextField(
              controller: _userNoController,
              decoration: const InputDecoration(labelText: '账号'),
            ),
            TextField(
              controller: _pwdController,
              obscureText: true,
              decoration: const InputDecoration(labelText: '密码'),
            ),
            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: () {
                if (_userNoController.text.isEmpty ||
                    _pwdController.text.isEmpty) {
                  ScaffoldMessenger.of(
                    context,
                  ).showSnackBar(const SnackBar(content: Text('账号或密码不能为空')));
                  return;
                }
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder:
                        (context) => WebViewLoginScreen(
                          userNo: _userNoController.text,
                          password: _pwdController.text,
                          showText: "正在登录...",
                        ),
                  ),
                );
              },
              child: const Text('登录'),
            ),
          ],
        ),
      ),
    );
  }
}
