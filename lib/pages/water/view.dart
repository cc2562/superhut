import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:ionicons/ionicons.dart';
import 'package:modal_bottom_sheet/modal_bottom_sheet.dart';
import 'package:url_launcher/url_launcher.dart';

import 'logic.dart';

// Local implementation of ScreenUtils
class ScreenUtils {
  // Responsive sizing utility
  static double length({required double vertical, required double horizon}) {
    // This implementation determines which value to use based on screen orientation
    final context = Get.context!;
    final isPortrait =
        MediaQuery.of(context).orientation == Orientation.portrait;
    return isPortrait ? vertical : horizon;
  }
}

// Extension for responsive text sizing using the SP unit
extension SizeExtension on num {
  double get w =>
      ScreenUtils.length(vertical: toDouble(), horizon: toDouble() * 0.4);

  double get sp =>
      ScreenUtils.length(vertical: toDouble(), horizon: toDouble() * 0.5);
}

// Local implementation of localization
class S {
  static S of(BuildContext context) => S();

  static S get current => S();

  // Localized strings
  String get function_hot_water => "洗澡热水";

  String get snackbar_tip => "提示";

  String function_hot_water_campus_balance(String balance) =>
      "校园卡余额: ¥$balance";

  String get function_hot_water_have_device_not_off => "您有设备未关闭";

  String get function_hot_water_btn_status_enable => "开启";

  String get function_hot_water_btn_status_disable => "关闭";

  String get function_drink_switch_start_success => "开启成功";

  String get function_drink_switch_start_fail => "开启失败";

  String get function_drink_switch_end_success => "关闭成功";

  String get function_drink_switch_end_fail => "关闭失败";
}

class FunctionHotWaterPage extends StatefulWidget {
  const FunctionHotWaterPage({super.key});

  @override
  State<FunctionHotWaterPage> createState() => _FunctionHotWaterPageState();
}

class _FunctionHotWaterPageState extends State<FunctionHotWaterPage> {
  final logic = Get.put(FunctionHotWaterLogic());
  final state = Get.find<FunctionHotWaterLogic>().state;
  final Uri _url = Uri.parse(
    'alipays://platformapi/startapp?appId=2019030163398604&page=pages/index/index',
  );

  Future<void> _launchUrl() async {
    if (!await launchUrl(_url)) {
      throw Exception('Could not launch $_url');
    }
  }

