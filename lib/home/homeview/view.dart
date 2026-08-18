import 'package:dio/dio.dart';
import 'package:flutter_floating_bottom_bar/flutter_floating_bottom_bar.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:ionicons_plus/ionicons_plus.dart';
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
  int _selectedIndex = 0;
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
    bool isEnable = prefs.getBool('enableBillWarning') ?? false;
    if (isEnable == false) {
      return;
    }
    String checkRoomId = prefs.getString('enableRoomId') ?? '';
    //获取电费
    await electricityApi.onInit();
    await electricityApi.getHistory();
    var nowRoomInfo = await electricityApi.getSingleRoomInfo(checkRoomId);
    var roomCount = nowRoomInfo["eleTail"];
    var setRoomName = nowRoomInfo["roomName"];
    double bill = prefs.getDouble('enableBill') ?? 0;
    if (double.parse(roomCount) >= bill) {
      print("无风险");
    } else {
      print("有风险");
      _showAlert('当前电费：${roomCount}元\n设置电费：${bill}元\n房间：${setRoomName}');
    }
    print('当前电费：${roomCount}元\n设置电费：${bill}元\n房间：${setRoomName}\n\n');
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
    try {
      final dio = Dio();
      final response = await dio.get(
        'https://super.ccrice.com/api/check_version.php?version=$_currentVersion',
      );
      final Map<String, dynamic> data = response.data;
      if (!mounted) return;
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
    } on DioException catch (error) {
      debugPrint('版本检查失败: ${error.message}');
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
    final colorScheme = Theme.of(context).colorScheme;

    return Scaffold(
      body: BottomBar(
        layout: const BottomBarLayout.adaptive(
          maxWidth: 420,
          offset: 16,
          borderRadius: BorderRadius.all(Radius.circular(30)),
        ),
        motion: const BottomBarMotion.cupertino(
          preset: BottomBarCupertinoMotion.snappy,
          duration: Duration(milliseconds: 420),
          slideStart: Offset(0, 2),
        ),
        scrollBehavior: const BottomBarScrollBehavior(
          hideOnScroll: true,
          showAtStart: true,
          deltaThreshold: 10,
        ),
        showIcon: false,
        theme: BottomBarThemeData(
          barDecoration: BoxDecoration(
            color: colorScheme.surfaceContainer.withValues(alpha: 0.96),
            borderRadius: BorderRadius.circular(30),
            border: Border.all(
              color: colorScheme.outlineVariant.withValues(alpha: 0.5),
            ),
            boxShadow: [
              BoxShadow(
                color: colorScheme.shadow.withValues(alpha: 0.16),
                blurRadius: 24,
                offset: const Offset(0, 8),
              ),
            ],
          ),
        ),
        body: PageView(
          physics: const NeverScrollableScrollPhysics(),
          controller: logic.homePageController,
          onPageChanged: (index) {
            if (_selectedIndex != index) {
              setState(() => _selectedIndex = index);
            }
          },
          children: const [
            _KeepAlivePage(child: CourseTableView()),
            _KeepAlivePage(child: FunctionPage()),
            _KeepAlivePage(child: UserPage()),
          ],
        ),
        child: Padding(
          padding: const EdgeInsets.all(6),
          child: LayoutBuilder(
            builder: (context, constraints) {
              final itemWidth = constraints.maxWidth / 3;

              return Stack(
                children: [
                  AnimatedPositioned(
                    duration: const Duration(milliseconds: 280),
                    curve: Curves.easeOutCubic,
                    left: itemWidth * _selectedIndex,
                    top: 0,
                    bottom: 0,
                    width: itemWidth,
                    child: IgnorePointer(
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          color: colorScheme.primaryContainer,
                          borderRadius: BorderRadius.circular(24),
                        ),
                      ),
                    ),
                  ),
                  Row(
                    children: [
                      _FloatingNavigationItem(
                        icon: Ionicons.calendar_outline,
                        selectedIcon: Ionicons.calendar,
                        label: '课表',
                        selected: _selectedIndex == 0,
                        onTap: () => _selectPage(logic, 0),
                      ),
                      _FloatingNavigationItem(
                        icon: Ionicons.apps_outline,
                        selectedIcon: Ionicons.apps,
                        label: '功能',
                        selected: _selectedIndex == 1,
                        onTap: () => _selectPage(logic, 1),
                      ),
                      _FloatingNavigationItem(
                        icon: Ionicons.person_outline,
                        selectedIcon: Ionicons.person,
                        label: '我',
                        selected: _selectedIndex == 2,
                        onTap: () => _selectPage(logic, 2),
                      ),
                    ],
                  ),
                ],
              );
            },
          ),
        ),
      ),
    );
  }

  void _selectPage(HomeviewLogic logic, int index) {
    if (_selectedIndex == index) {
      return;
    }

    setState(() => _selectedIndex = index);
    logic.homePageController.jumpToPage(index);
  }

  @override
  bool get wantKeepAlive => true;
}

class _FloatingNavigationItem extends StatelessWidget {
  const _FloatingNavigationItem({
    required this.icon,
    required this.selectedIcon,
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final IconData icon;
  final IconData selectedIcon;
  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Expanded(
      child: Semantics(
        button: true,
        selected: selected,
        label: label,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(24),
          child: Container(
            constraints: const BoxConstraints(minHeight: 52),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                AnimatedSwitcher(
                  duration: const Duration(milliseconds: 180),
                  child: Icon(
                    selected ? selectedIcon : icon,
                    key: ValueKey(selected),
                    size: 22,
                    color:
                        selected
                            ? colorScheme.onPrimaryContainer
                            : colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _KeepAlivePage extends StatefulWidget {
  const _KeepAlivePage({required this.child});

  final Widget child;

  @override
  State<_KeepAlivePage> createState() => _KeepAlivePageState();
}

class _KeepAlivePageState extends State<_KeepAlivePage>
    with AutomaticKeepAliveClientMixin {
  @override
  Widget build(BuildContext context) {
    super.build(context);
    return widget.child;
  }

  @override
  bool get wantKeepAlive => true;
}
