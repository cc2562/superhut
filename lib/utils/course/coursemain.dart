import 'dart:convert';
import 'dart:io';

import 'package:path_provider/path_provider.dart';
import 'package:superhut/widget_refresh_service.dart';

import 'getCourse.dart';

class Course {
  final String name;
  final String teacherName;
  final String weekDuration;
  final String location;
  final int startSection;
  final int duration;
  final bool isExp;
  final String pcid;

  Course({
    required this.name,
    required this.teacherName,
    required this.weekDuration,
    required this.location,
    required this.startSection,
    required this.duration,
    this.isExp = false,
    this.pcid = '',
  });

  // 将 Course 对象转换为 Map
  Map<String, dynamic> toJson() {
    return {
      'name': name,
      'teacherName': teacherName,
      'weekDuration': weekDuration,
      'location': location,
      'startSection': startSection,
      'duration': duration,
      'isExp': isExp,
      'pcid': pcid,
    };
  }

  // 从 Map 构造 Course 对象
  factory Course.fromJson(Map<String, dynamic> json) {
    return Course(
      name: json['name'],
      teacherName: json['teacherName'],
      weekDuration: json['weekDuration'],
      location: json['location'],
      startSection: json['startSection'],
      duration: json['duration'],
      isExp: json['isExp'] ?? false,
      pcid: json['pcid'] ?? '',
    );
  }
}

Future<void> saveCourseDataToJson(Map<String, List<Course>> courseData) async {
  // 将 Course 对象列表转换为 Map 列表
  Map<String, List<Map<String, dynamic>>> courseDataMap = {};
  courseData.forEach((key, courses) {
    courseDataMap[key] = courses.map((course) => course.toJson()).toList();
  });

  // 将 Map 转换为 JSON 字符串
  String jsonString = jsonEncode(courseDataMap);
  final Directory appDocumentsDir = await getApplicationDocumentsDirectory();
  final String appDocumentsPath = appDocumentsDir.path;

  // 确保 app_flutter 目录存在
  final flutterDir = Directory('$appDocumentsPath/app_flutter');
  if (!flutterDir.existsSync()) {
    flutterDir.createSync(recursive: true);
  }

  // 将 JSON 字符串写入文件（保存在应用文档目录下）
  final file = File('$appDocumentsPath/course_data.json');
  await file.writeAsString(jsonString);

  // 同时保存一份到 app_flutter 目录（供桌面小组件访问）
  final widgetFile = File('${flutterDir.path}/course_data.json');
  await widgetFile.writeAsString(jsonString);

  // 刷新桌面小组件
  await WidgetRefreshService.refreshCourseTableWidget();
}

// 从 JSON 文件读取并转换为 Map<String, List<Course>>
Future<Map<String, List<Course>>> readCourseDataFromJson(
  String filePath,
) async {
  // 读取 JSON 文件内容
  final file = File(filePath);
  String jsonString = await file.readAsString();

  // 解析 JSON 字符串为 Map<String, dynamic>
  Map<String, dynamic> jsonData = jsonDecode(jsonString);

  // 将 Map<String, dynamic> 转换为 Map<String, List<Course>>
  Map<String, List<Course>> courseData = {};
  jsonData.forEach((key, coursesJson) {
    List<Course> courses =
        (coursesJson as List).map((courseJson) {
          return Course.fromJson(courseJson);
        }).toList();
    courseData[key] = courses;
  });

  return courseData;
}

Future<Map<String, List<Course>>> loadClassFromLocal() async {
  final Directory appDocumentsDir = await getApplicationDocumentsDirectory();
  final String appDocumentsPath = appDocumentsDir.path;
  try {
    final Map<String, List<Course>> courseData = await readCourseDataFromJson(
      '$appDocumentsPath/course_data.json',
    );
    // print(courseData);
    return courseData;
  } catch (e) {
    print('Error reading JSON file: $e');
    return {};
  }
}

Future<String> saveClassToLocal(String token, context) async {
  final Directory appDocumentsDir = await getApplicationDocumentsDirectory();
  final String appDocumentsPath = appDocumentsDir.path;
  try {
    final Map<String, List<Course>> courseData = await loadClassFormUrl(
      token,
      context,
    );
    //  print(courseData);
    await saveCourseDataToJson(courseData);
    return '200';
  } catch (e) {
    print('Error reading JSON file: $e');
    return '100';
  }
}