  @override
  void dispose() {
    super.dispose();
    Get.delete<FunctionHotWaterLogic>();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).colorScheme.surface,
      appBar: AppBar(
        title: Text(S.of(context).function_hot_water),
        elevation: 0,
        backgroundColor: Colors.transparent,
      ),
      extendBodyBehindAppBar: true,
      body: Stack(
        children: [
          // 添加背景渐变
          Positioned.fill(
            child: GetBuilder<FunctionHotWaterLogic>(
              builder: (logic) {
                return AnimatedContainer(
                  duration: Duration(milliseconds: 800),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.bottomCenter,
                      end: Alignment.topCenter,
                      colors: [
                        Colors.orange.withAlpha(60),
                        Colors.orange.withAlpha(70),
                        Colors.transparent,
                      ],
                      stops:
                          logic.state.waterStatus.value
                              ? [0.0, 0.8, 1.0] // 洗澡时，橙色集中在底部
                              : [0.0, 0.2, 1.0], // 未洗澡时，橙色集中在顶部
                    ),
                  ),
                );
              },
            ),
          ),
          SafeArea(
            child: Column(
              children: [
                // 热水状态显示
                waterStatusWidget(),

                // 设备选择区域
                Expanded(
                  child: Align(
                    alignment: Alignment.center,
                    child: deviceDrinkRowBtnWidget(),
                  ),
                ),

                // 开始/结束按钮区域
                Expanded(
                  child: Align(
                    alignment: Alignment.center,
                    child: deviceHotWaterBtnWidget(context),
                  ),
                ),

                // 余额显示
                balanceCardWidget(context),
              ],
            ),
          ),
          // 添加气泡动画
          Positioned.fill(
            child: GetBuilder<FunctionHotWaterLogic>(
              builder: (logic) {
                return BubbleAnimation(
                  isActive: logic.state.waterStatus.value,
                  color: Colors.orange,
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  /// 热水状态显示
  Widget waterStatusWidget() {
    return GetBuilder<FunctionHotWaterLogic>(
      builder: (logic) {
        return Container(
          width: double.infinity,
          padding: EdgeInsets.symmetric(vertical: 40, horizontal: 20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                logic.state.waterStatus.value ? '正在使用热水' : '未开启热水',
                style: TextStyle(fontSize: 42, fontWeight: FontWeight.bold),
              ),
            ],
          ),
        );
      },
    );
  }

  /// 获取选择饮水设备按钮
  Widget deviceDrinkRowBtnWidget() {
    return Padding(
      padding: EdgeInsets.symmetric(vertical: 15, horizontal: 20),
      child: GetBuilder<FunctionHotWaterLogic>(
        builder: (logic) {
          // 如果没有设备或未选择设备
          if (logic.state.deviceList.isEmpty ||
              logic.state.choiceDevice.value == -1) {
            return GestureDetector(
              onTap: () {
                _showDeviceSelectionDialog(context);
              },
              child: Container(
                width: double.infinity,
                padding: EdgeInsets.symmetric(vertical: 12),
                decoration: BoxDecoration(),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('当前设备'),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          '未选择设备',
                          style: TextStyle(
                            fontSize: 30,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        Icon(Icons.arrow_forward_ios, color: Colors.grey),
                      ],
                    ),
                  ],
                ),
              ),
            );
          }

          // 显示当前选择的设备
          String deviceName =
              logic.state.deviceList[logic.state.choiceDevice.value]["posname"];
          return GestureDetector(
            onTap: () {
              _showDeviceSelectionDialog(context);
            },
            child: Container(
              width: double.infinity,
              padding: EdgeInsets.symmetric(vertical: 12),
              decoration: BoxDecoration(),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('当前设备'),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        deviceName,
                        style: TextStyle(
                          fontSize: 30,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Icon(Icons.arrow_forward_ios, color: Colors.grey),
                    ],
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  /// 获取点击洗澡按钮按钮
  Widget deviceHotWaterBtnWidget(BuildContext context) {
    return Center(
      child: GetBuilder<FunctionHotWaterLogic>(
        builder: (logic) {
          // 检查是否正在加载或设备检查尚未完成
          bool isDisabled =
              logic.state.isLoading.value ||
              !logic.state.deviceCheckComplete.value;

          return GestureDetector(
            onTap: () {
              // 如果正在加载或设备检查尚未完成，不响应点击
              if (isDisabled) {
                // 仅当设备检查未完成时显示提示
                if (!logic.state.deviceCheckComplete.value &&
                    !logic.state.isLoading.value) {
                  ScaffoldMessenger.of(
                    context,
                  ).showSnackBar(SnackBar(content: Text('正在检测设备状态，请稍候...')));
                }
                return;
              }

              if (logic.state.choiceDevice.value == -1) {
                ScaffoldMessenger.of(
                  context,
                ).showSnackBar(SnackBar(content: Text('请先选择设备')));
                return;
              }

              if (logic.state.waterStatus.value) {
                logic.endWater();
              } else {
                logic.startWater();
              }
            },
            child: AnimatedContainer(
              duration: Duration(milliseconds: 300),
              width: 180,
              height: 180,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors:
                      isDisabled
                          ? [
                            Colors.grey.shade300,
                            Colors.grey.shade400,
                          ] // 禁用状态使用灰色
                          : logic.state.waterStatus.value
                          ? [Colors.orange.shade300, Colors.red.shade400]
                          : [Colors.orange.shade200, Colors.orange.shade400],
                ),
                boxShadow: [
                  BoxShadow(
                    color:
                        isDisabled
                            ? Colors.grey.withOpacity(0.4)
                            : logic.state.waterStatus.value
                            ? Colors.red.withOpacity(0.6)
                            : Colors.orange.withOpacity(0.4),
                    blurRadius: 15,
                    spreadRadius: 5,
                  ),
                ],
              ),
              child: Center(
                child:
                    logic.state.isLoading.value
                        ? _buildLoadingIndicator(logic.state.waterStatus.value)
                        : !logic.state.deviceCheckComplete.value
                        ? _buildCheckingIndicator() // 设备检查未完成时显示检查指示器
                        : Text(
                          logic.state.waterStatus.value
                              ? S
                                  .of(context)
                                  .function_hot_water_btn_status_disable
                              : S
                                  .of(context)
                                  .function_hot_water_btn_status_enable,
                          style: TextStyle(
                            fontSize: 32,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
              ),
            ),
          );
        },
      ),
    );
  }

  // 构建加载指示器
  Widget _buildLoadingIndicator(bool isWaterOn) {
    return Stack(
      alignment: Alignment.center,
      children: [
        // 旋转的圆圈
        SizedBox(
          width: 60,
          height: 60,
          child: CircularProgressIndicator(
            valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
            strokeWidth: 4,
          ),
        ),
        // 中心的图标
        Icon(
          isWaterOn ? Icons.play_arrow : Icons.stop_circle_outlined,
          color: Colors.white,
          size: 30,
        ),
      ],
    );
  }

  // 构建设备检查指示器
  Widget _buildCheckingIndicator() {
    return Stack(
      alignment: Alignment.center,
      children: [
        // 旋转的圆圈
        SizedBox(
          width: 60,
          height: 60,
          child: CircularProgressIndicator(
            valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
            strokeWidth: 4,
          ),
        ),
        // 中心的图标
        Icon(
          Icons.search, // 使用搜索图标表示正在检查
          color: Colors.white,
          size: 30,
        ),
      ],
    );
  }

  /// 余额卡片
  Widget balanceCardWidget(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(bottom: 30, left: 20, right: 20),
      child: GetBuilder<FunctionHotWaterLogic>(
        builder: (logic) {
          if (logic.state.balance.value == "null") {
            return SizedBox.shrink();
          }

          return Card(
            elevation: 0,
            color: Colors.transparent,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            child: Container(
              width: double.infinity,
              padding: EdgeInsets.symmetric(horizontal: 20, vertical: 16),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(16),
                color: Colors.white.withAlpha(20),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      Icon(
                        Icons.account_balance_wallet,
                        color: Colors.orange,
                        size: 28,
                      ),
                      SizedBox(width: 12),
                      Text(
                        S
                            .of(context)
                            .function_hot_water_campus_balance(
                              logic.state.balance.value,
                            ),
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                  IconButton(
                    icon: Icon(Icons.arrow_forward_ios, size: 16),
                    color: Colors.grey,
                    onPressed: () {
                      _launchUrl();
                    },
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  // 显示设备选择对话框
  void _showDeviceSelectionDialog(BuildContext context) {
    showCupertinoModalBottomSheet(
      context: context,
      expand: false,
      backgroundColor: Colors.transparent,
      builder:
          (context) => Material(
            color: Theme.of(context).colorScheme.surface,
            borderRadius: BorderRadius.only(
              topLeft: Radius.circular(15),
              topRight: Radius.circular(15),
            ),
            child: SafeArea(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 40,
                    height: 4,
                    margin: EdgeInsets.symmetric(vertical: 12),
                  ),
                  Padding(
                    padding: EdgeInsets.all(16),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          '选择设备',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        // 添加设备管理按钮
                        TextButton.icon(
                          onPressed: () {
                            Navigator.pop(context);
                            _showDeviceManagementDialog(context);
                          },
                          icon: Icon(Icons.settings, color: Colors.orange),
                          label: Text(
                            '管理设备',
                            style: TextStyle(color: Colors.orange),
                          ),
                        ),
                      ],
                    ),
                  ),
                  GetBuilder<FunctionHotWaterLogic>(
                    builder: (logic) {
                      if (logic.state.deviceList.isEmpty) {
                        return Padding(
                          padding: EdgeInsets.all(20),
                          child: Center(
                            child: Column(
                              children: [
                                Icon(
                                  Icons.hot_tub,
                                  size: 48,
                                  color: Colors.grey,
                                ),
                                SizedBox(height: 10),
                                Text('暂无可用设备，请先添加设备'),
                              ],
                            ),
                          ),
                        );
                      }

                      return Container(
                        constraints: BoxConstraints(
                          maxHeight: MediaQuery.of(context).size.height * 0.5,
                        ),
                        padding: EdgeInsets.fromLTRB(10, 0, 10, 20),
                        child: ListView.builder(
                          shrinkWrap: true,
                          itemCount: logic.state.deviceList.length,
                          itemBuilder: (context, index) {
                            String deviceName =
                                logic.state.deviceList[index]["posname"];
                            return ListTile(
                              title: Text(
                                deviceName,
                                style: TextStyle(fontSize: 20),
                              ),
                              trailing:
                                  logic.state.choiceDevice.value == index
                                      ? Icon(
                                        Ionicons.checkmark_circle,
                                        color: Colors.orange,
                                      )
                                      : null,
                              onTap: () {
                                if (logic.state.waterStatus.value) {
                                  Navigator.pop(context);
                                  return;
                                }
                                logic.setChoiceDevice(index);
                                Navigator.pop(context);
                              },
                            );
                          },
                        ),
                      );
                    },
                  ),
                ],
              ),
            ),
          ),
    );
  }

  // 显示设备管理对话框
  void _showDeviceManagementDialog(BuildContext context) {
    showCupertinoModalBottomSheet(
      context: context,
      expand: false,
      backgroundColor: Colors.transparent,
      builder:
          (context) => Material(
            color: Theme.of(context).colorScheme.surface,
            borderRadius: BorderRadius.only(
              topLeft: Radius.circular(15),
              topRight: Radius.circular(15),
            ),
            child: SafeArea(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 40,
                    height: 4,
                    margin: EdgeInsets.symmetric(vertical: 12),
                  ),
                  Padding(
                    padding: EdgeInsets.all(16),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          '设备管理',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        TextButton.icon(
                          onPressed: () {
                            Navigator.pop(context);
                            _showAddDevicePage(context);
                          },
                          icon: Icon(
                            Icons.add_circle_outline,
                            color: Colors.orange,
                          ),
                          label: Text(
                            '添加设备',
                            style: TextStyle(color: Colors.orange),
                          ),
                        ),
                      ],
                    ),
                  ),

                  // 设备列表区域
                  Padding(
                    padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '我的设备',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        SizedBox(height: 8),
                        GetBuilder<FunctionHotWaterLogic>(
                          builder: (logic) {
                            if (logic.state.deviceList.isEmpty) {
                              return Center(
                                child: Padding(
                                  padding: EdgeInsets.all(20),
                                  child: Column(
                                    children: [
                                      Icon(
                                        Icons.hot_tub,
                                        size: 48,
                                        color: Colors.grey,
                                      ),
                                      SizedBox(height: 10),
                                      Text('暂无设备，请先添加设备'),
                                    ],
                                  ),
                                ),
                              );
                            }

                            return Container(
                              constraints: BoxConstraints(
                                maxHeight:
                                    MediaQuery.of(context).size.height * 0.3,
                              ),
                              child: ListView.builder(
                                shrinkWrap: true,
                                itemCount: logic.state.deviceList.length,
                                itemBuilder: (context, index) {
                                  String deviceName =
                                      logic.state.deviceList[index]["posname"];
                                  String deviceCode =
                                      logic.state.deviceList[index]["poscode"];

                                  return ListTile(
                                    title: Text(deviceName),
                                    subtitle: Text('设备号: $deviceCode'),
                                    trailing: IconButton(
                                      icon: Icon(
                                        Icons.delete_outline,
                                        color: Colors.red,
                                      ),
                                      onPressed: () async {
                                        // 显示确认对话框
                                        showDialog(
                                          context: context,
                                          builder:
                                              (context) => AlertDialog(
                                                title: Text('删除设备'),
                                                content: Text(
                                                  '确定要删除设备 "$deviceName" 吗？',
                                                ),
                                                actions: [
                                                  TextButton(
                                                    onPressed: () {
                                                      Navigator.pop(context);
                                                    },
                                                    child: Text('取消'),
                                                  ),
                                                  TextButton(
                                                    onPressed: () async {
                                                      Navigator.pop(context);
                                                      await logic.deleteDevice(
                                                        deviceCode,
                                                      );
                                                      if (!context.mounted)
                                                        return;
                                                      Navigator.pop(context);
                                                      _showDeviceSelectionDialog(
                                                        context,
                                                      );
                                                    },
                                                    child: Text(
                                                      '确定',
                                                      style: TextStyle(
                                                        color: Colors.red,
                                                      ),
                                                    ),
                                                  ),
                                                ],
                                              ),
                                        );
                                      },
                                    ),
                                  );
                                },
                              ),
                            );
                          },
                        ),
                      ],
                    ),
                  ),

                  SizedBox(height: 20),
                ],
              ),
            ),
          ),
    );
  }

