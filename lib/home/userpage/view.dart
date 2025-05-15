import 'package:enhanced_future_builder/enhanced_future_builder.dart';
import 'package:flutter/material.dart';
import 'package:ionicons/ionicons.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:superhut/welcomepage/view.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../bridge/getCoursePage.dart';
import '../../pages/score/scorepage.dart';
import '../../utils/hut_user_api.dart';
import '../../utils/token.dart';
import '../about/view.dart';

class UserPage extends StatefulWidget {
  const UserPage({super.key});

  @override
  State<UserPage> createState() => _UserPageState();
}

class _UserPageState extends State<UserPage> {
  @override
  void initState() {
    // TODO: implement initState
    super.initState();
    getBalance();
  }
  final hutUserApi = HutUserApi();
  String balance="--";
  /// 获取余额
  Future<void> getBalance() async {
    await hutUserApi.getCardBalance().then((value) {
      balance = value.toString()??'--';
      setState(() {
        balance=balance;
      });
    });
  }
  final Uri _url = Uri.parse('alipays://platformapi/startapp?appId=2019030163398604&page=pages/index/index');
  Future<void> _launchUrl() async {
    if (!await launchUrl(_url)) {
      throw Exception('Could not launch $_url');
    }
  }

  Future<Map> getBaseData() async {
    final prefs = await SharedPreferences.getInstance();
    String name = await prefs.getString('name')??"人类";
    String entranceYear = await prefs.getString('entranceYear')??"0001";
    String academyName = await prefs.getString('academyName') ?? "地球学院";
    String clsName = await prefs.getString('clsName')??"地球1班";
    String yxzxf = await prefs.getString('yxzxf')??"-";
    String zxfjd = await prefs.getString('zxfjd')??"-";
    String pjxfjd = await prefs.getString('pjxfjd')??"-";
    Map data = {
      "name": name,
      "entranceYear": entranceYear,
      "academyName": academyName,
      "clsName": clsName,
      "yxzxf": yxzxf,
      "zxfjd": zxfjd,
      "pjxfjd": pjxfjd,
    };
    return data;
  }
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).colorScheme.surface, // 浅灰蓝色背景，类似图片中的风格

      body: EnhancedFutureBuilder(future: getBaseData(),
          rememberFutureResult: true,
          whenDone: (d){
        return SafeArea(
          child: ListView(
            padding: EdgeInsets.all(20),
            children: [
              // 顶部标题
              Text(
                "你好，${d["name"]}",
                style: TextStyle(
                  fontSize: 26,
                  fontWeight: FontWeight.bold,

                ),
              ),

              SizedBox(height: 24),
              /*
              Container(
                padding: EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: Color(0xFFF1E6F5),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // 标题行
                    Row(
                      children: [
                        Container(
                          padding: EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Icon(Ionicons.person_outline, size: 20), // 修改图标为用户相关图标
                        ),
                        SizedBox(width: 10),
                        Text(
                          "我的信息",
                          style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w500,
                              color: Colors.black87),
                        ),
                      ],
                    ),

                    SizedBox(height: 16),

                    // 学生信息字段
                    Text(
                      "姓名: 张三", // 示例数据，实际可动态绑定
                      style: TextStyle(fontSize: 14),
                    ),
                    SizedBox(height: 8),
                    Text(
                      "学号: 20230001", // 示例数据，实际可动态绑定
                      style: TextStyle(fontSize: 14),
                    ),
                    SizedBox(height: 8),
                    Text(
                      "班级: 计算机科学与技术1班", // 示例数据，实际可动态绑定
                      style: TextStyle(fontSize: 14),
                    ),

                    SizedBox(height: 20),
                  ],
                ),
              ),


              SizedBox(height: 24),

              */
              // 完成和分数卡片
              Row(
                children: [
                  // 完成卡片
                  Expanded(
                    child: _buildStatCard(
                      title: "已修学分",
                      value: d['yxzxf'],
                      color: Color(0xFFE3F1EC),
                      textColor: Colors.black87,
                      onTap: () async {
                        await renewToken(context);
                        Navigator.push(
                          context,
                          MaterialPageRoute(builder: (context) => ScorePage()),
                        );
                      }
                    ),
                  ),

                  SizedBox(width: 12),

                  // 分数卡片
                  Expanded(
                    child: _buildStatCard(
                      title: "我的绩点",
                      value: d['pjxfjd'],
                      color: Color(0xFFFFF6E0),
                      textColor: Colors.black87,
                        onTap: () async {
                          await renewToken(context);
                          Navigator.push(
                            context,
                            MaterialPageRoute(builder: (context) => ScorePage()),
                          );
                        }
                    ),
                  ),
                ],
              ),

              SizedBox(height: 10),

              // 校园卡
          Card(
            elevation: 0,
            color: Colors.purple.shade100,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            child: Container(
              width: double.infinity,
              padding: EdgeInsets.all(16),
              decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(16),
                  color: Colors.white.withAlpha(20)
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: [
                          Text(
                            '校园卡',
                            style: TextStyle(
                                fontWeight: FontWeight.w500,
                                color: Colors.black
                            ),
                          ),
                        ],
                      ),

                    ],
                  ),
                  SizedBox(height: 8),
                  Row(
                    children: [
                      Text(
                        balance,
                        style: TextStyle(
                            fontSize: 32,
                            fontWeight: FontWeight.bold,
                            color: Colors.black
                        ),
                      ),
                      SizedBox(width: 5,),
                      Text(
                        'CNY',
                        style: TextStyle(
                            fontSize: 32,
                            fontWeight: FontWeight.w100,
                            color: Colors.black.withAlpha(150)
                        ),
                      ),
                    ],
                  ),
                  TextButton(onPressed: (){
                    _launchUrl();
                  },  style: ButtonStyle(
                    backgroundColor: WidgetStateProperty.all(Colors.purple.shade200),
                    foregroundColor: WidgetStateProperty.all(Colors.white),
                    shape: WidgetStateProperty.all(
                      RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                    ),
                  ),child: Text('充值'))
                ],
              )
            ),
          ),
              SizedBox(height: 20),
              //SizedBox(height: 24),

              // 功能项
              _buildFunctionItem(
                icon: Ionicons.refresh_outline,
                title: "刷新课表",
                onTap: () async {
                  await renewToken(context);
                 // print("跳转");
                  Navigator.of(context).push(
                      MaterialPageRoute(builder: (context) => Getcoursepage(renew: true))
                  );
                },
              ),

              _buildFunctionItem(
                icon: Ionicons.log_out_outline,
                title: "退出登录",
                onTap: () async {
                  final prefs = await SharedPreferences.getInstance();
                  prefs.setString('user', "");
                  prefs.setString('password', "");
                  await prefs.setBool('isFirstOpen', true);
                  WidgetsBinding.instance.addPostFrameCallback((_) {
                    Navigator.of(context).pushReplacement(
                        MaterialPageRoute(builder: (context) => WelcomepagePage())
                    );
                  });
                },
              ),

              _buildFunctionItem(
                icon: Ionicons.information_circle_outline,
                title: "关于软件",
                onTap: () {
                  Navigator.of(context).push(
                      MaterialPageRoute(builder: (context) => AboutPage())
                  );
                },
              ),
              SizedBox(height: 100,),
            ],
          ),
        );
          },
          whenNotDone: Center(
            child: CircularProgressIndicator(),
          )),
    );
  }
  
  // 构建统计卡片
  Widget _buildStatCard({
    required VoidCallback onTap,
    required String title,
    required String value,
    required Color color,
    required Color textColor,
  }) {
    return Container(
      padding: EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: TextStyle(
              color: textColor.withOpacity(0.7),
              fontWeight: FontWeight.w500,
            ),
          ),
          SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                value,
                style: TextStyle(
                  fontSize: 32,
                  fontWeight: FontWeight.bold,
                  color: textColor,
                ),
              ),
              Container(
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.5),
                  shape: BoxShape.circle,
                ),
                padding: EdgeInsets.all(4),
                child: IconButton(onPressed: onTap, icon: Icon(
                  Icons.arrow_forward,
                  size: 16,
                  color: textColor,
                )),
              ),
            ],
          ),

        ],
      ),
    );
  }

  // 构建功能项
  Widget _buildFunctionItem({
    required IconData icon,
    required String title,
    required VoidCallback onTap,
  }) {
    return Container(
      margin: EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Theme
            .of(context)
            .colorScheme
            .surfaceContainer,
        borderRadius: BorderRadius.circular(12),
      ),
      child: ListTile(
        leading: Icon(icon, color: Theme.of(context).primaryColor),
        title: Text(
          title,
          style: TextStyle(fontWeight: FontWeight.w500),
        ),
        trailing: Icon(Icons.chevron_right, color: Colors.grey),
        onTap: onTap,
      ),
    );
  }
}
