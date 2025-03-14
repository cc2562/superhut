import 'package:flutter/material.dart';
import 'package:ionicons/ionicons.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:superhut/welcomepage/view.dart';

import '../../bridge/getCoursePage.dart';
import '../../command/token.dart';
import '../about/view.dart';

class UserPage extends StatefulWidget {
  const UserPage({super.key});

  @override
  State<UserPage> createState() => _UserPageState();
}

class _UserPageState extends State<UserPage> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).colorScheme.surface, // 浅灰蓝色背景，类似图片中的风格

      body: SafeArea(
        child: ListView(
          padding: EdgeInsets.all(20),
          children: [
            // 顶部标题
            Text(
              "学习进度",
              style: TextStyle(
                fontSize: 32,
                fontWeight: FontWeight.bold,

              ),
            ),

            SizedBox(height: 24),

            // 完成和分数卡片
            Row(
              children: [
                // 完成卡片
                Expanded(
                  child: _buildStatCard(
                    title: "已修学分",
                    value: "18",
                    color: Color(0xFFE3F1EC),
                    textColor: Colors.black87,
                  ),
                ),

                SizedBox(width: 12),

                // 分数卡片
                Expanded(
                  child: _buildStatCard(
                    title: "我的分数",
                    value: "72",
                    color: Color(0xFFFFF6E0),
                    textColor: Colors.black87,
                  ),
                ),
              ],
            ),

            SizedBox(height: 20),

            // 生产力卡片
            /*Container(
              padding: EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Color(0xFFF1E6F5),
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.05),
                    blurRadius: 10,
                    offset: Offset(0, 4),
                  ),
                ],
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
                        child: Icon(Ionicons.flame_outline, size: 20),
                      ),
                      SizedBox(width: 10),
                      Text(
                        "我的生产力",
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w500,
                          color:  Colors.black87
                        ),
                      ),
                    ],
                  ),

                  SizedBox(height: 24),

                  // 进度环
                  Center(
                    child: Stack(
                      alignment: Alignment.center,
                      children: [
                        SizedBox(
                          width: 160,
                          height: 160,
                          child: CircularProgressIndicator(
                            value: 0.72,
                            strokeWidth: 12,
                            backgroundColor: Colors.white.withOpacity(0.5),
                            valueColor: AlwaysStoppedAnimation<Color>(Colors.black),
                          ),
                        ),
                        Column(
                          children: [
                            Text(
                              "240",
                              style: TextStyle(
                                fontSize: 40,
                                fontWeight: FontWeight.bold,
                                color: Colors.black87
                              ),
                            ),
                            Text(
                              "积分",
                              style: TextStyle(
                                fontSize: 16,
                                color: Colors.black54,

                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),

                  SizedBox(height: 20),

                  // 底部文字
                  Center(
                    child: Container(
                      padding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        "您的生产力高于72%的人",
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                            color: Colors.black87
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
*/
            //SizedBox(height: 24),

            // 功能项
            _buildFunctionItem(
              icon: Ionicons.refresh_outline,
              title: "刷新课表",
              onTap: () async {
                await renewToken(context);
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
      ),
    );
  }
  
  // 构建统计卡片
  Widget _buildStatCard({
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
       // boxShadow: [
       //   BoxShadow(
       //     color: Colors.black.withOpacity(0.05),
       //     blurRadius: 10,
       //     offset: Offset(0, 4),
       //   ),
       // ],
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
                child: Icon(
                  Icons.arrow_forward,
                  size: 16,
                  color: textColor,
                ),
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
        //boxShadow: [
        //  BoxShadow(
        //    color: Colors.black.withOpacity(0.03),
        //    blurRadius: 6,
        //    offset: Offset(0, 2),
        //  ),
        //],
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