  // 显示添加设备页面(底部弹窗形式)
  void _showAddDevicePage(BuildContext context) {
    final TextEditingController deviceCodeController = TextEditingController();

    showCupertinoModalBottomSheet(
      context: context,
      expand: false,
      backgroundColor: Colors.transparent,
      builder:
          (context) => Material(
            color: Theme.of(context).colorScheme.surface,
            borderRadius: BorderRadius.only(
              topLeft: Radius.circular(15),
              topRight: Radius.circular(15),
            ),
            child: SafeArea(
              child: Padding(
                padding: EdgeInsets.only(
                  bottom: MediaQuery.of(context).viewInsets.bottom,
                ),
                child: SingleChildScrollView(
                  child: Padding(
                    padding: EdgeInsets.all(20),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // 标题栏
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              '添加新设备',
                              style: TextStyle(
                                fontSize: 20,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            IconButton(
                              icon: Icon(Icons.close),
                              onPressed: () => Navigator.pop(context),
                            ),
                          ],
                        ),
                        SizedBox(height: 5),
                        Text(
                          '请输入6位设备号码',
                          style: TextStyle(fontSize: 14, color: Colors.grey),
                        ),
                        SizedBox(height: 20),

                        // 输入框
                        TextField(
                          controller: deviceCodeController,
                          decoration: InputDecoration(
                            hintText: '输入6位设备号',
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                            filled: true,
                            fillColor: Colors.white.withOpacity(0.1),
                            contentPadding: EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 12,
                            ),
                            prefixIcon: Icon(
                              Icons.confirmation_number_outlined,
                              color: Colors.orange,
                            ),
                          ),
                          keyboardType: TextInputType.number,
                          maxLength: 6,
                          style: TextStyle(fontSize: 18),
                        ),
                        SizedBox(height: 20),

                        // 提交按钮
                        SizedBox(
                          width: double.infinity,
                          height: 50,
                          child: ElevatedButton(
                            onPressed: () async {
                              String deviceCode =
                                  deviceCodeController.text.trim();
                              if (deviceCode.isEmpty) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(content: Text('请输入设备号')),
                                );
                                return;
                              }

                              bool success = await logic.addDevice(deviceCode);
                              if (success && context.mounted) {
                                Navigator.pop(context);
                                _showDeviceSelectionDialog(context);
                              }
                            },
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.orange,
                              foregroundColor: Colors.white,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                            child: Text('添加设备', style: TextStyle(fontSize: 18)),
                          ),
                        ),

                        // 提示信息
                        SizedBox(height: 20),
                        Card(
                          elevation: 0,
                          color: Colors.transparent,
                          child: Container(
                            padding: EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              color: Colors.white.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Icon(
                                      Icons.info_outline,
                                      color: Colors.orange,
                                    ),
                                    SizedBox(width: 8),
                                    Text(
                                      '温馨提示',
                                      style: TextStyle(
                                        fontSize: 16,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ],
                                ),
                                SizedBox(height: 8),
                                Text('1. 设备号通常位于设备正门的显示屏中'),
                                Text('2. 设备号为6位数字'),
                                Text('3. 如无法添加，请联系学校管理员'),
                              ],
                            ),
                          ),
                        ),
                        SizedBox(height: 20),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
    );
  }
}

