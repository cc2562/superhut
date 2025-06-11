import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:ionicons/ionicons.dart';
import 'package:modal_bottom_sheet/modal_bottom_sheet.dart';
import 'package:qr_code_scanner/qr_code_scanner.dart';

import 'logic.dart';

class FunctionDrinkPage extends StatefulWidget {
  const FunctionDrinkPage({super.key});

  @override
  State<FunctionDrinkPage> createState() => _FunctionDrinkPageState();
}

class _FunctionDrinkPageState extends State<FunctionDrinkPage> {
  final logic = Get.put(FunctionDrinkLogic());
  final state = Get.find<FunctionDrinkLogic>().state;

  @override
  void dispose() {
    super.dispose();
    Get.delete<FunctionDrinkLogic>();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).colorScheme.surface,
      appBar: AppBar(
        title: Text('快速喝水'),
        elevation: 0,
        backgroundColor: Colors.transparent,
      ),
      extendBodyBehindAppBar: true,
      body: Stack(
        children: [
          // 添加背景渐变
          Positioned.fill(
            child: GetBuilder<FunctionDrinkLogic>(
              builder: (logic) {
                return AnimatedContainer(
                  duration: Duration(milliseconds: 800),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.bottomCenter,
                      end: Alignment.topCenter,
                      colors: [
                        Colors.blue.withAlpha(60),
                        Colors.blue.withAlpha(70),
                        Colors.transparent,
                      ],
                      stops:
                          logic.state.drinkStatus.value
                              ? [0.0, 0.8, 1.0] // 喝水时，蓝色集中在底部
                              : [0.0, 0.2, 1.0], // 未喝水时，蓝色集中在顶部
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

                // 选择饮水设备按钮
                Expanded(
                  child: Align(
                    alignment: Alignment.bottomCenter,
                    child: Padding(
                      padding: EdgeInsets.symmetric(vertical: 0),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          deviceDrinkRowBtnWidget(),
                          paymentInfoWidget(),
                        ],
                      ),
                    ),
                  ),
                ),

                Align(
                  alignment: Alignment.bottomCenter,
                  child: Padding(
                    padding: EdgeInsets.only(bottom: 20),
                    child: TextButton(
                      onPressed: () {
                        _showMoreFunctionsBottomSheet(context);
                      },
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text('展开更多功能', style: TextStyle(color: Colors.grey)),
                          Icon(Icons.keyboard_arrow_right, color: Colors.grey),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          // 添加气泡动画
          Positioned.fill(
            child: GetBuilder<FunctionDrinkLogic>(
              builder: (logic) {
                return BubbleAnimation(isActive: logic.state.drinkStatus.value);
              },
            ),
          ),
        ],
      ),
    );
  }

  /// 热水状态显示
  Widget waterStatusWidget() {
    return GetBuilder<FunctionDrinkLogic>(
      builder: (logic) {
        return Container(
          width: double.infinity,
          padding: EdgeInsets.symmetric(vertical: 40, horizontal: 20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                logic.state.drinkStatus.value ? '正在接水中' : '未开启接水',
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
      child: GetBuilder<FunctionDrinkLogic>(
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
          String deviceName = logic.formatDeviceName(
            logic.state.deviceList[logic.state.choiceDevice.value]["name"],
          );

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
                          fontSize: 35,
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
                    decoration: BoxDecoration(
                      color: Colors.grey[300],
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                  Padding(
                    padding: EdgeInsets.all(16),
                    child: Text(
                      '选择设备',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  GetBuilder<FunctionDrinkLogic>(
                    builder: (logic) {
                      if (logic.state.deviceList.isEmpty) {
                        return Padding(
                          padding: EdgeInsets.all(20),
                          child: Center(
                            child: Column(
                              children: [
                                Icon(
                                  Icons.device_unknown,
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
                        child: ListView.builder(
                          shrinkWrap: true,
                          itemCount: logic.state.deviceList.length,
                          itemBuilder: (context, index) {
                            String deviceName = logic.formatDeviceName(
                              logic.state.deviceList[index]["name"],
                            );
                            return ListTile(
                              title: Text(
                                deviceName,
                                style: TextStyle(fontSize: 20),
                              ),
                              trailing:
                                  logic.state.choiceDevice.value == index
                                      ? Icon(
                                        Ionicons.checkmark_circle,
                                        color: Theme.of(context).primaryColor,
                                      )
                                      : null,
                              onTap: () {
                                if (logic.state.drinkStatus.value) {
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
                  Padding(
                    padding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        TextButton(
                          onPressed: () {
                            Navigator.pop(context);
                          },
                          child: Text('取消'),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
    );
  }

  /// 位置信息显示
  Widget locationInfoWidget() {
    return Container(
      width: double.infinity,
      child: Column(
        children: [
          Container(
            height: 180,
            color: Colors.grey[200], // 地图占位背景
            child: Center(
              child: Icon(Icons.location_on, size: 48, color: Colors.blue),
            ),
          ),
        ],
      ),
    );
  }

  /// 开启用水按钮
  Widget deviceDrinkBtnWidget(BuildContext context) {
    return GetBuilder<FunctionDrinkLogic>(
      builder: (logic) {
        return Container(
          width: double.infinity,
          padding: EdgeInsets.symmetric(horizontal: 20),
          child: TextButton(
            onPressed: () {
              if (logic.state.choiceDevice.value == -1) {
                return;
              }

              if (logic.state.drinkStatus.value) {
                logic.endDrink(context);
              } else {
                logic.startDrink(context);
              }
            },
            style: ButtonStyle(
              backgroundColor: WidgetStateProperty.all(
                Theme.of(context).colorScheme.primary,
              ),
              foregroundColor: WidgetStateProperty.all(Colors.white),
              padding: WidgetStateProperty.all(
                EdgeInsets.symmetric(vertical: 15),
              ),
              shape: WidgetStateProperty.all(
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
            ),
            child: Text(
              logic.state.drinkStatus.value ? '结算' : '开启用水',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
          ),
        );
      },
    );
  }

  /// 支付信息
  Widget paymentInfoWidget() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.end,
      mainAxisAlignment: MainAxisAlignment.end,
      children: [
        // 开启用水按钮
        deviceDrinkBtnWidget(context),

        SizedBox(height: 20),
      ],
    );
  }

  // 显示更多功能的底部弹窗
  void _showMoreFunctionsBottomSheet(BuildContext context) {
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
                    decoration: BoxDecoration(
                      color: Colors.grey[300],
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                  Padding(
                    padding: EdgeInsets.all(16),
                    child: Text(
                      '更多功能',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  ListTile(
                    leading: Icon(Ionicons.grid_outline, color: Colors.blue),
                    title: Text('设备管理'),
                    onTap: () {
                      Navigator.pop(context);
                      _showDeviceManagementSheet(context);
                    },
                  ),
                  ListTile(
                    leading: Icon(
                      Ionicons.add_circle_outline,
                      color: Colors.blue,
                    ),
                    title: Text('添加设备'),
                    onTap: () {
                      Navigator.pop(context);
                      _showAddDeviceOptions(context);
                    },
                  ),
                  SizedBox(height: 20),
                ],
              ),
            ),
          ),
    );
  }

  // 设备管理底部弹窗
  void _showDeviceManagementSheet(BuildContext context) {
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
                    decoration: BoxDecoration(
                      color: Colors.grey[300],
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                  Padding(
                    padding: EdgeInsets.all(16),
                    child: Text(
                      '设备管理',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  SizedBox(
                    height: MediaQuery.of(context).size.height * 0.4,
                    child: StatefulBuilder(
                      builder: (context, setState) {
                        if (logic.state.deviceList.isEmpty) {
                          return Padding(
                            padding: EdgeInsets.all(20),
                            child: Center(
                              child: Column(
                                children: [
                                  Icon(Ionicons.water_outline, size: 48),
                                  SizedBox(height: 10),
                                  Text('暂无收藏设备，请先添加设备'),
                                ],
                              ),
                            ),
                          );
                        }

                        return ListView.builder(
                          itemCount: logic.state.deviceList.length,
                          itemBuilder: (context, i) {
                            return Padding(
                              padding: EdgeInsets.symmetric(
                                horizontal: 16,
                                vertical: 4,
                              ),
                              child: Card(
                                elevation: 0,
                                color:
                                    Theme.of(
                                      context,
                                    ).colorScheme.surfaceContainer,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(10),
                                  // side: BorderSide(color: Colors.grey[200]!, width: 0),
                                ),
                                child: ListTile(
                                  contentPadding: EdgeInsets.symmetric(
                                    horizontal: 16,
                                    vertical: 8,
                                  ),
                                  title: Text(
                                    logic.formatDeviceName(
                                      logic.state.deviceList[i]["name"],
                                    ),
                                    style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 16,
                                    ),
                                  ),
                                  subtitle: Text(
                                    'ID: ${logic.state.deviceList[i]["id"]}',
                                  ),
                                  trailing: IconButton(
                                    icon: Icon(
                                      Ionicons.remove_circle_outline,
                                      color: Colors.red,
                                    ),
                                    onPressed: () {
                                      showDialog(
                                        context: context,
                                        builder:
                                            (context) => AlertDialog(
                                              title: Text('确认删除'),
                                              content: Text(
                                                '确定要删除设备"${logic.formatDeviceName(logic.state.deviceList[i]["name"])}"吗？',
                                              ),
                                              actions: [
                                                TextButton(
                                                  onPressed: () {
                                                    Navigator.pop(context);
                                                  },
                                                  child: Text('取消'),
                                                ),
                                                TextButton(
                                                  onPressed: () {
                                                    logic.favoDevice(
                                                      logic
                                                          .state
                                                          .deviceList[i]["id"]
                                                          .toString(),
                                                      true,
                                                      context,
                                                    );
                                                    logic.removeDeviceByName(
                                                      logic
                                                          .state
                                                          .deviceList[i]["name"],
                                                    );
                                                    setState(() {});
                                                    Navigator.pop(context);
                                                  },
                                                  style: TextButton.styleFrom(
                                                    foregroundColor: Colors.red,
                                                  ),
                                                  child: Text('删除'),
                                                ),
                                              ],
                                            ),
                                      );
                                    },
                                  ),
                                ),
                              ),
                            );
                          },
                        );
                      },
                    ),
                  ),
                  Padding(
                    padding: EdgeInsets.all(16),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        TextButton(
                          onPressed: () {
                            Navigator.pop(context);
                          },
                          child: Text('确认'),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
    );
  }

  // 显示添加设备选项
  void _showAddDeviceOptions(BuildContext context) {
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
                    decoration: BoxDecoration(
                      color: Colors.grey[300],
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                  Padding(
                    padding: EdgeInsets.all(16),
                    child: Text(
                      '添加设备',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  Padding(
                    padding: EdgeInsets.all(20),
                    child: Column(
                      children: [
                        Container(
                          decoration: BoxDecoration(
                            color:
                                Theme.of(context).colorScheme.surfaceContainer,
                            borderRadius: BorderRadius.circular(10),
                          ),
                          padding: EdgeInsets.all(20),
                          child: Row(
                            children: [
                              Icon(
                                Ionicons.information_circle_outline,
                                color: Theme.of(context).colorScheme.primary,
                                size: 24,
                              ),
                              SizedBox(width: 10),
                              Expanded(
                                child: Text(
                                  '扫描设备上的二维码，添加到您的设备列表',
                                  style: TextStyle(
                                    color:
                                        Theme.of(context).colorScheme.primary,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                        SizedBox(height: 30),
                        FilledButton.icon(
                          onPressed: () async {
                            Navigator.pop(context);
                            await _scanQRCodeAndAddDevice(context);
                          },
                          icon: Icon(Ionicons.scan_outline, size: 24),
                          label: Text(
                            '扫描设备二维码',
                            style: TextStyle(fontSize: 16),
                          ),
                          style: ButtonStyle(
                            padding: WidgetStatePropertyAll(
                              EdgeInsets.symmetric(
                                vertical: 16,
                                horizontal: 24,
                              ),
                            ),
                          ),
                        ),
                        SizedBox(height: 20),
                      ],
                    ),
                  ),
                  Padding(
                    padding: EdgeInsets.all(16),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        TextButton(
                          onPressed: () {
                            Navigator.pop(context);
                          },
                          child: Text('取消'),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
    );
  }

  // 扫描二维码并添加设备
  Future<bool> _scanQRCodeAndAddDevice(BuildContext context) async {
    try {
      final result = await Get.to(() => QRCodeScannerPage());

      if (result != null) {
        try {
          String enc = (result as Barcode).code!;
          enc = enc.split("/").last;

          // 添加设备
          bool isFavo = await logic.favoDevice(enc, false, context);

          // 使用GetX显示结果提示
          Get.snackbar(
            isFavo ? '成功' : '失败',
            isFavo ? '设备添加成功！' : '设备添加失败，请重试',
            snackPosition: SnackPosition.BOTTOM,
            backgroundColor: isFavo ? Colors.green : Colors.red,
            colorText: Colors.white,
            duration: Duration(seconds: 3),
            margin: EdgeInsets.all(10),
            borderRadius: 10,
            icon: Icon(
              isFavo ? Icons.check_circle : Icons.error,
              color: Colors.white,
            ),
          );

          // 刷新设备列表
          if (isFavo) {
            await logic.getDeviceList();
          }
        } catch (e) {
          print('添加设备出错: $e');
          // 使用GetX显示错误提示
          Get.snackbar(
            '错误',
            '添加设备时出错: $e',
            snackPosition: SnackPosition.BOTTOM,
            backgroundColor: Colors.red,
            colorText: Colors.white,
            duration: Duration(seconds: 3),
            margin: EdgeInsets.all(10),
            borderRadius: 10,
            icon: Icon(Icons.error, color: Colors.white),
          );
        }
      }
    } catch (e) {
      print('扫描二维码出错: $e');
      // 使用GetX显示错误提示
      Get.snackbar(
        '错误',
        '扫描二维码出错',
        snackPosition: SnackPosition.BOTTOM,
        backgroundColor: Colors.red,
        colorText: Colors.white,
        duration: Duration(seconds: 3),
        margin: EdgeInsets.all(10),
        borderRadius: 10,
        icon: Icon(Icons.error, color: Colors.white),
      );
    }
    return true;
  }

  // 旧版的QRScannerPage方法，不再使用
  Widget QRScannerPage() {
    // 这个方法已不再使用，被QRCodeScannerPage类替代
    return SizedBox();
  }

  // 旧版设备管理对话框 - 已经不再使用，由上面的方法替代
  void _showDeviceManagementDialog(BuildContext context) {
    _showDeviceManagementSheet(context);
  }
}

// 自定义二维码扫描页面
class QRCodeScannerPage extends StatefulWidget {
  @override
  State<QRCodeScannerPage> createState() => _QRCodeScannerPageState();
}

class _QRCodeScannerPageState extends State<QRCodeScannerPage> {
  final GlobalKey qrKey = GlobalKey(debugLabel: 'QR');
  final scanArea = 300.0;
  QRViewController? controller;
  bool _isFlashOn = false;

  @override
  void dispose() {
    controller?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('扫描设备二维码', style: TextStyle(color: Colors.white)),
        backgroundColor: Colors.transparent,
        elevation: 0,
        iconTheme: IconThemeData(color: Colors.white),
      ),
      body: Stack(
        children: [
          QRView(
            key: qrKey,
            onQRViewCreated: _onQRViewCreated,
            overlay: QrScannerOverlayShape(
              borderColor: Colors.blue,
              borderRadius: 10,
              borderLength: 30,
              borderWidth: 10,
              cutOutSize: scanArea,
              overlayColor: Color.fromRGBO(0, 0, 0, 0.7),
            ),
          ),
          Positioned(
            bottom: 40,
            left: 0,
            right: 0,
            child: Column(
              children: [
                Container(
                  margin: EdgeInsets.symmetric(horizontal: 40),
                  padding: EdgeInsets.symmetric(horizontal: 20, vertical: 15),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.8),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        Ionicons.information_circle_outline,
                        color: Colors.blue,
                      ),
                      SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          '将二维码放入框内，即可自动扫描',
                          style: TextStyle(fontSize: 14, color: Colors.black87),
                        ),
                      ),
                    ],
                  ),
                ),
                SizedBox(height: 20),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    TextButton.icon(
                      onPressed: () {
                        setState(() {
                          _isFlashOn = !_isFlashOn;
                        });
                        controller?.toggleFlash();
                      },
                      icon: Icon(
                        _isFlashOn
                            ? Ionicons.flashlight
                            : Ionicons.flashlight_outline,
                        color: Colors.white,
                        size: 24,
                      ),
                      label: Text(
                        _isFlashOn ? '关闭闪光灯' : '打开闪光灯',
                        style: TextStyle(color: Colors.white),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  void _onQRViewCreated(QRViewController controller) {
    this.controller = controller;
    controller.scannedDataStream.listen((scanData) {
      if (scanData.code != null) {
        controller.pauseCamera();
        Navigator.pop(context, scanData);
      }
    });
  }
}

// 气泡动画组件
class BubbleAnimation extends StatefulWidget {
  final bool isActive;

  const BubbleAnimation({Key? key, required this.isActive}) : super(key: key);

  @override
  State<BubbleAnimation> createState() => _BubbleAnimationState();
}

class _BubbleAnimationState extends State<BubbleAnimation>
    with TickerProviderStateMixin {
  List<Bubble> bubbles = [];
  Timer? _timer;
  final Random _random = Random();

  @override
  void initState() {
    super.initState();
    if (widget.isActive) {
      _startAnimation();
    }
  }

  @override
  void didUpdateWidget(BubbleAnimation oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.isActive != oldWidget.isActive) {
      if (widget.isActive) {
        _startAnimation();
      } else {
        _stopAnimation();
      }
    }
  }

  void _startAnimation() {
    _timer = Timer.periodic(Duration(milliseconds: 300), (timer) {
      if (mounted) {
        setState(() {
          // 限制最大气泡数量
          if (bubbles.length < 60) {
            bubbles.add(
              Bubble(
                x: _random.nextDouble() * MediaQuery.of(context).size.width,
                size: _random.nextDouble() * 40 + 15,
                speed: _random.nextDouble() * 1.5 + 0.8,
                vsync: this,
                onComplete: () {
                  setState(() {
                    bubbles.removeWhere((bubble) => bubble.isCompleted);
                  });
                },
              ),
            );
          }
        });
      }
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
    return Stack(
      children:
          bubbles.map((bubble) {
            return AnimatedBuilder(
              animation: bubble.controller,
              builder: (context, child) {
                return Positioned(
                  left: bubble.x + bubble.horizontalOffset,
                  bottom: bubble.y,
                  child: Opacity(
                    opacity: bubble.opacity,
                    child: Container(
                      width: bubble.size,
                      height: bubble.size,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        gradient: LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: [
                            Colors.blue.withAlpha(60),
                            Colors.blue.withAlpha(120),
                          ],
                        ),
                        border: Border.all(
                          color: Colors.blue.withAlpha(80),
                          width: 1,
                        ),
                      ),
                    ),
                  ),
                );
              },
            );
          }).toList(),
    );
  }
}

class Bubble {
  final double x;
  final double size;
  final double speed;
  late AnimationController controller;
  late Animation<double> yAnimation;
  late Animation<double> opacityAnimation;
  late Animation<double> horizontalAnimation;
  final VoidCallback onComplete;
  bool isCompleted = false;

  Bubble({
    required this.x,
    required this.size,
    required this.speed,
    required TickerProvider vsync,
    required this.onComplete,
  }) {
    controller = AnimationController(
      duration: Duration(seconds: (4 / speed).round()),
      vsync: vsync,
    );

    yAnimation = Tween<double>(
      begin: 0,
      end: 1000,
    ).animate(CurvedAnimation(parent: controller, curve: Curves.easeOut));

    opacityAnimation = Tween<double>(
      begin: 0.6,
      end: 0,
    ).animate(CurvedAnimation(parent: controller, curve: Curves.easeOut));

    // 添加水平方向的轻微摆动
    horizontalAnimation = Tween<double>(
      begin: 0,
      end: Random().nextDouble() * 40 - 20, // -20 到 20 之间的随机值
    ).animate(CurvedAnimation(parent: controller, curve: Curves.easeInOut));

    controller.forward().then((_) {
      isCompleted = true;
      onComplete();
    });
  }

  double get y => yAnimation.value;

  double get opacity => opacityAnimation.value;

  double get horizontalOffset => horizontalAnimation.value;
}
