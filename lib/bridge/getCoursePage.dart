import 'package:flutter/material.dart';
import 'package:loading_animation_widget/loading_animation_widget.dart';
import 'package:restart_app/restart_app.dart';
import 'package:superhut/home/homeview/view.dart';

import '../utils/course/coursemain.dart';
import '../utils/token.dart';

class Getcoursepage extends StatefulWidget {
  final bool renew;

  const Getcoursepage({super.key, required this.renew});

  @override
  State<Getcoursepage> createState() => _GetcoursepageState();
}

class _GetcoursepageState extends State<Getcoursepage> {
  @override
  void initState() {
    super.initState();
    loadClass();
  }

  Future<void> loadClass() async {
    String token = await getToken();
    String re = await saveClassToLocal(token, context);

    if (re == '200' && widget.renew == false) {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (context) => HomeviewPage()),
      );
    } else {
      Restart.restartApp(
        /// In Web Platform, Fill webOrigin only when your new origin is different than the app's origin
        // webOrigin: 'http://example.com',

        // Customizing the restart notification message (only needed on iOS)
        notificationTitle: '正在重启应用',
        notificationBody: '请点击这条通知重启',
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SizedBox(
        width: double.infinity,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            LoadingAnimationWidget.inkDrop(
              color: Theme.of(context).primaryColor,
              size: 40,
            ),
            SizedBox(height: 16),
            Text('正在加载课表'),
            Text('只有第一次使用需要加载课表'),
          ],
        ),
      ),
    );
  }
}
