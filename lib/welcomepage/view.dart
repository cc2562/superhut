import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:introduction_screen/introduction_screen.dart';

import '../login/unified_login_page.dart';
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
        done: Text("签订契约"),
        onDone: () {
          Get.off(UnifiedLoginPage());
        },
        pages: [
          PageViewModel(
            title: "超级工大",
            body: "欢迎使用超级工大APP\n与工大签订契约吧~( ⓛ ω ⓛ *)",
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
            title: " 更多功能",
            body: "宿舍喝水、洗澡、看成绩、快速教评...你需要的这里都有",
            image: const Center(child: Icon(Icons.apps, size: 50.0)),
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
