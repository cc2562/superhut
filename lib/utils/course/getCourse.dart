import 'package:dio/dio.dart';

import '../withhttp.dart';
import 'coursemain.dart';

typedef CourseWeekProgress = void Function(int completed, int total);

class GetSingleWeekClass {
  final Map orgdata;

  GetSingleWeekClass({required this.orgdata});

  late Map data;
  late int week;
  late List orgclassList, dateList;
  late List<Course> courseList;
  late Map<String, List<Course>> courseData = {};
  late Map<int, String> courseKey = {};
  late String firstDay;

  void initData() {
    data = orgdata['data'][0];
    // 安全地转换week字段，处理可能的字符串类型
    var weekValue = data['week'];
    if (weekValue is String) {
      week = int.parse(weekValue);
    } else if (weekValue is int) {
      week = weekValue;
    } else {
      week = 0; // 默认值
    }
    orgclassList = data['item'];
    dateList = data['date'];
  }

  void getWeekDate() {
    late Map tempDate;
    for (var i = 0; i < dateList.length; i++) {
      tempDate = dateList[i];
      // 安全地处理xqid字段的类型转换
      var xqidValue = tempDate['xqid'];
      int xqid;
      if (xqidValue is String) {
        xqid = int.parse(xqidValue);
      } else if (xqidValue is int) {
        xqid = xqidValue;
      } else {
        xqid = 0; // 默认值
      }

      if (xqid == 1) {
        firstDay = tempDate['mxrq'];
      }
      courseData[tempDate['mxrq']] = [];
      courseKey[xqid] = tempDate['mxrq'];
    }
    // print(courseData.toString());
  }

  Future<Map<String, List<Course>>> getSingleClass() async {
    late Map tempClass;
    for (var i = 0; i < orgclassList.length; i++) {
      tempClass = orgclassList[i];

      try {
        // 安全地解析classTime字段
        String classTime = tempClass['classTime'].toString();
        if (classTime.length < 3) {
          print('警告：classTime格式不正确: $classTime');
          continue; // 跳过这个课程
        }

        int atday = int.parse(classTime.substring(0, 1));
        int startSection = int.parse(classTime.substring(1, 3));
        int endSection = int.parse(classTime.substring(classTime.length - 2));
        int duration = endSection - startSection + 1;
        String saveDate = courseKey[atday] ?? '';

        if (saveDate.isNotEmpty && courseData[saveDate] != null) {
          courseData[saveDate]!.add(
            Course(
              name: tempClass['courseName']?.toString() ?? '',
              teacherName: tempClass['teacherName']?.toString() ?? '',
              weekDuration: tempClass['classWeek']?.toString() ?? '',
              location: tempClass['location']?.toString() ?? '',
              startSection: startSection,
              duration: duration,
            ),
          );
        }
      } catch (e) {
        print('解析课程数据出错: $e');
        print('问题数据: $tempClass');
        // 继续处理下一个课程，不中断整个流程
      }
    }

    return courseData;
  }
}

class GetSingleWeekExpClass {
  final Map orgdata;

  GetSingleWeekExpClass({required this.orgdata});

  late Map data;
  late List expClassList, dateList;
  late Map<String, List<Course>> courseData = {};
  late Map<int, String> courseKey = {};

  void initData() {
    data = orgdata['data'][0];
    expClassList = data['courses'] ?? [];
    dateList = data['date'] ?? [];
  }

  void getWeekDate() {
    late Map tempDate;
    for (var i = 0; i < dateList.length; i++) {
      tempDate = dateList[i];
      var xqidValue = tempDate['xqid'];
      int xqid;
      if (xqidValue is String) {
        xqid = int.parse(xqidValue);
      } else if (xqidValue is int) {
        xqid = xqidValue;
      } else {
        xqid = 0;
      }
      courseData[tempDate['mxrq']] = [];
      courseKey[xqid] = tempDate['mxrq'];
    }
  }

