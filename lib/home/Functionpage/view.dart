import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:ionicons/ionicons.dart';

import '../../command/token.dart';
import '../../pages/score/scorepage.dart';

class FunctionPage extends StatefulWidget {
  const FunctionPage({super.key});

  @override
  State<FunctionPage> createState() => _FunctionPageState();
}

class _FunctionPageState extends State<FunctionPage> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
        extendBodyBehindAppBar: true,
      appBar: AppBar(

        title: Text("功能"),
      ),
      body:Container(
        padding: EdgeInsets.only(left: 10,right: 10,top: 10),
        color: Theme.of(context).colorScheme.surface,
        child: ListView(
          children: [
            Text("教务",
              style: TextStyle(
                  fontSize: 22,
                  color: Theme.of(context).primaryColor
              ),
            ),
            Container(
              padding: EdgeInsets.only(left: 10,right: 10),
              margin: EdgeInsets.all(10),
              child:Column(
                children: [
                  ListTile(
                    leading: Icon(Ionicons.reader_outline,color: Theme.of(context).primaryColor,),
                    trailing: Icon(Ionicons.chevron_forward_outline,color: Theme.of(context).primaryColor,),
                    style: ListTileStyle.drawer,
                    title: Text("成绩查询"),
                    onTap: () async {
                      await renewToken(context);
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder:
                              (context) =>ScorePage(),
                        ),
                      );
                    },
                  ),
                  ListTile(
                    leading: Icon(Ionicons.school_outline,color: Theme.of(context).primaryColor,),
                    trailing: Icon(Ionicons.chevron_forward_outline,color: Theme.of(context).primaryColor,),
                    style: ListTileStyle.drawer,
                    title: Text("考试查询（开发中）"),
                    onTap: () async {

                    },
                  ),
                  ListTile(
                    leading: Icon(Ionicons.home_outline,color: Theme.of(context).primaryColor,),
                    trailing: Icon(Ionicons.chevron_forward_outline,color: Theme.of(context).primaryColor,),
                    style: ListTileStyle.drawer,
                    title: Text("空教室查询（开发中）"),
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
