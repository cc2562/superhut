import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:google_nav_bar/google_nav_bar.dart';
import 'package:ionicons/ionicons.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:superhut/home/Functionpage/view.dart';
import 'package:superhut/home/coursetable/view.dart';
import 'package:superhut/home/userpage/view.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../pages/Electricitybill/electricityApi.dart';
import '../../pages/Electricitybill/electricityPage.dart';
import 'logic.dart';

class HomeviewPage extends StatefulWidget {
  const HomeviewPage({super.key});

  @override
  _HomeviewPageState createState() => _HomeviewPageState();
}

class _HomeviewPageState extends State<HomeviewPage>
    with AutomaticKeepAliveClientMixin {
  bool _isUpdateAvailable = false;
  String _latestVersion = '';
  String _updateDescription = '';
  bool _isForcedUpdate = false;
  String _downloadUrl = '';
  String _currentVersion = '0.0.1'; // 默认版本号

  @override
  void initState() {
    super.initState();
    _getCurrentVersion().then((_) {
      _checkVersion();
    });
    checkAlert();
  }

  Future<void> _getCurrentVersion() async {
    PackageInfo packageInfo = await PackageInfo.fromPlatform();
    setState(() {
      _currentVersion = packageInfo.version;
    });
  }

  void checkAlert() async {
    var electricityApi = ElectricityApi();
    final prefs = await SharedPreferences.getInstance();
    bool isEnable = prefs.getBool('enableBillWarning')??false;
    if(isEnable==false){
      return;
    }
    String checkRoomId = prefs.getString('enableRoomId')??'';
    //获取电费
    await electricityApi.onInit();
    await electricityApi.getHistory();
    var nowRoomInfo = await electricityApi.getSingleRoomInfo(checkRoomId);
    var roomCount = nowRoomInfo["eleTail"];
    var setRoomName = nowRoomInfo["roomName"];
    double bill = prefs.getDouble('enableBill')??0;
    if(double.parse(roomCount)>=bill){
      print("无风险");

    }else{
      print("有风险");
      _showAlert('当前电费：${roomCount}元\n设置电费：${bill}元\n房间：${setRoomName}');
    }
    print(
        '当前电费：${roomCount}元\n设置电费：${bill}元\n房间：${setRoomName}\n\n'
    );
  }

  void _showAlert(String showDescription) {
    showDialog(
      context: context,
      barrierDismissible: true,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text('电费达到预警值'),
          content: Text(showDescription),
          actions: <Widget>[
              TextButton(
                child: Text('我知道了'),
                onPressed: () {
                  Navigator.of(context).pop();
                },
              ),
            TextButton(
              child: Text('立即充值'),
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => ElectricityPage()),
                );
              },
            ),
          ],
        );
      },
    );
  }
  Future<void> _checkVersion() async {
    print("DO");
    final dio = Dio();
    final response = await dio.get('https://super.ccrice.com/api/check_version.php?version=$_currentVersion');
    print(_currentVersion);
    print(response.data);
    final Map<String, dynamic> data = response.data;
    setState(() {
      _isUpdateAvailable = !data['is_latest'];
      _latestVersion = data['latest_version'];
      _updateDescription = data['description'];
      _isForcedUpdate = data['is_forced'];
      _downloadUrl = data['download_url'];
    });

    if (_isUpdateAvailable) {
      _showUpdateDialog();
    }
  }

  void _showUpdateDialog() {
    showDialog(
      context: context,
      barrierDismissible: !_isForcedUpdate,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text('新版本可用: $_latestVersion'),
          content: Text(_updateDescription),
          actions: <Widget>[
            if (!_isForcedUpdate)
              TextButton(
                child: Text('稍后更新'),
                onPressed: () {
                  Navigator.of(context).pop();
                },
              ),
            TextButton(
              child: Text('立即更新'),
              onPressed: () {
                launchUrl(Uri.parse(_downloadUrl));
                if (_isForcedUpdate) {
                  SystemNavigator.pop();
                }
              },
            ),
          ],
        );
      },
    );
  }
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