  Future<Map<String, List<Course>>> getSingleClass() async {
    for (var i = 0; i < expClassList.length; i++) {
      final tempClass = expClassList[i];
      try {
        int weekDay;
        var weekDayValue = tempClass['weekDay'];
        if (weekDayValue is String) {
          weekDay = int.parse(weekDayValue);
        } else if (weekDayValue is int) {
          weekDay = weekDayValue;
        } else {
          continue;
        }

        String saveDate = courseKey[weekDay] ?? '';
        if (saveDate.isEmpty) continue;

        String weekNoteDetail = tempClass['weekNoteDetail']?.toString() ?? '';
        if (weekNoteDetail.isEmpty) continue;

        List<String> tokens =
            weekNoteDetail
                .split(',')
                .where((e) => e.trim().isNotEmpty)
                .toList();
        if (tokens.isEmpty) continue;

        List<int> sections =
            tokens
                .map((t) {
                  String two = t.length >= 2 ? t.substring(t.length - 2) : t;
                  return int.tryParse(two) ?? 0;
                })
                .where((s) => s > 0)
                .toList();

        if (sections.isEmpty) continue;
        sections.sort();
        int startSection = sections.first;
        int endSection = sections.last;
        int duration = endSection - startSection + 1;

        String courseName = tempClass['courseName']?.toString() ?? '';
        String syxmName = tempClass['syxmName']?.toString() ?? '';
        String displayName =
            (syxmName.isNotEmpty)
                ? '$courseName 实验：$syxmName'
                : '$courseName 实验';

        courseData[saveDate]!.add(
          Course(
            name: displayName,
            teacherName: tempClass['teacherName']?.toString() ?? '',
            weekDuration: '第${tempClass['kkzc']?.toString() ?? ''}周',
            location: tempClass['classroomName']?.toString() ?? '',
            startSection: startSection,
            duration: duration,
            isExp: true,
            pcid: tempClass['pcid']?.toString() ?? '',
          ),
        );
      } catch (e) {
        print('解析实验课程数据出错: $e');
        print('问题数据: $tempClass');
        continue;
      }
    }

    return courseData;
  }
}

class GetOrgDataWeb {
  final String token;
  late int nowWeek, firstWeek, maxWeek;
  List weekList = [];
  late Map<String, List<Course>> courseData = {};
  String? semesterId;
  String? firstDay;

  GetOrgDataWeb({required this.token});

  void initData() {
    // 不再需要configureDio，将在具体方法中配置
  }

  //获取总周数和当前周数
  Future<void> getTeachingWeek() async {
    await configureDioFromStorage();

    final Response response = await postDioWithCookie(
      '/njwhd/teachingWeek',
      {},
    );
    if (response.data is! Map) {
      throw const FormatException('教学周数据格式不正确');
    }
    final Map data = response.data;

    // 安全地处理nowWeek字段
    final int? parsedNowWeek = int.tryParse(data['nowWeek'].toString());
    nowWeek = parsedNowWeek ?? 1;

    if (data['data'] is! List) {
      throw const FormatException('教学周列表格式不正确');
    }
    final List tempList = data['data'];
    weekList.clear();

    for (final dynamic item in tempList) {
      if (item is Map && item['week'] != null) {
        weekList.add(item['week'].toString());
      }
    }

    if (weekList.isEmpty) {
      firstWeek = 1;
      maxWeek = 20;
      return;
    }

    firstWeek = int.parse(weekList.first);
    maxWeek = int.parse(weekList.last);
    if (firstWeek < 1 || maxWeek < firstWeek) {
      throw const FormatException('教学周范围不正确');
    }
  }

  //循环获取所有周课表
  Future<Map<String, List<Course>>> getAllWeekClass({
    CourseWeekProgress? onProgress,
  }) async {
    await configureDioFromStorage();
    courseData = {};
    final int total = maxWeek - firstWeek + 1;
    int completed = 0;

    for (int i = firstWeek; i <= maxWeek; i++) {
      final Response response = await postDioWithCookie(
        '/njwhd/student/curriculum?week=$i',
        {},
      );
      if (response.data is! Map) {
        throw FormatException('第$i周课表数据格式不正确');
      }
      final Map data = response.data;
      final dynamic rawWeekData = data['data'];
      if (rawWeekData != null && rawWeekData is! List) {
        throw FormatException('第$i周课表列表格式不正确');
      }

      final List weekData = rawWeekData is List ? rawWeekData : const [];
      if (weekData.isNotEmpty) {
        final GetSingleWeekClass singleWeek = GetSingleWeekClass(orgdata: data);
        singleWeek.initData();
        singleWeek.getWeekDate();
        final Map<String, List<Course>> tempData =
            await singleWeek.getSingleClass();
        courseData.addAll(tempData);
        if (firstDay == null && tempData.keys.isNotEmpty) {
          final DateTime weekStart = DateTime.parse(tempData.keys.first);
          final DateTime semesterStart = weekStart.subtract(
            Duration(days: (i - 1) * 7),
          );
          firstDay = semesterStart.toIso8601String().substring(0, 10);
        }
      }

      completed++;
      onProgress?.call(completed, total);
    }
    return courseData;
  }

