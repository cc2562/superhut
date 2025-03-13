import 'package:flutter/material.dart';

import 'package:get/get.dart';
import 'package:ionicons/ionicons.dart';

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
        title: Text('喝水'),
        actions: [
          IconButton(
            onPressed: () {
              showDialog(
                context: context,
                barrierDismissible: false,
                builder: (context) {
                  return AlertDialog(
                    title: Text('设备管理'),
                    content: SizedBox(
                      width:
                      200,
                      child: StatefulBuilder(builder: (context, setState) {
                        List<Widget> widget = [];
                        for (int i = 0;
                        i < logic.state.deviceList.length;
                        i++) {
                          widget.add(
                              PopupMenuButton(
                                position: PopupMenuPosition.under,
                                offset: Offset(100, 0),
                                itemBuilder: (BuildContext context) {
                                  List<PopupMenuEntry> widget = [];
                                  widget.add(
                                    PopupMenuItem(
                                      value: 0,
                                      child: Text('取消收藏'),
                                    ),
                                  );
                                  return widget;
                                },
                                child: ListTile(
                                  title: Text(
                                    logic.formatDeviceName(
                                        logic.state.deviceList[i]["name"]),
                                  ),
                                  trailing: const Icon(Icons.more_vert_rounded),
                                ),
                                onSelected: (select) {
                                  if (select == 0) {
                                    logic.favoDevice(
                                        logic.state.deviceList[i]["id"]
                                            .toString(),
                                        true,context);
                                    logic.removeDeviceByName(
                                        logic.state.deviceList[i]["name"]);
                                    widget.remove(this);
                                    setState(() {});
                                  }
                                },
                              ));
                        }

                        return ListView(
                          shrinkWrap: true,
                          children: widget,
                        );
                      }),
                    ),
                    actions: [
                      TextButton(
                        onPressed: () {
                          Get.back();
                        },
                        child: Text('确认'),
                      ),
                    ],
                  );
                },
              );
            },
            icon:Icon(Ionicons.grid_outline),
          ),
          // 添加设备
          FilledButton.icon(
            onPressed: () {
              logic.scanQRCode(context);
            },
            icon: const Icon(Ionicons.add_circle_outline),
            label: Text('添加设备'),
          ),

          // token管理

        ],
      ),
      body: Column(
        children: [
          // 获取选择饮水设备按钮
          deviceDrinkRowBtnWidget(),
          Center(
            child: deviceDrinkBtnWidget(context),
          ),
        ],
      ),
    );
  }

  /// 获取选择饮水设备按钮
  Widget deviceDrinkRowBtnWidget() {
    return Padding(
      padding: EdgeInsets.only(
        top: 10,
      ),
      child: GetBuilder<FunctionDrinkLogic>(builder: (logic) {
        List<ButtonSegment<int>> list = [];
        for (int i = 0; i < logic.state.deviceList.length && i < 4; i++) {
          list.add(
            ButtonSegment(
              label: Text(
                logic.formatDeviceName(logic.state.deviceList[i]["name"]),
                style: TextStyle(
                  fontSize: 20,
                ),
              ),
              value: i,
            ),
          );
        }

        // 如果列表为空默认
        if (list.isEmpty) {
          return const SizedBox();
        }

        return SegmentedButton(
          showSelectedIcon: false,
          style: ButtonStyle(
            padding: WidgetStateProperty.all(
              EdgeInsets.symmetric(
                horizontal: 20,
              ),
            ),
          ),
          segments: list,
          selected: {logic.state.choiceDevice.value},
          onSelectionChanged: (Set<int> newSelected) {
            if (logic.state.drinkStatus.value) {
              return;
            }
            logic.setChoiceDevice(newSelected.first);
          },
        );
      }),
    );
  }

  /// 获取饮水按钮
  Widget deviceDrinkBtnWidget(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        top: 20,
      ),
      child: GetBuilder<FunctionDrinkLogic>(builder: (logic) {
        return ElevatedButton(
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
            elevation: WidgetStateProperty.all(0),
            shape: WidgetStateProperty.all(
              RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(1000),
              ),
            ),
            fixedSize: WidgetStateProperty.all(
              Size(
                  300,300
              ),
            ),
          ),
          child: Text(
            logic.state.drinkStatus.value
                ? '结算'
                : '喝水',
            style: TextStyle(
              fontSize: 30,
            ),
          ),
        );
      }),
    );
  }

  /// 获取设置按钮
  Widget settingFloatBtn(BuildContext context) {
    return GetBuilder<FunctionDrinkLogic>(
      builder: (logic) {
        return Row(
          children: [
            // 设备管理
            IconButton(
              onPressed: () {
                showDialog(
                  context: context,
                  barrierDismissible: false,
                  builder: (context) {
                    return AlertDialog(
                      title:
                      Text('Token管理'),
                      content: TextField(
                        controller: logic.state.tokenController,
                        decoration: InputDecoration(
                          labelText:'Token',
                        ),
                      ),
                      actions: [
                        TextButton(
                          onPressed: () {
                            Get.back();
                          },
                          child: Text('取消'),
                        ),
                        TextButton(
                          onPressed: () {
                            logic.setToken(logic.state.tokenController.text);
                            Get.back();
                          },
                          child: Text('确认'),
                        ),
                      ],
                    );
                  },
                );
              },
              icon: const Icon(Ionicons.key_outline),
            ),
          ],
        );
      },
    );
  }
}

