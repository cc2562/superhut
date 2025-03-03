import 'package:enhanced_future_builder/enhanced_future_builder.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:intl/intl.dart';
import 'package:ionicons/ionicons.dart';
import 'package:modal_bottom_sheet/modal_bottom_sheet.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../command/course/coursemain.dart';
import 'logic.dart';

class CourseTableView extends StatefulWidget {
  const CourseTableView({super.key});

  @override
  State<CourseTableView> createState() => _CourseTableViewState();
}

/*
 * 课程数据模型类
 * @param name 课程名称
 * @param startSection 课程开始的节数（1-based）
 * @param duration 课程持续节数
 */

DateTime getMondayOfCurrentWeek() {
  final DateTime now = DateTime.now();
  // 计算当前日期与本周一的差值（星期一对应的weekday为1）
  int daysToSubtract = now.weekday - 1;
  // 处理周日的情况（Dart中周日weekday=7）
  if (now.weekday == 7) {
    daysToSubtract = 6;
  }
  return now.subtract(Duration(days: daysToSubtract));
}

class _CourseTableViewState extends State<CourseTableView> {
  final CourseTableViewLogic logic = Get.put(CourseTableViewLogic());

  // DateTime _currentDate = DateTime.now();
  DateTime _currentDate = getMondayOfCurrentWeek();
  //设置周数
  //当前显示周数
  int _currentWeek = 1;
  int _allWeek = 100;
  //当前实际周数
  int _currentRealWeek = 1;
  /*
   * 课程数据存储器
   * Key格式：yyyy-MM-dd 的日期字符串
   * Value：当天课程列表
   */
  late Map<String, List<Course>> _courseData = {};
  // 定义一个映射来存储 weekday 数字到中文星期名称的对应关系
  final Map<int, String> _weekdayMap = {
    1: '周一',
    2: '周二',
    3: '周三',
    4: '周四',
    5: '周五',
    6: '周六',
    7: '周日',
  };
  @override
  void initState() {
    super.initState();
    //_loadExampleData();
    //_courseData = testc();
  }

  // 综合计算周数的完整函数
  int calculateSchoolWeek(String? firstDayString) {
    // 异常情况处理
    if (firstDayString == null) throw ArgumentError('firstDay 不能为空');
    if (!RegExp(r'^\d{4}-\d{2}-\d{2}$').hasMatch(firstDayString)) {
      throw FormatException('日期格式应为 yyyy-MM-dd');
    }

    // 1. 字符串转DateTime
    final firstDay = DateTime.parse(firstDayString);

    // 2. 转换为当周周一
    final firstMonday = firstDay.subtract(Duration(days: firstDay.weekday - 1));

    // 3. 计算当前周数
    final now = DateTime.now();
    final difference = now.difference(firstMonday).inDays + 1;

    // 处理早于开学日的情况
    if (difference < 0) return 0;

    return (difference / 7).ceil();
  }

  Future<void> getWeek() async {
    final prefs = await SharedPreferences.getInstance();
    var firstDay = prefs.getString('firstDay');
    _allWeek = prefs.getInt('maxWeek') ?? 1;
    setState(() {
      _currentWeek = calculateSchoolWeek(firstDay);
      _currentRealWeek = _currentWeek;
    });

  }


  /*
   * 获取指定日期所在周的起始日期（周一）
   * @param date 要计算的日期
   * @return 当周周一对应的日期对象
   */
  DateTime _getStartOfWeek(DateTime date) {
    return date.subtract(Duration(days: date.weekday - 1));
  }
  void _backToRealWeek() {
    if (_currentWeek ==_currentRealWeek) {
      return;
    }
    setState(() {
      _currentDate = DateTime(
        _currentDate.year,
        _currentDate.month,
        _currentDate.day - 7*(_currentWeek -_currentRealWeek),
      );
      _currentWeek = _currentRealWeek;
    });
  }
  /*
   * 切换到上个月视图
   * 更新_currentDate为上月第一天
   */
  void _previousWeek() {
    if (_currentWeek <= 1) {
      return;
    }
    setState(() {
      _currentDate = DateTime(
        _currentDate.year,
        _currentDate.month,
        _currentDate.day - 7,
      );
      _currentWeek = _currentWeek - 1;
    });
  }

  /*
   * 切换到下个月视图
   * 更新_currentDate为下月第一天
   */
  void _nextWeek() {
    if (_currentWeek >= _allWeek) {
      return;
    }
    setState(() {
      _currentDate = DateTime(
        _currentDate.year,
        _currentDate.month,
        _currentDate.day + 7,
      );
      _currentWeek = _currentWeek + 1;
    });
  }

  /*
   * 生成日期格式化键
   * @param date 要格式化的日期对象
   * @return yyyy-MM-dd格式的日期字符串
   */
  String _dateKey(DateTime date) => DateFormat('yyyy-MM-dd').format(date);

