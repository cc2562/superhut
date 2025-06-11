import 'package:enhanced_future_builder/enhanced_future_builder.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:ionicons/ionicons.dart';
import 'package:loading_animation_widget/loading_animation_widget.dart';
import 'package:modal_bottom_sheet/modal_bottom_sheet.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../utils/hut_user_api.dart';
import 'electricityApi.dart';

class ElectricityPage extends StatefulWidget {
  const ElectricityPage({super.key});

  @override
  State<ElectricityPage> createState() => _ElectricityPageState();
}

class _ElectricityPageState extends State<ElectricityPage> {
  String setRoomName = "未知房间";
  String nowRoomId = '';
  String roomCount = '-';
  var electricityApi = ElectricityApi();
  Map baseInfo = {}, nowRoomInfo = {};
  final hutUserApi = HutUserApi();
  String balance = "-";
  bool isRoomLoading = false, isinit = false;
  final TextEditingController _paymentController = TextEditingController();

  @override
  void dispose() {
    // TODO: implement dispose
    _paymentController.dispose();
    super.dispose();
  }

  /// 获取余额

  @override
  void initState() {
    // TODO: implement initState
    super.initState();
    getBalance();
  }

  Future<void> getBalance() async {
    await hutUserApi.getCardBalance().then((value) {
      balance = value.toString() ?? '--';
      setState(() {
        balance = balance;
      });
    });
  }

  Future<bool> getHisRoomInfo() async {
    if (isinit) {
      return true;
    }
    //初始化API
    await electricityApi.onInit();
    baseInfo = await electricityApi.getHistory();
    print("the base::::$baseInfo");
    nowRoomInfo = await electricityApi.getSingleRoomInfo(baseInfo["roomid"]);
    print("the now::::$nowRoomInfo");
    setState(() {
      setRoomName = nowRoomInfo["roomName"];
      roomCount = nowRoomInfo["eleTail"];
      nowRoomId = baseInfo["roomid"];
    });
    isinit = true;
    return true;
  }

  Future<bool> getNewRoomInfo(String roomIds) async {
    nowRoomInfo = await electricityApi.getSingleRoomInfo(roomIds);
    print("the now::::$nowRoomInfo");
    setState(() {
      setRoomName = nowRoomInfo["roomName"];
      roomCount = nowRoomInfo["eleTail"];
      nowRoomId = roomIds;
    });
    setState(() {
      setRoomName = nowRoomInfo["roomName"];
      roomCount = nowRoomInfo["eleTail"];
      nowRoomId = roomIds;
    });

    return true;
  }

  Future<List> getRoomList() async {
    List roomList = await electricityApi.getRoomList();
    print(roomList);
    return roomList;
  }

