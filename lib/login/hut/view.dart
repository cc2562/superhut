import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../../../generated/assets.dart';
import '../../utils/hut_user_api.dart';
import '../hut_cas_login_page.dart';
import '../hut_sms_login_enabled.dart';
import 'command.dart';
import 'sms_command.dart';

enum _HutLoginMode { password, sms }

class HutLoginPage extends StatefulWidget {
  const HutLoginPage({super.key});

  @override
  _HutLoginPageState createState() => _HutLoginPageState();
}

class _HutLoginPageState extends State<HutLoginPage> {
  final TextEditingController _userNoController = TextEditingController();
  final TextEditingController _pwdController = TextEditingController();
  final TextEditingController _mobileController = TextEditingController();
  final TextEditingController _smsCodeController = TextEditingController();
  var api = HutUserApi();

  _HutLoginMode _mode = _HutLoginMode.password;
  final HutSmsLoginCommand _smsCommand = HutSmsLoginCommand();
  bool _smsBusy = false;
  bool _mobilePrefillDone = false;

  @override
  void initState() {
    super.initState();
    _smsCommand.onCountdownChanged = () {
      if (mounted) {
        setState(() {});
      }
    };
    unawaited(_prefillMobile());
  }

  @override
  void dispose() {
    _userNoController.dispose();
    _pwdController.dispose();
    _mobileController.dispose();
    _smsCodeController.dispose();
    _smsCommand.onCountdownChanged = null;
    _smsCommand.dispose();
    super.dispose();
  }

  Future<void> _prefillMobile() async {
    final mobile = await readHutMobile();
    if (!mounted || mobile.isEmpty || _mobilePrefillDone) {
      return;
    }
    _mobilePrefillDone = true;
    if (_mobileController.text.isEmpty) {
      _mobileController.text = mobile;
    }
  }

