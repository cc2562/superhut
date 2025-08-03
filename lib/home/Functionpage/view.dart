import 'package:flutter/material.dart';
import 'package:ionicons/ionicons.dart';
import 'package:loading_animation_widget/loading_animation_widget.dart';
import 'package:superhut/pages/Commentary/CommentaryPage1.dart';
import 'package:superhut/pages/Electricitybill/electricityPage.dart';
import 'package:superhut/pages/ExamSchedule/exam_schedule_page.dart';
import 'package:superhut/pages/drink/view/view.dart';
import 'package:superhut/pages/freeroom/building.dart';
import 'package:superhut/pages/hutpages/hutmain.dart';
import 'package:superhut/pages/water/view.dart';

import '../../pages/score/scorepage.dart';
import '../../utils/token.dart';

class FunctionPage extends StatefulWidget {
  const FunctionPage({super.key});

  @override
  State<FunctionPage> createState() => _FunctionPageState();
}

class _FunctionPageState extends State<FunctionPage> {
  // 用于跟踪正在加载的功能
  final Set<String> _loadingFunctions = <String>{};

  // 设置加载状态
  void _setLoading(String functionId, bool isLoading) {
    setState(() {
      if (isLoading) {
        _loadingFunctions.add(functionId);
      } else {
        _loadingFunctions.remove(functionId);
      }
    });
  }

  // 检查是否正在加载
  bool _isLoading(String functionId) {
    return _loadingFunctions.contains(functionId);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).colorScheme.surface, // 浅灰蓝色背景，类似图片中的风格
      /*appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        title: Row(
          children: [
            CircleAvatar(
              radius: 18,
              backgroundImage: AssetImage('assets/images/avatar.png'),
              onBackgroundImageError: (e, s) => Icon(Icons.person),
            ),
            SizedBox(width: 10),
            Text(
              "你的名字",
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w500),
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: Icon(Ionicons.notifications_outline, size: 24),
            onPressed: () {},
          ),
        ],
      ),

       */
      body: SafeArea(
        child: ListView(
          padding: EdgeInsets.all(16),
          children: [
            // 标题
            Text(
              "功能",
              style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold),
            ),

            SizedBox(height: 16),

            // 搜索和筛选栏
            /*Row(
            children: [
              // 课程标签
              Container(
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(24),
                ),
                padding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                child: Row(
                  children: [
                    Icon(Ionicons.book_outline, color: Colors.orange),
                    SizedBox(width: 8),
                    Text("课程", style: TextStyle(fontWeight: FontWeight.w500)),
                  ],
                ),
              ),

              Spacer(),

              // 搜索按钮
              Container(
                decoration: BoxDecoration(
                  color: Colors.white,
                  shape: BoxShape.circle,
                ),
                padding: EdgeInsets.all(12),
                child: Icon(Ionicons.search_outline),
              ),
            ],
          ),

           */
            SizedBox(height: 24),

            _buildActivityCard(
              id: "empty_room",
              title: "空教室查询",
              rating: null,
              iconData: Ionicons.school,
              color: Colors.blue.shade100,
              hasArrow: true,
              onTap: () async {
                _setLoading("empty_room", true);
                try {
                  await renewToken(context);
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (context) => BuildingPage()),
                  );
                } finally {
                  _setLoading("empty_room", false);
                }
              },
            ),
            SizedBox(height: 16),

