import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:superhut/bridge/getCoursePage.dart';
import 'package:superhut/generated/assets.dart';
import 'package:superhut/login/hut_cas_login_page.dart';
import 'package:superhut/login/webview_login_screen.dart';
import 'package:superhut/utils/hut_user_api.dart';

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

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _loadSavedCredentials();
  }

  @override
  void dispose() {
    _tabController.dispose();
    _userNoController.dispose();
    _pwdController.dispose();
    super.dispose();
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

                            Column(
                              children: [
                                // 账号输入框
                                Container(
                                  width: double.infinity,
                                  padding: const EdgeInsets.fromLTRB(
                                    10,
                                    0,
                                    10,
                                    0,
                                  ),
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
                                  padding: const EdgeInsets.fromLTRB(
                                    10,
                                    0,
                                    10,
                                    0,
                                  ),
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

                                // 登录按钮
                                Row(
                                  children: [
                                    /*
                                    Expanded(
                                      child: FilledButton(
                                        onPressed: _loginWithCredentials,
                                        child: const Text('教务系统登录'),
                                      ),
                                    ),
                                    const SizedBox(width: 10),


                                     */
                                    Expanded(
                                      child: FilledButton(
                                        onPressed: _loginWithCAS,
                                        style: FilledButton.styleFrom(
                                          backgroundColor: Colors.orangeAccent,
                                        ),
                                        child:
                                            _isLoading
                                                ? const SizedBox(
                                                  width: 20,
                                                  height: 20,
                                                  child:
                                                      CircularProgressIndicator(
                                                        color: Colors.white,
                                                        strokeWidth: 2,
                                                      ),
                                                )
                                                : const Text('工大平台登录'),
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
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
    );
  }
}
