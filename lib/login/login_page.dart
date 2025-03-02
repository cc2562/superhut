import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../generated/assets.dart';
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
              padding: EdgeInsets.only(top:200,right: 20,left: 20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text("欢迎~",
                    style: TextStyle(
                        fontSize: 35,
                        fontWeight: FontWeight.bold,
                        color: Theme.of(context).primaryColor
                    ),
                  ),
                  Text("与HUT签订契约吧",
                    style: TextStyle(
                       // fontSize: 35,
                        fontWeight: FontWeight.bold,
                        color: Theme.of(context).primaryColor
                    ),
                  ),
                ],
              ),
            ),
            MediaQuery.removePadding(context: context,
                removeTop: true,
                child:   ListView(
                  children: [
                    Container(
                      margin: EdgeInsets.only(top: 200,),
                      child: Stack(
                        children: [
                          Container(
                            decoration: BoxDecoration(
                              color: Theme.of(context).cardColor,
                              borderRadius: BorderRadius.only(topLeft:Radius.circular(20),topRight: Radius.circular(20)),
                            ),
                            margin: EdgeInsets.only(top: 100,),
                            padding: EdgeInsets.only(top: 40,right: 20,left: 20),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text("登录",
                                  style: TextStyle(
                                      fontSize: 30,
                                      fontWeight: FontWeight.bold,
                                      color: Theme.of(context).primaryColor
                                  ),
                                ),
                                SizedBox(height: 10,),
                                Container(
                                  width: 400,
                                  padding: EdgeInsets.fromLTRB(10, 0, 10, 0),
                                  //      margin: EdgeInsets.only(left: 5,right: 5),
                                  decoration: BoxDecoration(
                                    borderRadius: BorderRadius.circular(15),
                                    color:Theme.of(context).highlightColor,
                                  ),
                                  child:  TextField(
                                    keyboardType: TextInputType.number,
                                    style: TextStyle(
                                        fontSize: 18
                                    ),
                                    maxLength: 13,
                                    decoration: InputDecoration(
                                      filled: false,
                                      hintText: "账号",
                                      border: InputBorder.none,
                                      counterText: '',
                                    ),
                                    controller: _userNoController,
                                  ),
                                ),
                                SizedBox(height: 10,),
                                Container(
                                  width: 400,
                                  padding: EdgeInsets.fromLTRB(10, 0, 10, 0),
                                  //      margin: EdgeInsets.only(left: 5,right: 5),
                                  decoration: BoxDecoration(
                                    borderRadius: BorderRadius.circular(15),
                                    color:Theme.of(context).highlightColor,
                                  ),
                                  child:   TextField(
                                    style: TextStyle(
                                        fontSize: 18
                                    ),
                                    maxLength: 40,
                                    decoration: InputDecoration(
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
                                Flex(direction: Axis.horizontal,children: [
                                  Expanded(
                                    child: FilledButton(
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
                                                  renew: false,
                                            ),
                                          ),
                                        );
                                      },
                                      child: const Text('登录'),
                                    ),
                                  )
                                ],)
                              ],
                            ),
                          ),
                          Container(
                            padding: EdgeInsets.only(right: 20),
                            alignment: Alignment.topRight,
                            margin: EdgeInsets.only(top: 0),
                            child: SvgPicture.asset(Assets.illustrationLogin,width: 150,),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
            )


          ],
        ),
      ),
    );
  }
}
