import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:google_nav_bar/google_nav_bar.dart';
import 'package:ionicons/ionicons.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:superhut/command/token.dart';
import 'package:superhut/home/coursetable/view.dart';

import '../../login/webview_login_screen.dart';
import 'logic.dart';

class HomeviewPage extends StatefulWidget {
  const HomeviewPage({super.key});

  @override
  _HomeviewPageState createState() => _HomeviewPageState();
}

class _HomeviewPageState extends State<HomeviewPage>
    with AutomaticKeepAliveClientMixin {
  @override
  Widget build(BuildContext context) {
    super.build(context);
    final HomeviewLogic logic = Get.put(HomeviewLogic());
    return Scaffold(
      body: SafeArea(
        bottom: true,
        child: PageView(
          physics: NeverScrollableScrollPhysics(),
          controller: logic.homePageController,
          children: [
            CourseTableView(),
            Container(
              child: Center(
                child: ElevatedButton(onPressed: () async {
                  renewToken(context);

                }, child: Text("2222")),
              ),
            ),
            Container(child: Center(child: Text("我"))),
          ],
        ),
      ),
      bottomSheet: Padding(
        padding: EdgeInsets.all(0),
        child: GNav(
          gap: 8,
          color: Theme.of(context).hintColor,
          activeColor: Theme.of(context).primaryColor,
          iconSize: 24,
          tabBackgroundColor: Colors.purple.withOpacity(0.1),
          padding: EdgeInsets.symmetric(horizontal: 20, vertical: 14),
          duration: Duration(milliseconds: 200),
          tabs: [
            GButton(icon: Ionicons.calendar_outline, text: '课表'),
            GButton(icon: Ionicons.apps_outline, text: '功能'),
            GButton(icon: Ionicons.person_outline, text: '我'),
          ],
          onTabChange: (index) {
            logic.homePageController.animateToPage(
              index,
              duration: Duration(milliseconds: 200),
              curve: Curves.easeInOut,
            );
          },
        ),
      ),
    );
  }

  @override
  // TODO: implement wantKeepAlive
  bool get wantKeepAlive => true;
}
