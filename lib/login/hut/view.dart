import 'package:enhanced_future_builder/enhanced_future_builder.dart';
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:superhut/login/loginwithpost.dart';


import '../../../generated/assets.dart';
import '../../utils/hut_user_api.dart';
import 'command.dart';




class HutLoginPage extends StatefulWidget {
  const HutLoginPage({super.key});

  @override
  _HutLoginPageState createState() => _HutLoginPageState();
}

class _HutLoginPageState extends State<HutLoginPage> {
  final TextEditingController _userNoController = TextEditingController();
  final TextEditingController _pwdController = TextEditingController();
  var api = HutUserApi();
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
                              Container(
                                width: 400,
                                padding: EdgeInsets.fromLTRB(10, 0, 10, 0),
                                //      margin: EdgeInsets.only(left: 5,right: 5),
                                decoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(15),
                                  color: Theme.of(context).highlightColor,
                                ),
                                child: TextField(
                                  keyboardType: TextInputType.number,
                                  style: TextStyle(fontSize: 18),
                                  maxLength: 13,
                                  decoration: InputDecoration(
                                    filled: false,
                                    hintText: "学号/手机号",
                                    border: InputBorder.none,
                                    counterText: '',
                                  ),
                                  controller: _userNoController,
                                ),
                              ),
                              SizedBox(height: 10),
                              Container(
                                width: 400,
                                padding: EdgeInsets.fromLTRB(10, 0, 10, 0),
                                //      margin: EdgeInsets.only(left: 5,right: 5),
                                decoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(15),
                                  color: Theme.of(context).highlightColor,
                                ),
                                child: Flex(
                                  direction: Axis.horizontal,
                                  children: [
                                    Expanded(child: TextField(
                                      style: TextStyle(fontSize: 18),
                                      maxLength: 40,
                                      decoration: InputDecoration(
                                        filled: false,
                                        hintText: "密码",
                                        border: InputBorder.none,
                                        counterText: '',
                                      ),
                                      controller: _pwdController,
                                      obscureText: false,
                                    ),),

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
                                            const SnackBar(
                                              content: Text('学号或密码不能为空'),
                                            ),
                                          );
                                          return;
                                        }
                                        //SendMessageCode(context, _userNoController.text, _pwdController.text);
                                        loginToHuT(_userNoController.text, _pwdController.text,context);

                                      },
                                      child: const Text('下一步'),
                                    ),
                                  ),
                                ],
                              ),
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
}
