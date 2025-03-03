import 'package:flutter/material.dart';
import 'package:superhut/command/course/coursemain.dart';
import 'package:superhut/command/token.dart';
import 'package:superhut/home/homeview/view.dart';

class Getcoursepage extends StatefulWidget {
  const Getcoursepage({super.key});

  @override
  State<Getcoursepage> createState() => _GetcoursepageState();
}

class _GetcoursepageState extends State<Getcoursepage> {
  @override
  void initState() {
    // TODO: implement initState
    super.initState();
    loadClass();
  }

  Future<void> loadClass() async {
    String token = await getToken();
    String re = await saveClassToLocal(token,context);
    if (re == '200') {
      Navigator.push(
        context,
        MaterialPageRoute(builder: (context) => HomeviewPage()),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        child: Center(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [CircularProgressIndicator(), Text('正在获取课表\n请稍候')],
          ),
        ),
      ),
    );
  }
}