// 气泡动画组件
class BubbleAnimation extends StatefulWidget {
  final bool isActive;
  final Color color;

  const BubbleAnimation({
    Key? key,
    required this.isActive,
    this.color = Colors.blue,
  }) : super(key: key);

  @override
  State<BubbleAnimation> createState() => _BubbleAnimationState();
}

class _BubbleAnimationState extends State<BubbleAnimation>
    with SingleTickerProviderStateMixin {
  late List<Bubble> bubbles;
  Timer? _timer;
  final Random random = Random();

  @override
  void initState() {
    super.initState();
    bubbles = [];
    if (widget.isActive) {
      _startAnimation();
    }
  }

  @override
  void didUpdateWidget(BubbleAnimation oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.isActive && !oldWidget.isActive) {
      _startAnimation();
    } else if (!widget.isActive && oldWidget.isActive) {
      _stopAnimation();
    }
  }

  void _startAnimation() {
    bubbles = [];
    _timer = Timer.periodic(Duration(milliseconds: 300), (timer) {
      if (bubbles.length < 15) {
        setState(() {
          bubbles.add(
            Bubble(
              color: widget.color,
              size: random.nextDouble() * 20 + 5,
              position: Offset(
                random.nextDouble() * MediaQuery.of(context).size.width,
                MediaQuery.of(context).size.height + 20,
              ),
              destination: Offset(
                random.nextDouble() * MediaQuery.of(context).size.width,
                random.nextDouble() * 200,
              ),
              duration: Duration(seconds: random.nextInt(6) + 4),
            ),
          );
        });
      }

      // Remove bubbles that have completed their animation
      bubbles.removeWhere((bubble) => bubble.isCompleted);
    });
  }

  void _stopAnimation() {
    _timer?.cancel();
    setState(() {
      bubbles.clear();
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Stack(children: [for (var bubble in bubbles) bubble]);
  }
}

class Bubble extends StatefulWidget {
  final Color color;
  final double size;
  final Offset position;
  final Offset destination;
  final Duration duration;
  bool isCompleted = false;

  Bubble({
    Key? key,
    required this.color,
    required this.size,
    required this.position,
    required this.destination,
    required this.duration,
  }) : super(key: key);

  @override
  State<Bubble> createState() => _BubbleState();
}

class _BubbleState extends State<Bubble> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<Offset> _positionAnimation;
  late Animation<double> _opacityAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this, duration: widget.duration);

    _positionAnimation = Tween<Offset>(
      begin: widget.position,
      end: widget.destination,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeOut));

    _opacityAnimation = Tween<double>(begin: 0.7, end: 0.0).animate(
      CurvedAnimation(
        parent: _controller,
        curve: Interval(0.5, 1.0, curve: Curves.easeOut),
      ),
    );

    _controller.forward().then((_) {
      widget.isCompleted = true;
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        return Positioned(
          left: _positionAnimation.value.dx,
          top: _positionAnimation.value.dy,
          child: Opacity(
            opacity: _opacityAnimation.value,
            child: Container(
              width: widget.size,
              height: widget.size,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: widget.color.withOpacity(0.4),
                border: Border.all(
                  color: widget.color.withOpacity(0.6),
                  width: 1.0,
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}