  /*
   * 根据课程名称生成固定颜色
   * @param seed 颜色生成种子字符串（课程名称）
   * @return HSL颜色空间生成的固定颜色
   */
  Color _getCourseColor(String seed) {
    final hash = seed.hashCode % 360;
    return HSLColor.fromAHSL(1.0, hash.toDouble(), 0.6, 0.75).toColor();
  }

  /*
   * 构建单日课程时间表布局
   * @param courses 当天的课程列表
   * @return 包含课程块和空白时间段的组件列表
   * 实现逻辑：
   * 1. 按开始节数排序课程
   * 2. 填充课程之间的空白时间段
   * 3. 保证最多显示到第6节课
   */
  List<Widget> _buildDayCourses(List<Course> courses) {
    courses.sort((a, b) => a.startSection.compareTo(b.startSection));
    final widgets = <Widget>[];
    int currentSection = 1;

    for (final course in courses) {
      while (currentSection < course.startSection) {
        widgets.add(_buildTimeSlot(currentSection));
        currentSection++;
      }
      widgets.add(_buildCourseItem(course));
      currentSection += course.duration;
    }

    while (currentSection <= 10) {
      widgets.add(_buildTimeSlot(currentSection));
      currentSection++;
    }

    return widgets;
  }

  /*
   * 构建单个课程显示块
   * @param course 课程对象
   * @return 包含课程名称的彩色区块组件
   */
  Widget _buildCourseItem(Course course) {
    double marginTB = 0, marginT = 1;
    if (course.duration >= 2) {
      marginTB = course.duration.toDouble();
    }
    if (course.startSection == 1) {
      marginT = 0;
    }
    String showCourseName = course.name;

    return Container(
      alignment: Alignment.topLeft,
      height: 60 * course.duration.toDouble() + marginTB,
      decoration: BoxDecoration(
        border: Border.all(color: _getCourseColor(course.name).withAlpha(100)),

        color: _getCourseColor(course.name),
        borderRadius: BorderRadius.circular(4),
      ),
      margin: EdgeInsets.fromLTRB(1, marginT, 1, 1),
      padding: EdgeInsets.all(1),
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
                        padding: EdgeInsets.fromLTRB(20, 20, 20, 10),
                        height: 350,
                        child: ListView(
                          physics: NeverScrollableScrollPhysics(),
                          children: [
                            Container(
                              child: Text(
                                course.name,
                                style: Theme.of(context).textTheme.titleLarge,
                              ),
                            ),
                            ListTile(
                              leading: Icon(
                                Ionicons.calendar_outline,
                                color: Theme.of(context).primaryColor,
                              ),
                              title: Text(course.weekDuration),
                            ),
                            ListTile(
                              leading: Icon(
                                Ionicons.time_outline,
                                color: Theme.of(context).primaryColor,
                              ),
                              title: Text(
                                '第${course.startSection}-${(course.duration + course.startSection - 1)}节',
                              ),
                            ),
                            ListTile(
                              leading: Icon(
                                Ionicons.person_outline,
                                color: Theme.of(context).primaryColor,
                              ),
                              title: Text(course.teacherName),
                            ),
                            ListTile(
                              leading: Icon(
                                Ionicons.location_outline,
                                color: Theme.of(context).primaryColor,
                              ),
                              title: Text(course.location),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
          );
        },
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Text(
                showCourseName,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                ),
                textAlign: TextAlign.left,
                maxLines: 5,
                overflow: TextOverflow.fade,
              ),
            ),
            Text(
              course.location,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 10,
                fontWeight: FontWeight.normal,
              ),
              textAlign: TextAlign.left,
            ),
            Text(
              course.teacherName,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 10,
                fontWeight: FontWeight.normal,
              ),
              textAlign: TextAlign.left,
            ),
          ],
        ),
      ),
    );
  }

  /*
   * 构建空白时间段占位组件
   * @param section 当前节数编号
   * @return 带有节数标识的灰色边框占位块
   */
  Widget _buildTimeSlot(int section) {
    double marginT = 1;
    if (section == 1) {
      marginT = 0;
    }
    return Container(
      height: 60,
      decoration: BoxDecoration(
        //border: Border.all(color: Colors.grey.withOpacity(0.5)),
        //border: Border.all(color: Colors.grey.withOpacity(0.5)),
      ),
      margin: EdgeInsets.fromLTRB(1, marginT, 1, 1),
      child: Center(
        child: Text(
          '',
          style: TextStyle(color: Colors.grey[600], fontSize: 10),
        ),
      ),
    );
  }

  bool firstload = true;
  Future<void> doOnlyOne() async {
    print("1");
    if (firstload) {
      firstload = false;
      getWeek();
      _courseData = await loadClassFromLocal();
    } else {
      firstload = false;
      //getWeek();
      //_courseData = await loadClassFromLocal();
      print("2");
      return;
    }
  }

  @override
  Widget build(BuildContext context) {
    final weekStart = _getStartOfWeek(_currentDate);
    final weekDays = List.generate(7, (i) => weekStart.add(Duration(days: i)));
    String showWeekStr = "第$_currentWeek周";
    if (_currentWeek != _currentRealWeek) {
      showWeekStr = "第$_currentWeek周（当前第$_currentRealWeek周）";
    }
    return Scaffold(
      body: EnhancedFutureBuilder(
        future: doOnlyOne(),
        rememberFutureResult: true,
        whenDone: (da) {
          //_courseData = da;
          return Padding(
            padding: EdgeInsets.fromLTRB(10, 0, 10, 0),
            child: Column(
              children: [
                /* 月份切换控制区域 */
                Padding(
                  padding: const EdgeInsets.all(1.0),
                  child: Row(
                    children: [
                      //日期显示
                      Expanded(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              DateFormat('yyyy/M/dd').format(_currentDate),
                              style: const TextStyle(fontSize: 18),
                            ),
                            PopupMenuButton(
                              onSelected: (re){

                              },
                              child: Text(
                                showWeekStr,
                                style: const TextStyle(fontSize: 18),
                              ),
                              itemBuilder: (BuildContext context) {
                                return [
                                   PopupMenuItem(
                                    value: "1",
                                    child: Text('回到当前周'),
                                    onTap: (){
                                      _backToRealWeek();
                                    },
                                  ),
                                ];
                              },
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(10),

                              ),
                            ),
                          ],
                        ),
                      ),
                      //上下切换按钮
                      Row(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          IconButton(
                            icon: const Icon(Icons.chevron_left),
                            onPressed: _previousWeek,
                          ),

                          IconButton(
                            icon: const Icon(Icons.chevron_right),
                            onPressed: _nextWeek,
                          ),
                        ],
                      ),
                    ],
                  ),
                ),

                /* 周视图表头（星期几） */
                Row(
                  children: [
                    // 添加一个空的Container作为课程编号列的表头占位符
                    Expanded(
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 8),
                        decoration: BoxDecoration(
                          //   border: Border.all(color: Colors.grey),
                          // color: Colors.blue[200],
                        ),
                        child: Text(
                          "",
                          textAlign: TextAlign.center,
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                      ),
                    ),
                    ...weekDays.map((day) {
                      String showText =
                          '${_weekdayMap[day.weekday]!}\n${DateFormat('M-d').format(day)}';
                      return Expanded(
                        flex: 4,
                        child: Container(
                          padding: const EdgeInsets.symmetric(vertical: 8),
                          decoration: BoxDecoration(
                            // border: Border.all(color: Colors.grey),
                            // color: Colors.blue[200],
                          ),
                          child: Text(
                            showText ?? '',
                            textAlign: TextAlign.center,
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              color: Colors.grey,
                            ),
                            maxLines: 2,
                          ),
                        ),
                      );
                    }),
                  ],
                ),

                /* 课程表主体内容区域 */
                Expanded(
                  child: GestureDetector(
                    onHorizontalDragEnd: (details) {
                      print(details);
                      if (details.primaryVelocity! > 10) {
                        _previousWeek();
                      } else {
                        _nextWeek();
                      }
                    },
                    child: SingleChildScrollView(
                      child: Padding(
                        padding: EdgeInsets.only(bottom: 100),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // 添加课程编号列
                            Expanded(
                              child: SizedBox(
                                width: 40,
                                child: Column(
                                  children: List.generate(10, (index) {
                                    return Container(
                                      height: 60,
                                      decoration: BoxDecoration(),
                                      margin: const EdgeInsets.fromLTRB(
                                        0,
                                        1,
                                        0,
                                        1,
                                      ),
                                      child: Center(
                                        child: Text(
                                          '${index + 1}',
                                          style: TextStyle(
                                            color: Colors.grey[600],
                                            fontSize: 10,
                                          ),
                                        ),
                                      ),
                                    );
                                  }),
                                ),
                              ),
                            ),
                            ...weekDays.map((day) {
                              return Expanded(
                                flex: 4,
                                child: Container(
                                  padding: EdgeInsets.only(top: 1),
                                  decoration: BoxDecoration(
                                    border: Border(
                                      //right: BorderSide(color: Colors.grey),
                                      // top: BorderSide(color: Colors.grey),
                                    ),
                                  ),
                                  child: Column(
                                    children: _buildDayCourses(
                                      _courseData[_dateKey(day)] ?? [],
                                    ),
                                  ),
                                ),
                              );
                            }),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          );
        },
        whenNotDone: Center(child: Text('Waiting...')),
      ),
    );
  }
}
