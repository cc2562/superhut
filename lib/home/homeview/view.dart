import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:google_nav_bar/google_nav_bar.dart';
import 'package:ionicons/ionicons.dart';
import 'package:superhut/home/Functionpage/view.dart';
import 'package:superhut/home/coursetable/view.dart';
import 'package:superhut/home/userpage/view.dart';

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
      //extendBodyBehindAppBar: true,
      body:PageView(
        physics: NeverScrollableScrollPhysics(),
        controller: logic.homePageController,
        children: [
          CourseTableView(),
          FunctionPage(),
          UserPage()
        ],
      ),
      bottomSheet: Container(
        color: Colors.transparent,
        margin: EdgeInsets.all(10),
        padding: EdgeInsets.only(left: 15,right: 15,bottom: 20,top: 10),
        child: GNav(

          gap: 10,
          color: Theme.of(context).primaryColorDark,
          activeColor: Theme.of(context).primaryColor,
          iconSize: 24,
          tabBackgroundColor:Theme.of(context).primaryColor.withAlpha(20),
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
  bool get wantKeepAlive => true;
}
