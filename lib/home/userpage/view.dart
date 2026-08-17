import 'package:enhanced_future_builder/enhanced_future_builder.dart';
import 'package:flutter/material.dart';
import 'package:ionicons_plus/ionicons_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:superhut/welcomepage/view.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../bridge/getCoursePage.dart';
import '../../pages/score/scorepage.dart';
import '../../pages/settings/theme_settings_page.dart';
import '../../utils/hut_user_api.dart';
import '../../utils/token.dart';
import '../../widgets/material_grouped_list.dart';
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
  String balance = "--";

  /// 获取余额
  Future<void> getBalance() async {
    await hutUserApi.getCardBalance().then((value) {
      balance = value.toString();
      setState(() {
        balance = balance;
      });
    });
  }

  final Uri _url = Uri.parse(
    'alipays://platformapi/startapp?appId=2019030163398604&page=pages/index/index',
  );

  Future<void> _launchUrl() async {
    if (!await launchUrl(_url)) {
      throw Exception('Could not launch $_url');
    }
  }

  Future<Map> getBaseData() async {
    final prefs = await SharedPreferences.getInstance();
    String name = prefs.getString('name') ?? "人类";
    String entranceYear = prefs.getString('entranceYear') ?? "0001";
    String academyName = prefs.getString('academyName') ?? "地球学院";
    String clsName = prefs.getString('clsName') ?? "地球1班";
    String yxzxf = prefs.getString('yxzxf') ?? "-";
    String zxfjd = prefs.getString('zxfjd') ?? "-";
    String pjxfjd = prefs.getString('pjxfjd') ?? "-";
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

      body: EnhancedFutureBuilder(
        future: getBaseData(),
        rememberFutureResult: true,
        whenDone: (d) {
          return SafeArea(
            child: ListView(
              padding: const EdgeInsets.fromLTRB(16, 20, 16, 120),
              children: [
                // 顶部标题
                Text(
                  "你好，${d["name"]}",
                  style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),

                const SizedBox(height: 20),
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
                        onTap: () async {
                          if (!await renewToken(context) || !context.mounted) {
                            return;
                          }
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => ScorePage(),
                            ),
                          );
                        },
                      ),
                    ),

                    const SizedBox(width: 12),

                    // 分数卡片
                    Expanded(
                      child: _buildStatCard(
                        title: "我的绩点",
                        value: d['pjxfjd'],
                        onTap: () async {
                          if (!await renewToken(context) || !context.mounted) {
                            return;
                          }
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => ScorePage(),
                            ),
                          );
                        },
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 12),

                // 校园卡
                Card.filled(
                  margin: EdgeInsets.zero,
                  color: Theme.of(context).colorScheme.tertiaryContainer,
                  child: SizedBox(
                    width: double.infinity,
                    child: Padding(
                      padding: const EdgeInsets.all(16),
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
                                      color:
                                          Theme.of(
                                            context,
                                          ).colorScheme.onTertiaryContainer,
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          Row(
                            children: [
                              Expanded(
                                child: Row(
                                  children: [
                                    Text(
                                      balance,
                                      style: Theme.of(
                                        context,
                                      ).textTheme.headlineMedium?.copyWith(
                                        fontWeight: FontWeight.bold,
                                        color:
                                            Theme.of(
                                              context,
                                            ).colorScheme.onTertiaryContainer,
                                      ),
                                    ),
                                    const SizedBox(width: 6),
                                    Text(
                                      'CNY',
                                      style: Theme.of(
                                        context,
                                      ).textTheme.labelLarge?.copyWith(
                                        color: Theme.of(context)
                                            .colorScheme
                                            .onTertiaryContainer
                                            .withValues(alpha: 0.7),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              FilledButton.tonal(
                                onPressed: _launchUrl,
                                child: const Text('充值'),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 20),
                //SizedBox(height: 24),

                // 功能项
                MaterialGroupedList(
                  children: [
                    _buildFunctionItem(
                      icon: Ionicons.refresh_outline,
                      title: "刷新课表",
                      onTap: () async {
                        if (!await renewToken(context) || !context.mounted) {
                          return;
                        }
                        Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (context) => Getcoursepage(renew: true),
                          ),
                        );
                      },
                    ),
                    _buildFunctionItem(
                      icon: Icons.palette_outlined,
                      title: '外观与主题',
                      onTap: () {
                        Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (_) => const ThemeSettingsPage(),
                          ),
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
                            MaterialPageRoute(
                              builder: (context) => WelcomepagePage(),
                            ),
                          );
                        });
                      },
                    ),
                    _buildFunctionItem(
                      icon: Ionicons.information_circle_outline,
                      title: "关于软件",
                      onTap: () {
                        Navigator.of(context).push(
                          MaterialPageRoute(builder: (context) => AboutPage()),
                        );
                      },
                    ),
                  ],
                ),
              ],
            ),
          );
        },
        whenNotDone: Center(child: CircularProgressIndicator()),
      ),
    );
  }

  // 构建统计卡片
  Widget _buildStatCard({
    required VoidCallback onTap,
    required String title,
    required String value,
  }) {
    final scheme = Theme.of(context).colorScheme;
    return Card.filled(
      margin: EdgeInsets.zero,
      color: scheme.secondaryContainer,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(14, 12, 10, 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: TextStyle(
                  color: scheme.onSecondaryContainer.withValues(alpha: 0.75),
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(height: 4),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    value,
                    style: TextStyle(
                      fontSize: 30,
                      height: 1.1,
                      fontWeight: FontWeight.bold,
                      color: scheme.onSecondaryContainer,
                    ),
                  ),
                  Icon(
                    Icons.arrow_forward,
                    size: 20,
                    color: scheme.onSecondaryContainer,
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  // 构建功能项
  Widget _buildFunctionItem({
    required IconData icon,
    required String title,
    required VoidCallback onTap,
  }) {
    return MaterialGroupedListItem(
      child: ListTile(
        leading: Icon(icon, color: Theme.of(context).colorScheme.primary),
        title: Text(title, style: TextStyle(fontWeight: FontWeight.w500)),
        trailing: const Icon(Icons.chevron_right),
        onTap: onTap,
      ),
    );
  }
}