Future<Map<String, List<Course>>> testc() async {
  String jsonString =
      '{"Msg":"success~","code":"1","data":[{"date":[{"xqmc":"一","mxrq":"2025-03-03","zc":"all","xqid":1},{"xqmc":"二","mxrq":"2025-03-04","zc":"all","xqid":2},{"xqmc":"三","mxrq":"2025-03-05","zc":"all","xqid":3},{"xqmc":"四","mxrq":"2025-03-06","zc":"all","xqid":4},{"xqmc":"五","mxrq":"2025-03-07","zc":"all","xqid":5},{"xqmc":"六","mxrq":"2025-03-08","zc":"all","xqid":6},{"xqmc":"日","mxrq":"2025-03-09","zc":"all","xqid":7}],"item":[{"classWeek":"3-10,12-15","teacherName":"彭永群","buttonCode":"0","ktmc":"包装设计[2303-2304]班,数媒艺术2302班,3D打印2301班,艺术设计学[2301-2302]班,包装工程[2301-2306]班,播音主持2301班","classTime":"10304","jx0408id":"5B41D8B32D0449C5964518E4A4675613","kch":"30110080","courseName":"体育4","isRepeatCode":"0","maxClassTime":"第二大节","startTime":"10:00","endTIme":"11:40","location":"第二田径场-11","classWeekDetails":",3,4,5,6,7,8,9,10,12,13,14,15,","coursesNote":2},{"classWeek":"1-5,8-10,12-15","teacherName":"李慧源","buttonCode":"0","ktmc":"包装工程[2303-2304]班","classTime":"10506","jx0408id":"2260705AEE73489C8B310150613229A1","kch":"06110300","courseName":"通用学术英语A","isRepeatCode":"0","maxClassTime":"第三大节","startTime":"14:00","endTIme":"15:40","location":"公共304","classWeekDetails":",1,2,3,4,5,8,9,10,12,13,14,15,","coursesNote":2},{"classWeek":"3-10,12-15","teacherName":"何新快","buttonCode":"0","ktmc":"包装工程[2303-2304]班","classTime":"20304","jx0408id":"6AFCF1BEC88E457A9F3A8B8B0041FE64","kch":"04120035","courseName":"包装材料学","isRepeatCode":"0","maxClassTime":"第二大节","startTime":"10:00","endTIme":"11:40","location":"公共222","classWeekDetails":",3,4,5,6,7,8,9,10,12,13,14,15,","coursesNote":2},{"classWeek":"1-3,5-6,8-10","teacherName":"卢富德","buttonCode":"0","ktmc":"包装工程[2303-2304]班","classTime":"30102","jx0408id":"36163EC057574DCCB562879517E19112","kch":"04126570","courseName":"数值计算与工程应用","isRepeatCode":"0","maxClassTime":"第一大节","startTime":"08:00","endTIme":"09:40","location":"公共302","classWeekDetails":",1,2,3,5,6,8,9,10,","coursesNote":2},{"classWeek":"1-5,8-15","teacherName":"邓英剑","buttonCode":"0","ktmc":"包装工程[2303-2304]班","classTime":"30304","jx0408id":"9A1F9B6186C4490F8B1B6F2F067C0871","kch":"05123030","courseName":"机械设计基础","isRepeatCode":"0","maxClassTime":"第二大节","startTime":"10:00","endTIme":"11:40","location":"公共205","classWeekDetails":",1,2,3,4,5,8,9,10,11,12,13,14,15,","coursesNote":2},{"classWeek":"1-5,8-10,12-13","teacherName":"刘俊萍","buttonCode":"0","ktmc":"包装工程[2304-2306]班","classTime":"30506","jx0408id":"77EEDF2CE4E942FF9184F2C459B67626","kch":"01110010","courseName":"电工学1","isRepeatCode":"0","maxClassTime":"第三大节","startTime":"14:00","endTIme":"15:40","location":"公共115","classWeekDetails":",1,2,3,4,5,8,9,10,12,13,","coursesNote":2},{"classWeek":"1-5,8-10,12-13","teacherName":"余霄","buttonCode":"0","ktmc":"包装工程[2304-2306]班","classTime":"30708","jx0408id":"85A80553D9ED488BB19DC47B8896BBF0","kch":"29110250","courseName":"毛泽东思想和中国特色社会主义理论体系概论","isRepeatCode":"0","maxClassTime":"第四大节","startTime":"16:00","endTIme":"17:40","location":"外语楼111","classWeekDetails":",1,2,3,4,5,8,9,10,12,13,","coursesNote":2},{"classWeek":"1-5,8-15","teacherName":"邓英剑","buttonCode":"0","ktmc":"包装工程[2303-2304]班","classTime":"40304","jx0408id":"39451A236EC64C39BB380E93BD6D7763","kch":"05123030","courseName":"机械设计基础","isRepeatCode":"0","maxClassTime":"第二大节","startTime":"10:00","endTIme":"11:40","location":"公共205","classWeekDetails":",1,2,3,4,5,8,9,10,11,12,13,14,15,","coursesNote":2},{"classWeek":"2-5","teacherName":"陈腊文","buttonCode":"0","ktmc":"包装工程[2304-2306]班","classTime":"40506","jx0408id":"689AFBB898744117A7177CF8F18F36EC","kch":"40110010","courseName":"创业基础","isRepeatCode":"0","maxClassTime":"第三大节","startTime":"14:00","endTIme":"15:40","location":"公共407","classWeekDetails":",2,3,4,5,","coursesNote":2},{"classWeek":"1-5,8-10,12-13","teacherName":"余霄","buttonCode":"0","ktmc":"包装工程[2304-2306]班","classTime":"40708","jx0408id":"D3D71A6BA5C3469D80AB3F9263E801E7","kch":"29110250","courseName":"毛泽东思想和中国特色社会主义理论体系概论","isRepeatCode":"0","maxClassTime":"第四大节","startTime":"16:00","endTIme":"17:40","location":"公共309","classWeekDetails":",1,2,3,4,5,8,9,10,12,13,","coursesNote":2},{"classWeek":"1-4","teacherName":"李慧源","buttonCode":"0","ktmc":"包装工程[2303-2304]班","classTime":"50102","jx0408id":"0EDC6194AFCC4CF59DAAFD65628D2F59","kch":"06110300","courseName":"通用学术英语A","isRepeatCode":"0","maxClassTime":"第一大节","startTime":"08:00","endTIme":"09:40","location":"外语楼206","classWeekDetails":",1,2,3,4,","coursesNote":2},{"classWeek":"1-5,8-10,12-13","teacherName":"刘俊萍","buttonCode":"0","ktmc":"包装工程[2304-2306]班","classTime":"50506","jx0408id":"8BA04C12343748C2BCDE1461471E24E5","kch":"01110010","courseName":"电工学1","isRepeatCode":"0","maxClassTime":"第三大节","startTime":"14:00","endTIme":"15:40","location":"公共409","classWeekDetails":",1,2,3,4,5,8,9,10,12,13,","coursesNote":2},{"classWeek":"1-5,8-10,12-19","teacherName":"李世霖","buttonCode":"0","ktmc":"包装工程[2301-2304]班","classTime":"50708","jx0408id":"EEEEC32BA08B47908E618EB6E63C5ED7","kch":"11121730","courseName":"概率论与数理统计","isRepeatCode":"0","maxClassTime":"第四大节","startTime":"16:00","endTIme":"17:40","location":"公共332","classWeekDetails":",1,2,3,4,5,8,9,10,12,13,14,15,16,17,18,19,","coursesNote":2}],"week":2,"weekday":"五"}],"nowWeek":"3","jcdatalist":[{"XJMC":"01,02","DJMC":"第一大节"},{"XJMC":"03,04","DJMC":"第二大节"},{"XJMC":"05,06","DJMC":"第三大节"},{"XJMC":"07,08","DJMC":"第四大节"},{"XJMC":"09,10","DJMC":"第五大节"}],"nkbList":[{"kch":"05141030","kcmc":"金工实习C","jgxm":"张灵","zc":"6-7","tzdlb":"2","sjzcbz":""},{"kch":"04120035","kcmc":"包装材料学","jgxm":"何新快","zc":"12-15","tzdlb":"2","sjzcbz":""},{"kch":"01140060","kcmc":"电工学实验1","jgxm":"刘俊萍","zc":"3-5,8-10","tzdlb":"2","sjzcbz":""},{"kch":"05123030","kcmc":"机械设计基础","jgxm":"卢定军","zc":"1-4","tzdlb":"2","sjzcbz":""},{"kch":"53110030","kcmc":"大学生劳动教育","jgxm":"","zc":"1","tzdlb":"1","sjzcbz":""},{"kch":"53110030","kcmc":"大学生劳动教育","jgxm":"","zc":"1-18","tzdlb":"1","sjzcbz":""}]}';

  Map<String, dynamic> map = jsonDecode(jsonString);

  GetSingleWeekClass oneJson = GetSingleWeekClass(orgdata: map);
  oneJson.initData();
  oneJson.getWeekDate();
  Map<String, List<Course>> courseData = await oneJson.getSingleClass();
  //print(courseData);
  return courseData;
}

Future<Map<String, List<Course>>> loadClassFormUrl(
  String token,
  context,
) async {
  print("SSSSSSSSSSSSSSSSS");
  GetOrgDataWeb getOrgDataWeb = GetOrgDataWeb(token: token);
  getOrgDataWeb.initData();
  await getOrgDataWeb.getTeachingWeek();
  Map<String, List<Course>> courseData = await getOrgDataWeb.getAllWeekClass(
    context,
  );
  Map<String, List<Course>> expCourseData = await getOrgDataWeb
      .getAllWeekExpClass(context);
  expCourseData.forEach((date, list) {
    if (courseData.containsKey(date)) {
      courseData[date]!.addAll(list);
    } else {
      courseData[date] = list;
    }
  });
  // print(courseData);
  return courseData;
}
