import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:superhut/command/course/coursemain.dart';

import '../withhttp.dart';

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
    week = data['week'];
    orgclassList = data['item'];
    dateList = data['date'];
  }

  void getWeekDate() {
    late Map tempDate;
    for (var i = 0; i < dateList.length; i++) {
      tempDate = dateList[i];
      if (tempDate['xqid'] == 1) {
        firstDay = tempDate['mxrq'];
      }
      courseData[tempDate['mxrq']] = [];
      courseKey[tempDate['xqid']] = tempDate['mxrq'];
    }
   // print(courseData.toString());

  }

  Future<Map<String, List<Course>>> getSingleClass() async {
    late Map tempClass;
    for (var i = 0; i < orgclassList.length; i++) {
      tempClass = orgclassList[i];
      int atday = (int.parse(tempClass['classTime'].substring(0, 1))).toInt();
      int startSection = int.parse(tempClass['classTime'].substring(1, 3));
      int endSection = int.parse(tempClass['classTime'].substring(tempClass['classTime'].length - 2));
      int duration = endSection - startSection + 1;
      String saveDate = courseKey[atday]!;
      courseData[saveDate]!.add(
        Course(
          name: tempClass['courseName'],
          teacherName: tempClass['teacherName'],
          weekDuration: tempClass['classWeek'],
          location: tempClass['location'],
          startSection: startSection,
          duration: duration,
        ),
      );

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
    configureDio(token);
  }

  //获取总周数和当前周数
  Future<String> getTeachingWeek() async {
    final prefs = await SharedPreferences.getInstance();
    Response response;
    response = await postDio('/njwhd/teachingWeek', {});
    Map data = response.data;
    nowWeek = int.parse(data['nowWeek']);
    List tempList = data['data'];
    for (int i = 0; i < tempList.length; i++) {
      weekList.add(tempList[i]['week']);
    }
    firstWeek = int.parse(weekList[0]);
    maxWeek = int.parse(weekList[weekList.length - 1]);
   // print('$firstWeek and $maxWeek now $nowWeek');
    prefs.setInt('firstWeek', firstWeek);
    prefs.setInt('maxWeek', maxWeek);
    return '200';
  }

  //循环获取所有周课表
  Future<Map<String, List<Course>>> getAllWeekClass(context) async {
    bool noget = true;
    final prefs = await SharedPreferences.getInstance();
    for (int i = firstWeek; i <= maxWeek; i++) {
      Response response;
      response = await postDio('/njwhd/student/curriculum?week=$i', {});
      Map data = response.data;
    //  print(data.toString());
      GetSingleWeekClass getsingleweek = GetSingleWeekClass(orgdata: data);
      getsingleweek.initData();
      getsingleweek.getWeekDate();
      Map<String, List<Course>> tempData = await getsingleweek.getSingleClass();
      courseData.addAll(tempData);
      if (i == 1 && noget) {
        var entry = tempData.entries;
        MapEntry en = entry.first;
     //   print("开学第一天：${en.key}");
        prefs.setString('firstDay', en.key);
        noget = false;
      }
      await Future.delayed(Duration(microseconds: 300));
      ScaffoldMessenger.of(context).removeCurrentSnackBar();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          backgroundColor: Theme.of(context).secondaryHeaderColor,
          content: Text('正在获取第$i周课表'),
        ),
      );
     // print(i);
    }
    //print(courseData.length);
    return courseData;
  }
}
