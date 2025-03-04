import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:introduction_screen/introduction_screen.dart';

import '../login/login_page.dart';
import 'logic.dart';

class WelcomepagePage extends StatelessWidget {
  WelcomepagePage({super.key});

  final WelcomepageLogic logic = Get.put(WelcomepageLogic());

  @override
  Widget build(BuildContext context) {
    SystemChrome.setSystemUIOverlayStyle(
      const SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarBrightness: Brightness.light,
      ),
    );
    return Scaffold(
      body: IntroductionScreen(
        showNextButton: true,
        next: Text("下一步"),
        done: Text("登录教务系统"),
        onDone: () {
          Get.off(LoginPage());
        },
        pages: [
          PageViewModel(
            title: "湖工大小助手",
            body: "欢迎使用湖工大小助手，这个向导会帮助你完成最初的步骤",
            image: const Center(child: Icon(Icons.waving_hand, size: 50.0)),
            decoration: const PageDecoration(
              titleTextStyle: TextStyle(color: Colors.orange),
              bodyTextStyle: TextStyle(
                fontWeight: FontWeight.w700,
                fontSize: 20.0,
              ),
            ),
          ),
          PageViewModel(
            title: "查看课表",
            body: "通过小助手的课表功能，可以查看你的课表",
            image: const Center(child: Icon(Icons.calendar_month, size: 50.0)),
            decoration: const PageDecoration(
              titleTextStyle: TextStyle(color: Colors.orange),
              bodyTextStyle: TextStyle(
                fontWeight: FontWeight.w700,
                fontSize: 20.0,
              ),
            ),
          ),
          PageViewModel(
            title: "快速喝水",
            body: "通过小助手的喝水功能，可以快速喝水（还没有做好）",
            image: const Center(child: Icon(Icons.water_drop, size: 50.0)),
            decoration: const PageDecoration(
              titleTextStyle: TextStyle(color: Colors.orange),
              bodyTextStyle: TextStyle(
                fontWeight: FontWeight.w700,
                fontSize: 20.0,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
