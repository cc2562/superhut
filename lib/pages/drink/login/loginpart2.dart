import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:superhut/pages/drink/login/command.dart';

import '../../../generated/assets.dart';
import '../api/drink_api.dart';

class DrinkLoginPage2 extends StatefulWidget {
  final String phoneNumber;
  final String doubleRandom;
  final String timestamp;
  final String imageCode;

  const DrinkLoginPage2({
    super.key,
    required this.phoneNumber,
    required this.doubleRandom,
    required this.timestamp,
    required this.imageCode,
  });

  @override
  _DrinkLoginPage2State createState() => _DrinkLoginPage2State();
}

class _DrinkLoginPage2State extends State<DrinkLoginPage2> {
  final TextEditingController _userNoController = TextEditingController();

  var api = DrinkApi();

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
                    "最后一步~",
                    style: TextStyle(
                      fontSize: 35,
                      fontWeight: FontWeight.bold,
                      color: Theme.of(context).primaryColor,
                    ),
                  ),
                  Text(
                    "验证码已发送至 ${widget.phoneNumber}",
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
                                "请输入验证码",
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
                                    hintText: "验证码",
                                    border: InputBorder.none,
                                    counterText: '',
                                  ),
                                  controller: _userNoController,
                                ),
                              ),
                              SizedBox(height: 10),
                              const SizedBox(height: 20),
                              Flex(
                                direction: Axis.horizontal,
                                children: [
                                  Expanded(
                                    child: FilledButton(
                                      onPressed: () {
                                        if (_userNoController.text.isEmpty) {
                                          ScaffoldMessenger.of(
                                            context,
                                          ).showSnackBar(
                                            const SnackBar(
                                              content: Text('验证码不能为空'),
                                            ),
                                          );
                                          return;
                                        }
                                        Login(
                                          widget.phoneNumber,
                                          _userNoController.text,
                                          context,
                                        );
                                      },
                                      child: const Text('登录'),
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