  //充值逻辑处理
  Future<bool> chargeMoney() async {
    //确认充值房间
    var _roomToChargeName = setRoomName;
    var _roomToChargeId = nowRoomId;
    var _payment = _paymentController.text;
    _paymentController.clear();
    print("the roomToCharge::::$_roomToChargeName");
    print("the roomToChargeId::::$_roomToChargeId");
    print("the payment::::$_payment");
    //充值前检测
    if (double.parse(balance) < double.parse(_payment)) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('余额不足')));
      return false;
    }
    //二次检测
    bool firstCheck = await electricityApi.checkBeforeRecharge(_roomToChargeId);
    if (firstCheck != true) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('未知错误')));
      return false;
    }
    //创建订单
    Map _orderInfo = await electricityApi.createOrder(
      _roomToChargeId,
      _payment,
      _roomToChargeName,
    );
    print("the orderInfo::::$_orderInfo");
    //完成充值
    electricityApi.finishRecharge(
      _orderInfo['payorderno'],
      _payment,
      _roomToChargeName,
    );
    //充值成功
    getNewRoomInfo(_roomToChargeId);
    getBalance();
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('充值成功')));
    return true;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).colorScheme.surface,
      appBar: AppBar(
        title: Text('电费充值'),
        elevation: 0,
        backgroundColor: Colors.transparent,
      ),
      body: Container(
        padding: EdgeInsets.fromLTRB(12, 0, 12, 0),
        child: ListView(
          children: [
            Container(
              padding: EdgeInsets.all(16),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(16),
                color: Colors.blue.shade100,
              ),
              child: EnhancedFutureBuilder(
                future: getHisRoomInfo(),
                rememberFutureResult: true,
                whenDone: (v) {
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Row(
                            children: [
                              Text(
                                setRoomName,
                                style: TextStyle(
                                  fontWeight: FontWeight.w500,
                                  color: Colors.black,
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
                            roomCount,
                            style: TextStyle(
                              fontSize: 32,
                              fontWeight: FontWeight.bold,
                              color: Colors.black,
                            ),
                          ),
                          SizedBox(width: 5),
                          Text(
                            'CNY',
                            style: TextStyle(
                              fontSize: 32,
                              fontWeight: FontWeight.w100,
                              color: Colors.black.withAlpha(150),
                            ),
                          ),
                        ],
                      ),
                    ],
                  );
                },
                whenNotDone: Center(
                  child: LoadingAnimationWidget.inkDrop(
                    color: Theme.of(context).primaryColor,
                    size: 40,
                  ),
                ),
              ),
            ),
            SizedBox(height: 12),
            Container(
              padding: EdgeInsets.all(16),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(16),
                color: Colors.green.shade100,
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
                            '通过校园卡充值',
                            style: TextStyle(
                              fontWeight: FontWeight.w500,
                              color: Colors.black,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                  SizedBox(height: 8),
                  TextField(
                    controller: _paymentController,
                    keyboardType: TextInputType.numberWithOptions(
                      decimal: true,
                    ),
                    style: TextStyle(fontSize: 32),
                    maxLength: 10,
                    inputFormatters: [
                      FilteringTextInputFormatter.allow(RegExp(r'[\d.]')),
                      DecimalTextInputFormatter(),
                    ],
                    decoration: InputDecoration(
                      filled: false,
                      hintText: "输入充值金额",
                      border: InputBorder.none,
                      counterText: '',
                    ),
                  ),
                  Row(
                    children: [
                      Text(
                        '校园卡余额:',
                        style: TextStyle(
                          fontSize: 16,
                          color: Colors.black,
                          fontWeight: FontWeight.normal,
                        ),
                      ),
                      Text(
                        balance,
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.normal,
                          color: Colors.black,
                        ),
                      ),
                    ],
                  ),
                  TextButton(
                    onPressed: () async {
                      //_launchUrl();
                      if (_paymentController.text.isEmpty) {
                        ScaffoldMessenger.of(
                          context,
                        ).showSnackBar(SnackBar(content: Text('充值金额不能为空')));
                        return;
                      }
                      // 层级校验 2: 数字格式校验
                      final amount = double.tryParse(_paymentController.text);
                      if (amount == null) {
                        ScaffoldMessenger.of(
                          context,
                        ).showSnackBar(SnackBar(content: Text('请输入有效的数字格式')));
                        return;
                      }

                      // 层级校验 3: 正数校验
                      if (amount <= 0) {
                        ScaffoldMessenger.of(
                          context,
                        ).showSnackBar(SnackBar(content: Text('金额必须大于0元')));
                        return;
                      }

                      // 层级校验 4: 小数位校验
                      final decimalPattern = RegExp(r'^-?\d+(\.\d{1,2})?$');
                      if (!decimalPattern.hasMatch(_paymentController.text)) {
                        ScaffoldMessenger.of(
                          context,
                        ).showSnackBar(SnackBar(content: Text('最多支持两位小数')));
                        return;
                      }

                      // 层级校验 5: 最大金额限制
                      const maxAmount = 10000.0;
                      if (amount > maxAmount) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text('单次充值不能超过$maxAmount元')),
                        );
                        return;
                      }

                      bool statue = await chargeMoney();
                      isinit = false;
                      getHisRoomInfo();
                    },
                    style: ButtonStyle(
                      backgroundColor: WidgetStateProperty.all(
                        Colors.green.shade200,
                      ),
                      foregroundColor: WidgetStateProperty.all(Colors.white),
                      shape: WidgetStateProperty.all(
                        RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                      ),
                    ),
                    child: Text('充值'),
                  ),
                ],
              ),
            ),
            SizedBox(height: 12),
            Container(
              margin: EdgeInsets.only(bottom: 12),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.surfaceContainer,
                borderRadius: BorderRadius.circular(16),
              ),
              child: ListTile(
                leading: Icon(
                  Ionicons.grid_outline,
                  color: Theme.of(context).primaryColor,
                ),
                title: Text(
                  "更改充值房间",
                  style: TextStyle(fontWeight: FontWeight.w500),
                ),
                trailing:
                    isRoomLoading
                        ? LoadingAnimationWidget.inkDrop(
                          color: Theme.of(context).primaryColor,
                          size: 20,
                        )
                        : Icon(Icons.chevron_right, color: Colors.grey),
                onTap: () async {
                  setState(() {
                    isRoomLoading = true;
                  });
                  List roomList = await getRoomList();
                  _showAllRoomBottomSheet(context, roomList);
                  setState(() {
                    isRoomLoading = false;
                  });
                },
              ),
            ),
            _buildFunctionItem(
              icon: Ionicons.alert_circle_outline,
              title: "电费预警",
              onTap: () async {
                _showAlertBottomSheet(context);
                // await renewToken(context);
                // print("跳转");
                //Navigator.of(context).push(
                //   MaterialPageRoute(builder: (context) => Getcoursepage(renew: true))
                // );
              },
            ),
          ],
        ),
      ),
    );
  }

  // 显示所有充值房间
  void _showAllRoomBottomSheet(BuildContext context, List RoomList) {
    String searchQuery = ""; // 搜索关键词状态

    showCupertinoModalBottomSheet(
      context: context,
      expand: false,
      backgroundColor: Colors.transparent,
      builder:
          (context) => StatefulBuilder(
            // 使用 StatefulBuilder 管理搜索状态
            builder: (context, setState) {
              // 根据搜索词过滤房间列表
              final filteredRooms =
                  RoomList.where((room) {
                    final name = room['acname'].toString().toLowerCase();
                    final guid = room['acguid'].toString().toLowerCase();
                    final query = searchQuery.toLowerCase();
                    return name.contains(query) || guid.contains(query);
                  }).toList();

              return Material(
                color: Theme.of(context).colorScheme.surface,
                borderRadius: BorderRadius.only(
                  topLeft: Radius.circular(15),
                  topRight: Radius.circular(15),
                ),
                child: SafeArea(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // 顶部拖动指示条
                      Container(
                        width: 40,
                        height: 4,
                        margin: EdgeInsets.symmetric(vertical: 12),
                        decoration: BoxDecoration(
                          color: Colors.grey[300],
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),

                      // 标题
                      Padding(
                        padding: EdgeInsets.all(16),
                        child: Text(
                          '更改房间',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),

                      // 搜索框
                      Padding(
                        padding: EdgeInsets.symmetric(horizontal: 16),
                        child: TextField(
                          decoration: InputDecoration(
                            hintText: '搜索房间名称或ID',
                            prefixIcon: Icon(Icons.search, size: 24),
                            filled: true,
                            fillColor: Colors.grey.withOpacity(0.1),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(10),
                              borderSide: BorderSide.none,
                            ),
                            contentPadding: EdgeInsets.symmetric(vertical: 14),
                          ),
                          onChanged:
                              (value) => setState(() => searchQuery = value),
                        ),
                      ),

                      // 房间列表
                      Container(
                        height: 400,
                        child: ListView.builder(
                          itemCount: filteredRooms.length,
                          itemBuilder: (BuildContext context, int index) {
                            final room = filteredRooms[index];
                            return ListTile(
                              leading: Icon(
                                Ionicons.shapes_outline,
                                color: Colors.blue,
                              ),
                              title: Text(room['acname']),
                              //subtitle: Text(room['acguid']),
                              onTap: () {
                                getNewRoomInfo(room['acguid']);
                                Navigator.pop(context);

                                // 这里可以添加房间选择后的处理逻辑
                              },
                            );
                          },
                        ),
                      ),

                      SizedBox(height: 20),
                    ],
                  ),
                ),
              );
            },
          ),
    );
  }

  //显示预警设置
  // 显示添加设备页面(底部弹窗形式)
  Future<void> _showAlertBottomSheet(BuildContext context) async {
    final TextEditingController deviceCodeController = TextEditingController();
    final prefs = await SharedPreferences.getInstance();
    bool isEnable = prefs.getBool('enableBillWarning') ?? false;
    String RoomId = "", RoomName = "";
    double bill = 0;
    if (isEnable) {
      RoomId = prefs.getString('enableRoomId') ?? '';
      RoomName = prefs.getString('enableRoomName') ?? '';
      bill = prefs.getDouble('enableBill') ?? 0;
    }
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
                      crossAxisAlignment: CrossAxisAlignment.center,
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
                            '电费预警',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                        SizedBox(height: 5),
                        // 输入框
                        TextField(
                          controller: deviceCodeController,
                          decoration: InputDecoration(
                            hintText: '输入预警金额',
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
                              Ionicons.alert_circle_outline,
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
                              String alertCount =
                                  deviceCodeController.text.trim();
                              if (alertCount.isEmpty) {
                                ScaffoldMessenger.of(
                                  context,
                                ).showSnackBar(SnackBar(content: Text('')));
                                return;
                              }
                              prefs.setBool('enableBillWarning', true);
                              prefs.setString('enableRoomId', nowRoomId);
                              prefs.setString('enableRoomName', setRoomName);
                              prefs.setDouble(
                                'enableBill',
                                double.parse(alertCount),
                              );
                              Navigator.pop(context);
                            },
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.orange,
                              foregroundColor: Colors.white,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                            child: Text(
                              isEnable ? '更改预警' : '设置预警',
                              style: TextStyle(fontSize: 18),
                            ),
                          ),
                        ),
                        Visibility(
                          visible: isEnable,
                          child: Column(
                            children: [
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
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      SizedBox(height: 8),
                                      Text(
                                        '目前设置：\n当房间${RoomName}的电费低于${bill}元时进行提醒',
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                              SizedBox(
                                width: double.infinity,
                                height: 50,
                                child: ElevatedButton(
                                  onPressed: () async {
                                    prefs.setBool('enableBillWarning', false);
                                    Navigator.pop(context);
                                  },
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: Colors.orange,
                                    foregroundColor: Colors.white,
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                  ),
                                  child: Text(
                                    '关闭预警',
                                    style: TextStyle(fontSize: 18),
                                  ),
                                ),
                              ),
                            ],
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
                                Text(
                                  '当检测到${setRoomName}的电费小于预警值后，将会在进入超级工大时进行提醒',
                                ),
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

  Widget _buildFunctionItem({
    required IconData icon,
    required String title,
    required VoidCallback onTap,
  }) {
    return Container(
      margin: EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainer,
        borderRadius: BorderRadius.circular(16),
      ),
      child: ListTile(
        leading: Icon(icon, color: Theme.of(context).primaryColor),
        title: Text(title, style: TextStyle(fontWeight: FontWeight.w500)),
        trailing: Icon(Icons.chevron_right, color: Colors.grey),
        onTap: onTap,
      ),
    );
  }
}

class DecimalTextInputFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    final regex = RegExp(r'^(\d+)?\.?\d{0,2}');
    final String newString = regex.stringMatch(newValue.text) ?? '';
    return newString == newValue.text ? newValue : oldValue;
  }
}
