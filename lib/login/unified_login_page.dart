import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:superhut/bridge/getCoursePage.dart';
import 'package:superhut/generated/assets.dart';
import 'package:superhut/login/hut/command.dart';
import 'package:superhut/login/hut/sms_command.dart';
import 'package:superhut/login/hut_cas_login_page.dart';
import 'package:superhut/login/hut_sms_login_enabled.dart';
import 'package:superhut/login/webview_login_screen.dart';
import 'package:superhut/utils/hut_user_api.dart';

enum _UnifiedLoginMode { password, sms }

class UnifiedLoginPage extends StatefulWidget {
  const UnifiedLoginPage({Key? key}) : super(key: key);

  @override
  _UnifiedLoginPageState createState() => _UnifiedLoginPageState();
}

class _UnifiedLoginPageState extends State<UnifiedLoginPage>
    with SingleTickerProviderStateMixin {
  final TextEditingController _userNoController = TextEditingController();
  final TextEditingController _pwdController = TextEditingController();
  late TabController _tabController;
  bool _isLoading = false;
  final HutUserApi _api = HutUserApi();
  _UnifiedLoginMode _mode = _UnifiedLoginMode.password;
  final TextEditingController _mobileController = TextEditingController();
  final TextEditingController _smsCodeController = TextEditingController();
  final HutSmsLoginCommand _smsCommand = HutSmsLoginCommand();
  bool _mobilePrefillDone = false;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _loadSavedCredentials();
    _smsCommand.onCountdownChanged = () {
      if (mounted) {
        setState(() {});
      }
    };
    _prefillMobile();
  }

  @override
  void dispose() {
    _tabController.dispose();
    _userNoController.dispose();
    _pwdController.dispose();
    _mobileController.dispose();
    _smsCodeController.dispose();
    _smsCommand.onCountdownChanged = null;
    _smsCommand.dispose();
    super.dispose();
  }

  // 回填上次短信登录的手机号
  void _prefillMobile() async {
    final mobile = await readHutMobile();
    if (!mounted || mobile.isEmpty || _mobilePrefillDone) {
      return;
    }
    _mobilePrefillDone = true;
    if (_mobileController.text.isEmpty) {
      _mobileController.text = mobile;
    }
  }

  // 加载保存的账号密码
  Future<void> _loadSavedCredentials() async {
    final prefs = await SharedPreferences.getInstance();
    final savedUser = prefs.getString('user');
    if (savedUser != null && savedUser.isNotEmpty) {
      _userNoController.text = savedUser;

      // 密码通常不应自动填充，但这里根据应用需求处理
      final savedPassword = prefs.getString('password');
      if (savedPassword != null && savedPassword.isNotEmpty) {
        _pwdController.text = savedPassword;
      }
    }
  }

  // 教务系统直接登录
  void _loginWithCredentials() async {
    if (_userNoController.text.isEmpty || _pwdController.text.isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('请输入账号和密码')));
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      // 直接使用WebView登录教务系统
      Navigator.push(
        context,
        MaterialPageRoute(
          builder:
              (context) => WebViewLoginScreen(
                userNo: _userNoController.text,
                password: _pwdController.text,
                showText: '登录中',
                renew: false,
              ),
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('登录失败: $e')));
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  // 智慧工大平台登录
  void _loginWithCAS() async {
    if (_userNoController.text.isEmpty || _pwdController.text.isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('请输入账号和密码')));
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      // 使用LoginWithPost进行工大平台登录，内部会调用统一认证
      print('开始');
      await HutUserApi().userLogin(
        username: _userNoController.text,
        password: _pwdController.text,
      );
      print('获取Token');
      String? token = await HutCasTokenRetriever.getJwxtToken(context);
      if (token != null) {
        // 使用获取到的token
        print('获取到的教务系统Token: $token');
      }
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool('isFirstOpen', false);
      Navigator.of(context).pop();
      WidgetsBinding.instance.addPostFrameCallback((_) {
        Navigator.of(context).push(
          MaterialPageRoute(builder: (context) => Getcoursepage(renew: false)),
        );
      });
      // 登录成功后返回
      //Navigator.pop(context);
    } catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('登录失败: 也许是密码或账户不正确')));
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  // 使用统一认证CAS登录工大平台并获取Token
  void _loginWithHutPlatform() async {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const HutCasLoginPage()),
    );
  }

  // 发送短信验证码
  Future<void> _requestSmsCode() async {
    if (_isLoading) {
      return;
    }

    final mobile = _mobileController.text.trim();
    if (mobile.isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('请输入手机号')));
      return;
    }

    setState(() {
      _isLoading = true;
    });
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
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  // 短信验证码登录
  Future<void> _loginWithSms() async {
    if (_isLoading) {
      return;
    }

    final mobile = _mobileController.text.trim();
    final code = _smsCodeController.text.trim();
    if (mobile.isEmpty || code.isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('请输入手机号和验证码')));
      return;
    }

    setState(() {
      _isLoading = true;
    });
    try {
      final result = await _smsCommand.login(mobile: mobile, smscode: code);
      if (!mounted) {
        return;
      }
      if (!result.success) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(
          SnackBar(content: Text(result.message.isEmpty ? '登录失败' : result.message)),
        );
        return;
      }

      // 短信登录可能已切换账号，先清除上一个账号的教务系统会话，
      // 避免 getJwxtToken 命中仍有效的旧缓存并加载上一个账号的课表。
      await HutCasTokenRetriever.clearCachedSession();
      if (!mounted) {
        return;
      }

      // 与密码登录成功后的处理保持一致：先换取教务系统 token（写入 `token`
      // key，Getcoursepage 依赖它），再关闭登录页跳转课表。SMS 登录只写了
      // hutToken，若跳过这一步新 SMS 用户会拿到空 token 导致课表加载失败。
      // 仅在换取成功后才把 isFirstOpen 置 false 并跳转，失败则留在登录页让
      // 用户重试或改用密码登录，避免下次启动跳过登录流程。
      String? token = await HutCasTokenRetriever.getJwxtToken(context);
      if (!mounted) {
        return;
      }
      if (token == null || token.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('未获取到教务系统令牌，请重试或使用密码登录')),
        );
        return;
      }
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool('isFirstOpen', false);
      Navigator.of(context).pop();
      WidgetsBinding.instance.addPostFrameCallback((_) {
        Navigator.of(context).push(
          MaterialPageRoute(builder: (context) => Getcoursepage(renew: false)),
        );
      });
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  // 密码/验证码登录模式切换
  List<Widget> _buildModeSwitcher() {
    final isPassword = _mode == _UnifiedLoginMode.password;
    return [
      Row(
        children: [
          TextButton(
            onPressed:
                isPassword
                    ? null
                    : () => setState(() => _mode = _UnifiedLoginMode.password),
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
                    ? () => setState(() => _mode = _UnifiedLoginMode.sms)
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
      ),
      const SizedBox(height: 4),
    ];
  }

  // 账号/密码登录表单
  Column _buildPasswordFields() {
    return Column(
      children: [
        // 账号输入框
        Container(
          width: double.infinity,
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
              hintText: "手机号",
              border: InputBorder.none,
              counterText: '',
            ),
            controller: _userNoController,
          ),
        ),
        const SizedBox(height: 10),
        // 密码输入框
        Container(
          width: double.infinity,
          padding: const EdgeInsets.fromLTRB(10, 0, 10, 0),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(15),
            color: Theme.of(context).highlightColor,
          ),
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
            obscureText: true,
          ),
        ),
        const SizedBox(height: 20),
        Column(
          children: [
            FilledButton(
              onPressed: _loginWithCAS,
              style: FilledButton.styleFrom(
                backgroundColor: Colors.orangeAccent,
                minimumSize: const Size.fromHeight(48),
              ),
              child:
                  _isLoading
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            color: Colors.white,
                            strokeWidth: 2,
                          ),
                        )
                      : const Text('工大平台登录'),
            ),
          ],
        ),
      ],
    );
  }

  // 手机号/验证码登录表单
  Column _buildSmsFields() {
    final remaining = _smsCommand.remainingSeconds;
    final canRequest = remaining <= 0 && !_isLoading;

    return Column(
      children: [
        // 手机号输入框
        Container(
          width: double.infinity,
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
              hintText: "手机号",
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
        // 验证码输入框 + 获取按钮
        Container(
          width: double.infinity,
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
                    hintText: "验证码",
                    border: InputBorder.none,
                    counterText: '',
                  ),
                  controller: _smsCodeController,
                ),
              ),
              TextButton(
                onPressed:
                    canRequest ? () => _requestSmsCode() : null,
                child: Text(remaining > 0 ? '${remaining}s' : '获取验证码'),
              ),
            ],
          ),
        ),
        const SizedBox(height: 20),
        Column(
          children: [
            FilledButton(
              onPressed: _isLoading ? null : () => _loginWithSms(),
              style: FilledButton.styleFrom(
                backgroundColor: Colors.orangeAccent,
                minimumSize: const Size.fromHeight(48),
              ),
              child:
                  _isLoading
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            color: Colors.white,
                            strokeWidth: 2,
                          ),
                        )
                      : const Text('验证码登录'),
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
      body: Stack(
        children: [
          // 顶部背景
          Container(
            width: double.infinity,
            height: 400,
            color: Theme.of(context).secondaryHeaderColor,
            padding: const EdgeInsets.only(top: 200, right: 20, left: 20),
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
                  "选择登录方式",
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: Theme.of(context).primaryColor,
                  ),
                ),
              ],
            ),
          ),

          // 主内容
          MediaQuery.removePadding(
            context: context,
            removeTop: true,
            child: ListView(
              children: [
                Container(
                  margin: const EdgeInsets.only(top: 200),
                  child: Stack(
                    children: [
                      // 登录卡片
                      Container(
                        decoration: BoxDecoration(
                          color: Theme.of(context).cardColor,
                          borderRadius: const BorderRadius.only(
                            topLeft: Radius.circular(20),
                            topRight: Radius.circular(20),
                          ),
                        ),
                        margin: const EdgeInsets.only(top: 100),
                        padding: const EdgeInsets.only(
                          top: 40,
                          right: 20,
                          left: 20,
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // 标题
                            Text(
                              "登录",
                              style: TextStyle(
                                fontSize: 30,
                                fontWeight: FontWeight.bold,
                                color: Theme.of(context).primaryColor,
                              ),
                            ),
                            const SizedBox(height: 20),

                            if (kHutSmsLoginEnabled) ..._buildModeSwitcher(),

                            if (_mode == _UnifiedLoginMode.password)
                              _buildPasswordFields()
                            else
                              _buildSmsFields(),
                            const SizedBox(height: 20),
                            Text(
                              '请使用智慧工大账号进行登录',
                              style: TextStyle(color: Colors.grey),
                            ),
                          ],
                        ),
                      ),

                      // 右上角装饰图标
                      Container(
                        padding: const EdgeInsets.only(right: 20),
                        alignment: Alignment.topRight,
                        margin: const EdgeInsets.only(top: 0),
                        child: SvgPicture.asset(
                          Assets.illustration.login.path,
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
    );
  }
}
