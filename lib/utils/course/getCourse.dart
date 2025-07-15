import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../withhttp.dart';
import 'coursemain.dart';

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

class GetOrgDataWeb {
  final String token;
  late int nowWeek, firstWeek, maxWeek;
  List weekList = [];
  late Map<String, List<Course>> courseData = {};

  GetOrgDataWeb({required this.token});

  void initData() {
    // 不再需要configureDio，将在具体方法中配置
  }

  //获取总周数和当前周数
  Future<String> getTeachingWeek() async {
    final prefs = await SharedPreferences.getInstance();
    await configureDioFromStorage();
    
    try {
      Response response;
      response = await postDioWithCookie('/njwhd/teachingWeek', {});
      Map data = response.data;
      
      // 安全地处理nowWeek字段
      var nowWeekValue = data['nowWeek'];
      if (nowWeekValue is String) {
        nowWeek = int.parse(nowWeekValue);
      } else if (nowWeekValue is int) {
        nowWeek = nowWeekValue;
      } else {
        nowWeek = 1; // 默认值
      }
      
      List tempList = data['data'];
      weekList.clear(); // 清空之前的数据
      
      for (int i = 0; i < tempList.length; i++) {
        var weekValue = tempList[i]['week'];
        if (weekValue != null) {
          weekList.add(weekValue.toString());
        }
      }
      
      if (weekList.isNotEmpty) {
        firstWeek = int.parse(weekList[0]);
        maxWeek = int.parse(weekList[weekList.length - 1]);
      } else {
        // 如果没有数据，设置默认值
        firstWeek = 1;
        maxWeek = 20;
      }
      
      //print('$firstWeek and $maxWeek now $nowWeek');
      prefs.setInt('firstWeek', firstWeek);
      prefs.setInt('maxWeek', maxWeek);
      print("MAXIS");
      print(maxWeek);
      print(firstWeek);
      return '200';
    } catch (e) {
      print('获取教学周数据出错: $e');
      return 'error';
    }
  }

  //循环获取所有周课表
  Future<Map<String, List<Course>>> getAllWeekClass(context) async {
    bool noget = true;
    final prefs = await SharedPreferences.getInstance();
    await configureDioFromStorage();
    
    for (int i = firstWeek; i <= maxWeek; i++) {
      try {
        Response response;
        response = await postDioWithCookie('/njwhd/student/curriculum?week=$i', {});
        Map data = response.data;
        print('获取第$i周数据: ${data.toString()}');
        print('这里');
        
        // 检查返回的数据结构
        if (data['data'] == null || (data['data'] as List).isEmpty) {
          print('第$i周没有课程数据');
          continue;
        }
        
        GetSingleWeekClass getsingleweek = GetSingleWeekClass(orgdata: data);
        getsingleweek.initData();
        getsingleweek.getWeekDate();
        Map<String, List<Course>> tempData = await getsingleweek.getSingleClass();
        courseData.addAll(tempData);
        
        if (i == 1 && noget && tempData.isNotEmpty) {
          var entry = tempData.entries;
          MapEntry en = entry.first;
          print("开学第一天：${en.key}");
          prefs.setString('firstDay', en.key);
          noget = false;
        }

        print(i);
        await Future.delayed(Duration(microseconds: 300));
        ScaffoldMessenger.of(context).removeCurrentSnackBar();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: Theme.of(context).secondaryHeaderColor,
            content: Text('正在获取第$i周课表'),
          ),
        );
      } catch (e) {
        print('获取第$i周课表出错: $e');
        // 继续获取下一周的数据
        continue;
      }
    }
    return courseData;
  }

  //单独获取一周课表
  Future<Map<String, List<Course>>> getSingleWeekClass(int week) async {
    try {
      await configureDioFromStorage();
      Response response;
      response = await postDioWithCookie('/njwhd/student/curriculum?week=$week', {});
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
}
