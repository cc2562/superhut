import 'package:dio/dio.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:superhut/command/token.dart';
import 'package:superhut/command/withhttp.dart';



class Score{
  final String curriculumAttributes;
  final String state;
  final String examName;
  final String courseNature;
  final String fraction;
  final String courseName;
  final String examinationNature;
  final String gradePoints;
  final String credit;

  Score({
    required this.curriculumAttributes,
    required this.state,
    required this.examName,
    required this.courseNature,
    required this.fraction,
    required this.courseName,
    required this.examinationNature,
    required this.gradePoints,
    required this.credit,
});

}
Future<Map> semesterIdfc() async {
  String token = await getToken();
  configureDio(token);
  Response response;
  response = await postDio('/njwhd/semesterList', {});
  Map data = response.data;
  List iddata = data['data'];
  List idlist = [];
  String nowid ='';
  for(var i=0;i<iddata.length;i++){
    Map tempMap = iddata[i];
    idlist.add(tempMap['semesterId']);
    print(tempMap['semesterId']);
    if(tempMap['nowXq']=='1'){
      nowid = tempMap['semesterId'];
    }
  }
  return {
    'idlist':idlist,
    'nowid':nowid
  };
}


Future<Map<String, Object>> getScore(String semesterId) async {
  String token = await getToken();
  configureDio(token);
  Response response;
  response = await postDio('/njwhd/student/termGPA?semester=$semesterId&type=1', {});
  Map data = response.data;
  List<Score> reList =[];
  List scorelist = data['data'];

  List achievementList = scorelist[0]['achievement'];

  String yxzxf = scorelist[0]['yxzxf'];
  String zxfjd = scorelist[0]['zxfjd'];
  String pjxfjd = scorelist[0]['pjxfjd'];

  for(Map data in achievementList){

    reList.add(
      Score(
        curriculumAttributes: data['curriculumAttributes'],
        state: data['sfjg'],
        examName: data['examName'],
        courseNature: data['courseNature'],
        fraction: data['fraction'],
        courseName: data['courseName'],
        examinationNature: data['examinationNature'],
        gradePoints: data['jd'].toString(),
        credit: data['credit'].toString(),
      )
    );
  }
  print(reList.toString());
  final prefs = await SharedPreferences.getInstance();
  prefs.setString('yxzxf', yxzxf);
  prefs.setString('zxfjd', zxfjd);
  prefs.setString('pjxfjd', pjxfjd);

  return {
    'achievement':reList,
    'yxzxf':yxzxf,
    'zxfjd':zxfjd,
    'pjxfjd':pjxfjd
  };
}
