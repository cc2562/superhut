import 'dart:math' as math;

import 'package:dio/dio.dart';
import 'package:flutter_floating_bottom_bar/flutter_floating_bottom_bar.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:ionicons_plus/ionicons_plus.dart';
import 'package:liquid_glass_easy/liquid_glass_easy.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:superhut/home/Functionpage/view.dart';
import 'package:superhut/home/coursetable/view.dart';
import 'package:superhut/home/userpage/view.dart';

import '../../pages/Electricitybill/electricityApi.dart';
import '../../pages/Electricitybill/electricityPage.dart';
import '../../pages/update/update_dialog.dart';
import '../../utils/app_update_service.dart';
import '../../theme/glass/glass_overlays.dart';
import '../../theme/glass/glass_theme.dart';
import '../../theme/glass/glass_top_bar.dart';
import '../../theme/theme_controller.dart';
import '../coursetable/style/course_table_background.dart';
import '../coursetable/style/course_table_style.dart';
import '../coursetable/style/course_table_style_controller.dart';
import 'logic.dart';

class HomeviewPage extends StatefulWidget {
  const HomeviewPage({super.key});

  @override
  _HomeviewPageState createState() => _HomeviewPageState();
}

class _HomeviewPageState extends State<HomeviewPage>
    with AutomaticKeepAliveClientMixin {
  int _selectedIndex = 0;
  String _currentVersion = '0.0.1'; // 默认版本号

  /// 顶部标题栏在滚动后显示的文字。
  static const List<String> _tabTitles = ['课表', '功能', '我'];

  /// 顶栏标题是否浮现（仅在布尔翻转时更新，避免滚动时重建整页）。
  final ValueNotifier<bool> _revealed = ValueNotifier<bool>(false);

  /// 底部标签栏是否随下滚收起。
  final ValueNotifier<bool> _tabBarHidden = ValueNotifier<bool>(false);

  @override
  void dispose() {
    _revealed.dispose();
    _tabBarHidden.dispose();
    super.dispose();
  }

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
    showGlassDialog(
      context: context,
      barrierDismissible: true,
      title: const Text('电费达到预警值'),
      content: Text(showDescription),
      actions: <Widget>[
        TextButton(
          child: const Text('我知道了'),
          onPressed: () {
            Navigator.of(context).pop();
          },
        ),
        TextButton(
          child: const Text('立即充值'),
          onPressed: () {
            Navigator.of(context).pop();
            Navigator.push(
              context,
              MaterialPageRoute(builder: (context) => ElectricityPage()),
            );
          },
        ),
      ],
    );
  }

  /// 每次进入首页时的自动检查。
  ///
  /// 用户选择过「本版本不再提醒」的版本会被跳过；因为不是用户主动发起的检查，
  /// 所以这里静默失败，不弹错误提示。
  Future<void> _checkVersion() async {
    try {
      final AppUpdateInfo info = await AppUpdateService.fetch(_currentVersion);
      if (!mounted) return;
      final String? skipped = await AppUpdateService.skippedVersion();
      if (!mounted || !AppUpdateService.shouldNotify(info, skipped)) return;
      await showAppUpdateDialog(context: context, info: info);
    } on DioException catch (error) {
      debugPrint('版本检查失败: ${error.message}');
    }
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final HomeviewLogic logic = Get.put(HomeviewLogic());
    final ThemeData baseTheme = Theme.of(context);
    final ColorScheme backgroundScheme = baseTheme.colorScheme;

    // 深色自定义背景：整页（含顶栏、底部标签栏）改用深色配色，否则页面上的
    // 标题、节次与栏内图标会黑压压一片。背景层仍按原配色绘制。
    //
    // 注意这里始终保留同一层 `Theme`，只切换 data——如果按条件增删这层，
    // 整棵子树（含 PageView 与三个标签页）会被重建，切标签时会丢状态。
    final ThemeData effectiveTheme =
        _selectedIndex == 0 &&
                _needsDarkCourseChrome(backgroundScheme) &&
                Get.isRegistered<ThemeController>()
            ? Get.find<ThemeController>().darkTheme
            : baseTheme;

    return Theme(
      data: effectiveTheme,
      child: Builder(
        builder:
            (inner) =>
                inner.glassEnabled
                    ? _buildGlassShell(inner, logic, backgroundScheme)
                    : _buildMaterialShell(inner, logic, backgroundScheme),
      ),
    );
  }

  /// 课表标签页当前的自定义背景是否深到需要换成浅色前景。
  bool _needsDarkCourseChrome(ColorScheme scheme) {
    final CourseTableStyle style =
        CourseTableStyleController.instance.style.value;
    if (!style.hasCustomBackground) return false;
    return style.estimatedPageColor(scheme).computeLuminance() < 0.45;
  }

  /// 液态玻璃关闭或平台不支持时，完整保留原有 Material 3 外观。
  Widget _buildMaterialShell(
    BuildContext context,
    HomeviewLogic logic,
    ColorScheme backgroundScheme,
  ) {
    final colorScheme = Theme.of(context).colorScheme;

    return Scaffold(
      body: Stack(
        fit: StackFit.expand,
        children: [
          _buildCourseTableBackground(backgroundScheme),
          BottomBar(
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
        ],
      ),
    );
  }

  /// 顶栏背后的滚动边缘色带。
  ///
  /// 与 `GlassScaffold` 里的那份同款：内容滚到顶栏下方时淡回页面底色。
  /// 课表标签页可能换了自定义背景（纯色或图片），取色要跟着它走，
  /// 否则图片上会横一条白带。只订阅背景设置，不包住 `PageView`。
  Widget _buildTopScrollEdge(ColorScheme backgroundScheme) {
    final glass = context.glassTheme;
    final double height = MediaQuery.paddingOf(context).top + 56 + 24;

    return Obx(() {
      // 先读可观察变量：切标签时这里会换页，不订阅会触发 GetX 的 improper use。
      final style = CourseTableStyleController.instance.style.value;
      final Color pageColor =
          _selectedIndex == 0 && style.hasCustomBackground
              ? style.estimatedPageColor(backgroundScheme)
              : backgroundScheme.surface;

      return Positioned(
        top: 0,
        left: 0,
        right: 0,
        // 首页的顶栏标题是「下滚才淡入」的，色带跟着一起出现：
        // 回顶时那圈日历表头不该被一层底色雾罩住。
        child: ValueListenableBuilder<bool>(
          valueListenable: _revealed,
          builder: (context, revealed, child) {
            return AnimatedOpacity(
              opacity: revealed ? 1 : 0,
              duration: const Duration(milliseconds: 220),
              curve: Curves.easeOut,
              child: child,
            );
          },
          child: SizedBox(
            height: height,
            child: LiquidGlassScrollEdge(
              edge: LiquidGlassEdge.top,
              height: height,
              color: glass.scrollEdgeTint(pageColor),
              blur: glass.scrollEdgeBlurOrNull ?? 0,
              style: LiquidGlassScrollEdgeStyle.soft,
              curve: Curves.easeInOut,
              blurCurve: Curves.easeInOut,
            ),
          ),
        ),
      );
    });
  }

  /// 课表页的整页背景层。
  ///
  /// 铺在 `PageView` 之下，因此会自然延伸到状态栏区域与悬浮底栏下方；
  /// 只订阅背景设置，拖动滑杆时不会重建三个标签页。
  Widget _buildCourseTableBackground(ColorScheme backgroundScheme) {
    return Obx(() {
      // 必须先读取：切到别的标签时本层会整体消失，若不订阅，新创建的 Obx
      // 会因为「没有读到任何可观察变量」而报 GetX 的 improper use。
      final style = CourseTableStyleController.instance.style.value;
      if (_selectedIndex != 0) return const SizedBox.shrink();
      if (!style.hasCustomBackground) return const SizedBox.shrink();
      return CourseTableBackground(style: style, scheme: backgroundScheme);
    });
  }

  /// 底部标签栏的发丝描边。
  ///
  /// 位置与 `LiquidGlassTabBar` 自身的摆放规则一致（水平居中、距底 =
  /// 安全区内边距 + bottomMargin），只画一圈描边、不拦截点击。
  Widget _glassTabBarHairline(
    BuildContext context, {
    required double width,
    required double height,
    required double bottomMargin,
  }) {
    final bool isDark = Theme.of(context).brightness == Brightness.dark;
    return IgnorePointer(
      child: Align(
        alignment: Alignment.bottomCenter,
        child: Padding(
          padding: EdgeInsets.only(
            bottom: bottomMargin + MediaQuery.paddingOf(context).bottom,
          ),
          child: SizedBox(
            width: width,
            height: height,
            child: DecoratedBox(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(height / 2),
                border: Border.all(
                  color: Theme.of(context).colorScheme.onSurface.withValues(
                    alpha: isDark ? 0.16 : 0.10,
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  /// 液态玻璃首页：内容层保持原样，只叠加悬浮的功能层。
  Widget _buildGlassShell(
    BuildContext context,
    HomeviewLogic logic,
    ColorScheme backgroundScheme,
  ) {
    final theme = Theme.of(context);
    final glass = context.glassTheme;
    final tabBarWidth = math.min(MediaQuery.sizeOf(context).width - 48, 320.0);

    return Scaffold(
      backgroundColor: theme.colorScheme.surface,
      body: NotificationListener<ScrollNotification>(
        onNotification: _handleScroll,
        child: Stack(
          children: [
            _buildCourseTableBackground(backgroundScheme),
            PageView(
              physics: const NeverScrollableScrollPhysics(),
              controller: logic.homePageController,
              onPageChanged: (index) {
                if (_selectedIndex != index) {
                  setState(() => _selectedIndex = index);
                  _resetOverlayState();
                }
              },
              children: const [
                _KeepAlivePage(child: CourseTableView()),
                _KeepAlivePage(child: FunctionPage()),
                _KeepAlivePage(child: UserPage()),
              ],
            ),
            // 色带压在 PageView 之上、顶栏之下：只改变玻璃下面的内容。
            _buildTopScrollEdge(backgroundScheme),
            Positioned(
              top: 0,
              left: 0,
              right: 0,
              child: GlassTopBar(
                title: _tabTitles[_selectedIndex],
                revealed: _revealed,
                // 三个标签页各自有大标题（第 X 周 / 功能 / 你好），
                // 这里跟随滚动淡入即可，避免标题重复出现。
                alwaysShowTitle: false,
              ),
            ),
            Positioned.fill(
              child: ValueListenableBuilder<bool>(
                valueListenable: _tabBarHidden,
                builder: (context, hidden, child) {
                  return IgnorePointer(
                    ignoring: hidden,
                    child: AnimatedSlide(
                      offset: hidden ? const Offset(0, 0.2) : Offset.zero,
                      duration: const Duration(milliseconds: 200),
                      curve: Curves.easeOut,
                      child: AnimatedOpacity(
                        opacity: hidden ? 0 : 1,
                        duration: const Duration(milliseconds: 200),
                        curve: Curves.easeOut,
                        child: child,
                      ),
                    ),
                  );
                },
                child: Stack(
                  children: [
                    LiquidGlassTabBar(
                      items: const [
                        LiquidGlassTabBarItem(
                          icon: Ionicons.calendar_outline,
                          selectedIcon: Ionicons.calendar,
                        ),
                        LiquidGlassTabBarItem(
                          icon: Ionicons.apps_outline,
                          selectedIcon: Ionicons.apps,
                        ),
                        LiquidGlassTabBarItem(
                          icon: Ionicons.person_outline,
                          selectedIcon: Ionicons.person,
                        ),
                      ],
                      selectedIndex: _selectedIndex,
                      onChanged: (index) => _selectPage(logic, index),
                      style: glass.tabBarStyle,
                      itemStyle: glass.tabItemStyleOf(theme.colorScheme),
                      pillStyle: glass.tabPillStyle,
                      width: tabBarWidth,
                      height: 64,
                      margin: const EdgeInsets.only(bottom: 24),
                    ),
                    // 与顶部圆钮同款发丝描边。底部栏自己不投影，
                    // 靠这圈 8~16% 的描边在浅色/深色页面上勾出轮廓。
                    _glassTabBarHairline(
                      context,
                      width: tabBarWidth,
                      height: 64,
                      bottomMargin: 24,
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// 纵向滚动驱动：标题在离开顶部后浮现；底部标签栏下滚收起、上滚浮现。
  bool _handleScroll(ScrollNotification notification) {
    if (notification.metrics.axis != Axis.vertical) return false;
    final pixels = notification.metrics.pixels;

    if (!_revealed.value && pixels > 12) {
      _revealed.value = true;
    } else if (_revealed.value && pixels < 6) {
      _revealed.value = false;
    }

    if (notification is ScrollUpdateNotification) {
      final delta = notification.scrollDelta ?? 0;
      if (delta > 2 && pixels > 48 && !_tabBarHidden.value) {
        _tabBarHidden.value = true;
      } else if (delta < -2 && _tabBarHidden.value) {
        _tabBarHidden.value = false;
      }
    }
    return false;
  }

  void _resetOverlayState() {
    _revealed.value = false;
    _tabBarHidden.value = false;
  }

  void _selectPage(HomeviewLogic logic, int index) {
    if (_selectedIndex == index) {
      return;
    }

    setState(() => _selectedIndex = index);
    _resetOverlayState();
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
