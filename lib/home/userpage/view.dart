import 'package:flutter/material.dart';
import 'package:ionicons/ionicons.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:superhut/welcomepage/view.dart';

import '../../bridge/getCoursePage.dart';
import '../../command/token.dart';
import '../../pages/score/scorepage.dart';

class UserPage extends StatefulWidget {
  const UserPage({super.key});

  @override
  State<UserPage> createState() => _UserPageState();
}

class _UserPageState extends State<UserPage> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
        appBar: AppBar(
          title: Text("功能"),
        ),
        body:Padding(padding: EdgeInsets.only(right: 10,left: 10,top: 10),
          child: ListView(
            children: [
              Card.filled(
                  color: Theme.of(context).colorScheme.surfaceContainer,
                  child: Padding(padding: EdgeInsets.fromLTRB(20, 10, 20, 10),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text("我的信息",
                          style: TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                              color: Theme.of(context).primaryColor
                          ),
                        ),
                        SizedBox(height: 10,),
                        Flex(
                          direction: Axis.vertical,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text("好听的名字",style: TextStyle(
                                fontSize: 20,
                                fontWeight: FontWeight.bold,
                                color: Theme.of(context).primaryColor
                            ),),
                            Text("#学号",style: TextStyle(
                                fontSize: 15,
                                color: Theme.of(context).primaryColor
                            ),),
                          ],
                        ),
                        SizedBox(height: 10,),
                      ],
                    ),
                  )
              ),
              Container(
                padding: EdgeInsets.only(left: 10,right: 10),
                margin: EdgeInsets.all(10),
                child:Column(
                  children: [
                    ListTile(
                      leading: Icon(Ionicons.refresh_outline,color: Theme.of(context).primaryColor,),
                      trailing: Icon(Ionicons.chevron_forward_outline,color: Theme.of(context).primaryColor,),
                      style: ListTileStyle.drawer,
                      title: Text("刷新课表"),
                      onTap: () async {
                        await renewToken(context);
                        WidgetsBinding.instance.addPostFrameCallback((_) {
                          Navigator.of(
                            context,
                          ).pushReplacement(MaterialPageRoute(builder: (context) => Getcoursepage()));
                        });
                      },
                    ),
                    ListTile(
                      leading: Icon(Ionicons.log_out_outline,color: Theme.of(context).primaryColor,),
                      trailing: Icon(Ionicons.chevron_forward_outline,color: Theme.of(context).primaryColor,),
                      style: ListTileStyle.drawer,
                      title: Text("退出登录"),
                      onTap: () async {
                        final prefs = await SharedPreferences.getInstance();
                        prefs.setString('user', "");
                        prefs.setString('password', "");
                        await prefs.setBool('isFirstOpen', true);
                        WidgetsBinding.instance.addPostFrameCallback((_) {
                          Navigator.of(
                            context,
                          ).pushReplacement(MaterialPageRoute(builder: (context) => WelcomepagePage()));
                        });
                      },
                    ),
                    ListTile(
                      //leading: Icon(Ionicons.abou,color: Theme.of(context).primaryColor,),
                      trailing: Icon(Ionicons.chevron_forward_outline,color: Theme.of(context).primaryColor,),
                      style: ListTileStyle.drawer,
                      title: Text("关于软件"),
                      onTap: () async {

                      },
                    ),
                  ],
                ),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(10),
                  color: Theme.of(context).colorScheme.surfaceContainer,
                ),
              )
            ],
          ),
        )
    );
  }
}