  Future<void> _requestSmsCode() async {
    final mobile = _mobileController.text.trim();
    if (mobile.isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('请输入手机号')));
      return;
    }

    setState(() => _smsBusy = true);
    try {
      final result = await _smsCommand.requestCode(mobile);
      if (!mounted) {
        return;
      }
      if (result.success) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(
          SnackBar(content: Text(result.message.isEmpty ? '验证码已发送' : result.message)),
        );
      } else {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(
          SnackBar(content: Text(result.message.isEmpty ? '获取验证码失败' : result.message)),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _smsBusy = false);
      }
    }
  }

  Future<void> _loginWithSms() async {
    final mobile = _mobileController.text.trim();
    final code = _smsCodeController.text.trim();
    if (mobile.isEmpty || code.isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('请输入手机号和验证码')));
      return;
    }

    setState(() => _smsBusy = true);
    try {
      final result = await _smsCommand.login(mobile: mobile, smscode: code);
      if (!mounted) {
        return;
      }
      if (result.success) {
        // A successful SMS login may switch HUT accounts. Do not let the new
        // account reuse the previous account's academic-system credentials.
        await HutCasTokenRetriever.clearCachedSession();
        if (!mounted) {
          return;
        }
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('登录成功')));
        Navigator.pop(context);
      } else {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(
          SnackBar(content: Text(result.message.isEmpty ? '登录失败' : result.message)),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _smsBusy = false);
      }
    }
  }

  Widget _buildModeSwitcher() {
    if (!kHutSmsLoginEnabled) {
      return const SizedBox.shrink();
    }

    final isPassword = _mode == _HutLoginMode.password;
    return Row(
      children: [
        TextButton(
          onPressed:
              isPassword
                  ? null
                  : () => setState(() => _mode = _HutLoginMode.password),
          child: Text(
            '密码登录',
            style: TextStyle(
              fontWeight: isPassword ? FontWeight.bold : FontWeight.normal,
              color:
                  isPassword
                      ? Theme.of(context).primaryColor
                      : Theme.of(context).hintColor,
            ),
          ),
        ),
        TextButton(
          onPressed:
              isPassword
                  ? () => setState(() => _mode = _HutLoginMode.sms)
                  : null,
          child: Text(
            '验证码登录',
            style: TextStyle(
              fontWeight: !isPassword ? FontWeight.bold : FontWeight.normal,
              color:
                  !isPassword
                      ? Theme.of(context).primaryColor
                      : Theme.of(context).hintColor,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildSmsForm() {
    final remaining = _smsCommand.remainingSeconds;
    final canRequest = remaining <= 0 && !_smsBusy;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 400,
          padding: const EdgeInsets.fromLTRB(10, 0, 10, 0),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(15),
            color: Theme.of(context).highlightColor,
          ),
          child: TextField(
            keyboardType: TextInputType.phone,
            style: const TextStyle(fontSize: 18),
            maxLength: 13,
            decoration: const InputDecoration(
              filled: false,
              hintText: '手机号',
              border: InputBorder.none,
              counterText: '',
            ),
            controller: _mobileController,
            onChanged: (_) {
              _mobilePrefillDone = true;
            },
          ),
        ),
        const SizedBox(height: 10),
        Container(
          width: 400,
          padding: const EdgeInsets.fromLTRB(10, 0, 10, 0),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(15),
            color: Theme.of(context).highlightColor,
          ),
          child: Row(
            children: [
              Expanded(
                child: TextField(
                  keyboardType: TextInputType.number,
                  style: const TextStyle(fontSize: 18),
                  maxLength: 8,
                  decoration: const InputDecoration(
                    filled: false,
                    hintText: '验证码',
                    border: InputBorder.none,
                    counterText: '',
                  ),
                  controller: _smsCodeController,
                ),
              ),
              TextButton(
                onPressed:
                    canRequest ? () => unawaited(_requestSmsCode()) : null,
                child: Text(remaining > 0 ? '${remaining}s' : '获取验证码'),
              ),
            ],
          ),
        ),
        const SizedBox(height: 20),
        Flex(
          direction: Axis.horizontal,
          children: [
            Expanded(
              child: FilledButton(
                onPressed: _smsBusy ? null : () => unawaited(_loginWithSms()),
                child: const Text('下一步'),
              ),
            ),
          ],
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).cardColor,
      resizeToAvoidBottomInset: true,
      body: Padding(
        padding: const EdgeInsets.all(0),
        child: Stack(
          children: [
            Container(
              width: 1000,
              height: 400,
              color: Theme.of(context).secondaryHeaderColor,
              padding: EdgeInsets.only(top: 200, right: 20, left: 20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    "欢迎~",
                    style: TextStyle(
                      fontSize: 35,
                      fontWeight: FontWeight.bold,
                      color: Theme.of(context).primaryColor,
                    ),
                  ),
                  Text(
                    "登录智慧工大账号~",
                    style: TextStyle(
                      // fontSize: 35,
                      fontWeight: FontWeight.bold,
                      color: Theme.of(context).primaryColor,
                    ),
                  ),
                ],
              ),
            ),
            MediaQuery.removePadding(
              context: context,
              removeTop: true,
              child: ListView(
                children: [
                  Container(
                    margin: EdgeInsets.only(top: 200),
                    child: Stack(
                      children: [
                        Container(
                          decoration: BoxDecoration(
                            color: Theme.of(context).cardColor,
                            borderRadius: BorderRadius.only(
                              topLeft: Radius.circular(20),
                              topRight: Radius.circular(20),
                            ),
                          ),
                          margin: EdgeInsets.only(top: 100),
                          padding: EdgeInsets.only(
                            top: 40,
                            right: 20,
                            left: 20,
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                "登录",
                                style: TextStyle(
                                  fontSize: 30,
                                  fontWeight: FontWeight.bold,
                                  color: Theme.of(context).primaryColor,
                                ),
                              ),
                              SizedBox(height: 10),
                              _buildModeSwitcher(),
                              if (_mode == _HutLoginMode.password)
                                _buildPasswordForm()
                              else
                                _buildSmsForm(),
                            ],
                          ),
                        ),
                        Container(
                          padding: EdgeInsets.only(right: 20),
                          alignment: Alignment.topRight,
                          margin: EdgeInsets.only(top: 0),
                          child: SvgPicture.asset(
                            Assets.illustrationLogin,
                            width: 150,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPasswordForm() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 400,
          padding: const EdgeInsets.fromLTRB(10, 0, 10, 0),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(15),
            color: Theme.of(context).highlightColor,
          ),
          child: TextField(
            keyboardType: TextInputType.number,
            style: const TextStyle(fontSize: 18),
            maxLength: 13,
            decoration: const InputDecoration(
              filled: false,
              hintText: "学号/手机号",
              border: InputBorder.none,
              counterText: '',
            ),
            controller: _userNoController,
          ),
        ),
        const SizedBox(height: 10),
        Container(
          width: 400,
          padding: const EdgeInsets.fromLTRB(10, 0, 10, 0),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(15),
            color: Theme.of(context).highlightColor,
          ),
          child: Flex(
            direction: Axis.horizontal,
            children: [
              Expanded(
                child: TextField(
                  style: const TextStyle(fontSize: 18),
                  maxLength: 40,
                  decoration: const InputDecoration(
                    filled: false,
                    hintText: "密码",
                    border: InputBorder.none,
                    counterText: '',
                  ),
                  controller: _pwdController,
                  obscureText: false,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 20),
        Flex(
          direction: Axis.horizontal,
          children: [
            Expanded(
              child: FilledButton(
                onPressed: () {
                  if (_userNoController.text.isEmpty ||
                      _pwdController.text.isEmpty) {
                    ScaffoldMessenger.of(
                      context,
                    ).showSnackBar(
                      const SnackBar(content: Text('学号或密码不能为空')),
                    );
                    return;
                  }
                  loginToHuT(
                    _userNoController.text,
                    _pwdController.text,
                    context,
                  );
                },
                child: const Text('下一步'),
              ),
            ),
          ],
        ),
      ],
    );
  }
}
