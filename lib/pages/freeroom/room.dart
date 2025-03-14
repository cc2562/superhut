import 'package:enhanced_future_builder/enhanced_future_builder.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:ionicons/ionicons.dart';
import 'package:loading_animation_widget/loading_animation_widget.dart';
import 'package:modal_bottom_sheet/modal_bottom_sheet.dart';
import 'package:superhut/pages/freeroom/buildingBridge.dart';

class FreeRoomPage extends StatefulWidget {
  final String buildingId,buildingName;
  const FreeRoomPage({super.key,required this.buildingId,required this.buildingName});

  @override
  State<FreeRoomPage> createState() => _FreeRoomPageState();
}

class _FreeRoomPageState extends State<FreeRoomPage> {
  int count = 12;
  String nodeId="0102";
  String date=DateFormat('yyyy-MM-dd').format(DateTime.now());
  double startLesson = 1.0; // 默认起始节次
  double endLesson = 2.0;   // 默认结束节次

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).colorScheme.surface,
      appBar: AppBar(title:  Text(widget.buildingName)),
      body: EnhancedFutureBuilder(
          future: getRoom(date, nodeId, widget.buildingId, false),
          rememberFutureResult: false,
          whenDone: (data){
        return Flex(
          direction: Axis.vertical,
          children: [
            Padding(
              padding: EdgeInsets.only(left: 10,right: 10),
              child: Flex(
                direction: Axis.horizontal,
                children: [
                  Expanded(
                    child: Row(
                      children: [
                        Text('日期'),
                        TextButton(onPressed: () async {
                          var result = await showDatePicker(
                            locale: Locale('zh'),
                            context: context,
                            initialDate: DateTime.now(),
                            firstDate: DateTime(DateTime.now().year - 2, DateTime.now().month, DateTime.now().day),
                            lastDate: DateTime(DateTime.now().year + 2, DateTime.now().month, DateTime.now().day),
                          );
                          if (result != null) {
                            setState(() {
                              date = DateFormat('yyyy-MM-dd').format(result);
                            });
                          }
                        }, child: Text(
                          DateFormat('yyyy年MM月dd日').format(DateTime.parse(date)),
                        ),
                        )
                      ],
                    ),
                  ),
                  Expanded(
                    child: Row(
                      children: [
                        Text('节次'),
                        TextButton(
                          onPressed: () async {
                            showCupertinoModalBottomSheet(context: context,
                                builder:(context){
                                  return Material(
                                    child: StatefulBuilder(
                                      builder: (context, setState) {
                                        return Stack(
                                          children: [
                                            Container(
                                              padding: EdgeInsets.all(20),
                                              child: Column(
                                                crossAxisAlignment: CrossAxisAlignment.start,
                                                mainAxisSize: MainAxisSize.min,
                                                children: [
                                                  Container(
                                                    child: Text(
                                                      '选择节次范围',
                                                      style:
                                                      Theme.of(
                                                        context,
                                                      ).textTheme.titleLarge,
                                                    ),
                                                  ),
                                                  SizedBox(height: 10),
                                                  RangeSlider(
                                                    values: RangeValues(startLesson, endLesson),
                                                    min: 1.0,
                                                    max: 12.0,
                                                    divisions: 11,
                                                    labels: RangeLabels(
                                                      startLesson.round().toString(),
                                                      endLesson.round().toString(),
                                                    ),
                                                    onChanged: (RangeValues values) {
                                                      setState(() {
                                                        startLesson = values.start;
                                                        endLesson = values.end;
                                                      });
                                                    },
                                                    onChangeEnd: (RangeValues values) {
                                                      setState(() {
                                                        startLesson = values.start;
                                                        endLesson = values.end;
                                                        nodeId = '${startLesson.toStringAsFixed(0).padLeft(2, '0')}${endLesson.toStringAsFixed(0).padLeft(2, '0')}';
                                                      });
                                                    },
                                                  ),
                                                  Row(
                                                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                                    children: [
                                                      Text('第1节'),
                                                      Text('第12节'),
                                                    ],
                                                  ),
                                                  SizedBox(height: 50),
                                                ],
                                              ),
                                            )
                                          ],
                                        );
                                      },
                                    ),
                                  );
                                }
                            ).then(
                                  (value) {
                                setState(() {
                                  startLesson = startLesson;
                                  endLesson = endLesson;
                                  nodeId = '${startLesson.toStringAsFixed(0).padLeft(2, '0')}${endLesson.toStringAsFixed(0).padLeft(2, '0')}';
                                });
                              },
                            );
                          },
                          child: Text(
                            '${startLesson.round()}-${endLesson.round()}节', // 动态更新为用户选择的范围
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: SingleChildScrollView(
                child: Column(
                  children: [
                    ListView.builder(
                      physics: NeverScrollableScrollPhysics(),
                      shrinkWrap: true,
                      itemCount: data.length,
                      itemBuilder: (context, index) {
                        return Card.filled(
                          color: Theme.of(context).colorScheme.surfaceContainer,
                          child: InkWell(
                            onTap: () {
                              showCupertinoModalBottomSheet(
                                expand: false,
                                context: context,
                                builder:
                                    (context) => Material(
                                  child: Stack(
                                    children: [
                                      Container(
                                        padding: EdgeInsets.fromLTRB(
                                          20,
                                          20,
                                          20,
                                          10,
                                        ),
                                        height: 350,
                                        child: ListView(
                                          physics:
                                          NeverScrollableScrollPhysics(),
                                          children: [
                                            Container(
                                              child: Text(
                                                data[index].name,
                                                style:
                                                Theme.of(
                                                  context,
                                                ).textTheme.titleLarge,
                                              ),
                                            ),
                                            SizedBox(height: 10),

                                            Container(
                                              child: Flex(
                                                direction: Axis.horizontal,
                                                children: List.generate(
                                                  count, // 动态数量，例如设置为7，则会生成7个
                                                      (indexs){

                                                        String slot = (indexs + 1).toString().padLeft(2, '0');
                                                        bool isBooked = data[index].free.contains(slot);
                                                    return Expanded(
                                                      child: Container(
                                                        height: 40,
                                                        decoration: BoxDecoration(
                                                          color:
                                                          isBooked
                                                              ? Theme.of(context).colorScheme.primary
                                                              : Theme.of(context).colorScheme.secondaryContainer,
                                                          borderRadius: BorderRadius.only(
                                                            topLeft:
                                                            indexs == 0
                                                                ? Radius.circular(
                                                              10,
                                                            )
                                                                : Radius
                                                                .zero,
                                                            bottomLeft:
                                                            indexs == 0
                                                                ? Radius.circular(
                                                              10,
                                                            )
                                                                : Radius
                                                                .zero,
                                                            topRight:
                                                            indexs ==
                                                                count - 1
                                                                ? Radius.circular(
                                                              10,
                                                            )
                                                                : Radius
                                                                .zero,
                                                            // 最后一个索引为 count - 1
                                                            bottomRight:
                                                            indexs == count - 1
                                                                ? Radius.circular(
                                                              10,
                                                            )
                                                                : Radius
                                                                .zero,
                                                          ),
                                                        ),
                                                        child: Center(
                                                          child: Text(
                                                            '${indexs + 1}',
                                                            // 动态显示数字，从1开始
                                                            style: TextStyle(
                                                              color:
                                                              Theme.of(
                                                                context,
                                                              )
                                                                  .colorScheme
                                                                  .onPrimary,
                                                            ),
                                                          ),
                                                        ),
                                                      ),
                                                    );
                                                      }
                                                ),
                                              ),
                                            ),
                                            SizedBox(height: 10,),
                                            Row(
                                              crossAxisAlignment: CrossAxisAlignment.center,
                                              mainAxisAlignment: MainAxisAlignment.end,
                                              children: [
                                                Container(
                                                    width: 15,
                                                    height: 15,
                                                    decoration: BoxDecoration(
                                                      color: Theme.of(context).colorScheme.primary,
                                                      borderRadius: BorderRadius.circular(100),
                                                    )
                                                ),
                                                SizedBox(width: 5,),
                                                Text('不空闲'),
                                                SizedBox(width: 10,),
                                                Container(
                                                    width: 15,
                                                    height: 15,
                                                    decoration: BoxDecoration(
                                                      color: Theme.of(context).colorScheme.secondaryContainer,
                                                      borderRadius: BorderRadius.circular(100),
                                                    )
                                                ),
                                                SizedBox(width: 5,),
                                                Text('空闲'),
                                              ],
                                            ),
                                            ListTile(
                                              leading: Icon(Ionicons.location_outline),
                                              title: Text(
                                                '${data[index].name}',
                                              ),
                                            ),
                                            ListTile(
                                              leading: Icon(Ionicons.happy_outline),
                                              title: Text(
                                                '座位数：${data[index].seatNumber}',
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              );
                            },
                            child: Padding(
                              padding: EdgeInsets.all(10),
                              child: Flex(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                direction: Axis.horizontal,
                                children: [
                                  Expanded(
                                    flex: 10,
                                    child: Column(
                                      crossAxisAlignment:
                                      CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          data[index].name,
                                          style: TextStyle(
                                            fontSize: 18,
                                            fontWeight: FontWeight.bold,
                                            color: Theme.of(context).primaryColor,
                                          ),
                                        ),
                                        Row(
                                          children: [
                                            Chip(
                                              label: Text(
                                                '总座位数：${data[index].seatNumber}',
                                                style: TextStyle(fontSize: 12),
                                              ),
                                              backgroundColor:
                                              Theme.of(
                                                context,
                                              ).colorScheme.surface,
                                              padding: EdgeInsets.symmetric(
                                                vertical: 0,
                                                horizontal: 0,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        );
                      },
                    ),
                  ],
                ),
              ),
            ),
          ],
        );
          },
          whenNotDone: Center(child: LoadingAnimationWidget.inkDrop(color: Theme.of(context).primaryColor, size: 40),)),
    );
  }
}