  //单独获取一周课表
  Future<Map<String, List<Course>>> getSingleWeekClass(int week) async {
    try {
      await configureDioFromStorage();
      Response response;
      response = await postDioWithCookie(
        '/njwhd/student/curriculum?week=$week',
        {},
      );
      Map data = response.data;

      // 检查返回的数据结构
      if (data['data'] == null || (data['data'] as List).isEmpty) {
        print('第$week周没有课程数据');
        return {};
      }

      GetSingleWeekClass getsingleweek = GetSingleWeekClass(orgdata: data);
      getsingleweek.initData();
      getsingleweek.getWeekDate();
      Map<String, List<Course>> tempData = await getsingleweek.getSingleClass();
      return tempData;
    } catch (e) {
      print('获取第$week周课表出错: $e');
      return {};
    }
  }

  Future<String> getCurrentSemesterId() async {
    try {
      await configureDioFromStorage();
      Response response = await postDioWithCookie('/njwhd/semesterList', {});
      Map data = response.data;
      List iddata = data['data'] ?? [];
      String nowid = '';
      for (var i = 0; i < iddata.length; i++) {
        Map tempMap = iddata[i];
        if (tempMap['nowXq']?.toString() == '1') {
          nowid = tempMap['semesterId']?.toString() ?? '';
          break;
        }
      }
      semesterId = nowid;
      return nowid;
    } catch (e) {
      print('获取当前学期ID失败: $e');
      semesterId = '';
      return '';
    }
  }

  Future<Map<String, List<Course>>> getAllWeekExpClass({
    CourseWeekProgress? onProgress,
  }) async {
    final Map<String, List<Course>> expCourseData = {};
    if (semesterId == null || semesterId!.isEmpty) {
      await getCurrentSemesterId();
    }
    final String sid = semesterId ?? '';
    if (sid.isEmpty) {
      throw const FormatException('无法获取当前学期');
    }

    await configureDioFromStorage();
    final int total = maxWeek - firstWeek + 1;
    int completed = 0;
    for (int i = firstWeek; i <= maxWeek; i++) {
      final Response response = await postDioWithCookie(
        '/njwhd/teacher/courseScheduleExp?xnxq01id=$sid&week=$i',
        {},
      );
      if (response.data is! Map) {
        throw FormatException('第$i周课程数据格式不正确');
      }
      final Map data = response.data;
      final dynamic rawWeekData = data['data'];
      if (rawWeekData != null && rawWeekData is! List) {
        throw FormatException('第$i周课程列表格式不正确');
      }

      final List weekData = rawWeekData is List ? rawWeekData : const [];
      if (weekData.isNotEmpty) {
        final GetSingleWeekExpClass expWeek = GetSingleWeekExpClass(
          orgdata: data,
        );
        expWeek.initData();
        expWeek.getWeekDate();
        final Map<String, List<Course>> tempData =
            await expWeek.getSingleClass();
        tempData.forEach((String date, List<Course> courses) {
          expCourseData.putIfAbsent(date, () => []);
          expCourseData[date]!.addAll(courses);
        });
      }

      completed++;
      onProgress?.call(completed, total);
    }
    return expCourseData;
  }
}

Future<Map> getExpStudentList(String pcid) async {
  try {
    await configureDioFromStorage();
    Response response = await postDioWithCookie(
      '/njwhd/xuanke/getCuarStudentListExp?pcid=$pcid',
      {},
    );
    Map data = response.data;
    return data;
  } catch (e) {
    print('获取实验人员名单失败: $e');
    return {'code': '0', 'Msg': 'error'};
  }
}