            // UX/UI 设计卡片
            _buildActivityCard(
              id: "score",
              title: "成绩查询",
              rating: null,
              iconData: Ionicons.document,
              color: Colors.green.shade100,
              hasArrow: true,
              onTap: () async {
                _setLoading("score", true);
                try {
                  await renewToken(context);
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (context) => ScorePage()),
                  );
                } finally {
                  _setLoading("score", false);
                }
              },
            ),

            SizedBox(height: 16),

            // 数据分析卡片
            _buildActivityCard(
              id: "drink",
              title: "宿舍喝水",
              rating: null,
              iconData: Ionicons.water,
              color: Colors.pink.shade100,
              hasArrow: true,
              onTap: () async {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => FunctionDrinkPage()),
                );
              },
            ),
            SizedBox(height: 16),
            _buildActivityCard(
              id: "hot_water",
              title: "洗澡",
              rating: null,
              iconData: Ionicons.sparkles,
              color: Colors.deepPurpleAccent.shade100,
              hasArrow: true,
              onTap: () async {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => FunctionHotWaterPage(),
                  ),
                );
              },
            ),
            SizedBox(height: 16),
            _buildActivityCard(
              id: "exam",
              title: "考试安排",
              rating: null,
              iconData: Ionicons.checkmark,
              color: Colors.blueGrey.shade100,
              hasArrow: true,
              onTap: () async {
                _setLoading("exam", true);
                try {
                  await renewToken(context);
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (context) => ExamSchedulePage()),
                  );
                } finally {
                  _setLoading("exam", false);
                }
              },
            ),
            SizedBox(height: 16),
            _buildActivityCard(
              id: "electricity",
              title: "电费充值",
              rating: null,
              iconData: Ionicons.flash,
              color: Colors.lime.shade100,
              hasArrow: true,
              onTap: () async {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => ElectricityPage()),
                );
              },
            ),
            SizedBox(height: 16),
            _buildActivityCard(
              id: "commentary",
              title: "学生评教",
              rating: null,
              iconData: Ionicons.checkbox_outline,
              color: Colors.pinkAccent.shade100,
              hasArrow: true,
              onTap: () async {
                _setLoading("commentary", true);
                try {
                  await renewToken(context);
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (context) => commentaryPage1()),
                  );
                } finally {
                  _setLoading("commentary", false);
                }
              },
            ),
            SizedBox(height: 16),
            _buildActivityCard(
              id: "hut_main",
              title: "智慧工大",
              rating: null,
              iconData: Ionicons.phone_portrait,
              color: Colors.orange.shade100,
              hasArrow: true,
              onTap: () async {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => HutMainPage()),
                );
              },
            ),

            SizedBox(height: 100),
          ],
        ),
      ),
    );
  }

  // 构建活动卡片
  Widget _buildActivityCard({
    required String id,
    required String title,
    required IconData iconData,
    required Color color,
    double? rating,
    bool hasArrow = false,
    required VoidCallback onTap,
  }) {
    final isLoading = _isLoading(id);
    
    return GestureDetector(
      onTap: isLoading ? null : onTap, // 如果正在加载则禁用点击
      child: Container(
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surfaceContainer,
          borderRadius: BorderRadius.circular(16),
          //boxShadow: [
          //  BoxShadow(
          //    color: Colors.black.withOpacity(0.05),
          //    blurRadius: 10,
          //    offset: Offset(0, 4),
          //   ),
          // ],
        ),
        child: Column(
          children: [
            // 活动内容部分
            Padding(
              padding: EdgeInsets.all(16),
              child: Row(
                children: [
                  // 图标
                  Container(
                    decoration: BoxDecoration(
                      color: color,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    padding: EdgeInsets.all(12),
                    child: Icon(iconData, size: 28, color: Colors.white),
                  ),

                  SizedBox(width: 16),

                  // 标题和评分
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          title,
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        if (rating != null)
                          Row(
                            children: [
                              Icon(
                                Ionicons.star,
                                color: Colors.amber,
                                size: 16,
                              ),
                              SizedBox(width: 4),
                              Text(
                                rating.toString(),
                                style: TextStyle(
                                  // color: Colors.grey.shade700,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ],
                          ),
                      ],
                    ),
                  ),

                  // 右侧箭头或加载动画或人员头像
                  if (hasArrow)
                    Container(
                      decoration: BoxDecoration(shape: BoxShape.circle),
                      padding: EdgeInsets.all(8),
                      child: isLoading 
                        ? LoadingAnimationWidget.inkDrop(
                            color: Theme.of(context).colorScheme.primary,
                            size: 16,
                          )
                        : Icon(Ionicons.arrow_forward, size: 16),
                    )
                  else
                    _buildAvatarGroup(),
                ],
              ),
            ),

            // 底部分隔线和+6显示
            if (!hasArrow)
              Container(
                padding: EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                decoration: BoxDecoration(
                  border: Border(top: BorderSide(color: Colors.grey.shade200)),
                ),
                child: Row(
                  children: [
                    _buildAvatarGroup(),
                    SizedBox(width: 8),
                    Text(
                      "+6",
                      style: TextStyle(
                        //color: Colors.grey.shade700,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }

  // 构建头像组
  Widget _buildAvatarGroup() {
    return SizedBox(
      width: 80,
      height: 24,
      child: Stack(
        children: List.generate(3, (index) {
          return Positioned(
            left: index * 18.0,
            child: Container(
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(color: Colors.white, width: 1.5),
              ),
              child: CircleAvatar(
                radius: 12,
                backgroundColor:
                    Colors.primaries[index % Colors.primaries.length],
                child: Text(
                  String.fromCharCode(65 + index),
                  style: TextStyle(color: Colors.white, fontSize: 10),
                ),
              ),
            ),
          );
        }),
      ),
    );
  }
}
