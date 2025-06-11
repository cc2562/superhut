import 'package:enhanced_future_builder/enhanced_future_builder.dart';
import 'package:flutter/material.dart';
import 'package:ionicons/ionicons.dart';
import 'package:loading_animation_widget/loading_animation_widget.dart';
import 'package:superhut/pages/ExamSchedule/exam_schedule_bridge.dart';

class ExamSchedulePage extends StatefulWidget {
  const ExamSchedulePage({super.key});

  @override
  State<ExamSchedulePage> createState() => _ExamSchedulePageState();
}

class _ExamSchedulePageState extends State<ExamSchedulePage> {
  //定义安排MAP
  List examSchedules = [];

  void ShowLoadingDialog() {
    showDialog(
      barrierDismissible: false,
      context: context,
      builder: (context) {
        return PopScope(
          canPop: false,
          child: Dialog(
            backgroundColor: Colors.transparent,
            child: LoadingAnimationWidget.inkDrop(
              color: Theme.of(context).primaryColor,
              size: 40,
            ),
          ),
        );
      },
    );
  }

  Future getExamSchedule() async {
    examSchedules = await getSchedule();
    print(examSchedules);
    return true;
  }

  @override
  void initState() {
    super.initState();
  }

  @override
  Widget build(BuildContext context) {
    return EnhancedFutureBuilder(
      future: getExamSchedule(),
      rememberFutureResult: true,
      whenDone: (da) {
        return Scaffold(
          backgroundColor: Theme.of(context).colorScheme.surface,
          appBar: AppBar(title: Text("考试安排")),
          body: Container(
            margin: EdgeInsets.only(left: 10, right: 10),
            child: ListView.builder(
              itemCount: examSchedules.length,
              itemBuilder: (context, index) {
                print(examSchedules.length);
                if (examSchedules.isEmpty) {
                  return Column(
                    children: [SizedBox(height: 10), Text("当前学期暂时没有考试安排")],
                  );
                } else {
                  var ins = index;
                  // 更健壮的日期规范化函数
                  DateTime? parseExamDate(String input) {
                    try {
                      // 提取日期部分（前10个字符）
                      String datePart = input.substring(0, 10);

                      // 分割日期组件
                      List<String> parts = datePart.split('-');
                      if (parts.length != 3) return null;

                      // 解析为整数
                      int year = int.tryParse(parts[0]) ?? DateTime.now().year;
                      int month = int.tryParse(parts[1]) ?? 1;
                      int day = int.tryParse(parts[2]) ?? 1;

                      // 创建DateTime对象（只保留日期部分）
                      return DateTime(year, month, day);
                    } catch (e) {
                      return null;
                    }
                  }

                  // 解析考试日期
                  DateTime? examDate = parseExamDate(
                    examSchedules[ins]['time'],
                  );

                  // 计算距离考试的天数
                  String daysLeftText = "日期未知";
                  if (examDate != null) {
                    // 获取当前日期（去掉时间部分）
                    DateTime now = DateTime.now();
                    DateTime today = DateTime(now.year, now.month, now.day);

                    // 计算天数差
                    int daysLeft = examDate.difference(today).inDays;

                    // 根据天数差生成文本
                    if (daysLeft == 0) {
                      daysLeftText = "今天考试";
                    } else if (daysLeft > 0) {
                      daysLeftText = "还有${daysLeft}天";
                    } else {
                      daysLeftText = "已结束${-daysLeft}天";
                    }
                  }
                  return Card.filled(
                    color: Theme.of(context).colorScheme.surfaceContainer,
                    child: Padding(
                      padding: EdgeInsets.all(10),
                      child: Flex(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        direction: Axis.horizontal,
                        children: [
                          Expanded(
                            flex: 10,
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  examSchedules[ins]['courseName'],
                                  style: TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.bold,
                                    color:
                                        Theme.of(context).colorScheme.onSurface,
                                  ),
                                ),
                                SizedBox(height: 5),
                                Row(
                                  children: [
                                    Icon(
                                      Ionicons.location,
                                      size: 20,
                                      color: Theme.of(
                                        context,
                                      ).colorScheme.onSurface.withAlpha(100),
                                    ),
                                    SizedBox(width: 5),
                                    Text(
                                      '${examSchedules[ins]['examinationPlace']}',
                                      style: TextStyle(
                                        fontSize: 15,
                                        fontWeight: FontWeight.normal,
                                        color:
                                            Theme.of(
                                              context,
                                            ).colorScheme.onSurface,
                                      ),
                                    ),
                                  ],
                                ),
                                SizedBox(height: 5),
                                Row(
                                  children: [
                                    Icon(
                                      Ionicons.calendar,
                                      size: 20,
                                      color: Theme.of(
                                        context,
                                      ).colorScheme.onSurface.withAlpha(100),
                                    ),
                                    SizedBox(width: 5),
                                    Text(
                                      '${examSchedules[ins]['time']}',
                                      style: TextStyle(
                                        fontSize: 14,
                                        fontWeight: FontWeight.normal,
                                        color:
                                            Theme.of(
                                              context,
                                            ).colorScheme.onSurface,
                                      ),
                                    ),
                                  ],
                                ),
                                SizedBox(height: 5),
                                Row(
                                  children: [
                                    Icon(
                                      Ionicons.timer,
                                      size: 20,
                                      color: Theme.of(
                                        context,
                                      ).colorScheme.onSurface.withAlpha(100),
                                    ),
                                    SizedBox(width: 5),
                                    Text(
                                      daysLeftText,
                                      style: TextStyle(
                                        fontSize: 14,
                                        fontWeight: FontWeight.normal,
                                        color: _getDaysLeftColor(
                                          daysLeftText,
                                          context,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                                SizedBox(height: 10),
                                Row(
                                  crossAxisAlignment: CrossAxisAlignment.end,
                                  mainAxisAlignment: MainAxisAlignment.end,
                                  children: [
                                    Text(
                                      '${examSchedules[ins]['courseNumber']}',
                                      style: TextStyle(
                                        fontSize: 8,
                                        fontWeight: FontWeight.normal,
                                        color: Theme.of(
                                          context,
                                        ).colorScheme.onSurface.withAlpha(100),
                                      ),
                                      textAlign: TextAlign.end,
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                }
              },
            ),
          ),
        );
      },
      whenNotDone: Scaffold(
        appBar: AppBar(title: Text("考试安排")),
        body: Center(
          child: LoadingAnimationWidget.inkDrop(
            color: Theme.of(context).primaryColor,
            size: 40,
          ),
        ),
      ),
    );
  }

  Color _getDaysLeftColor(String text, BuildContext context) {
    if (text.contains("今天")) {
      return Colors.red; // 今天考试用红色
    } else if (text.contains("还有")) {
      // 提取天数
      int days = int.tryParse(text.replaceAll(RegExp(r'[^0-9]'), '')) ?? 0;

      if (days <= 3) {
        return Colors.orange; // 3天内用橙色
      } else {
        return Theme.of(context).colorScheme.onSurface; // 其他用默认颜色
      }
    } else {
      return Colors.grey; // 已结束用灰色
    }
  }
}
