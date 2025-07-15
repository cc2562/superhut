import 'package:dio/dio.dart';

import '../../utils/token.dart';
import '../../utils/withhttp.dart';

//定义选项
class QuestionOption {
  final String targetId;
  final String answer;
  final String optionId;
  final String optionScoreValue;

  QuestionOption(
    this.targetId,
    this.answer,
    this.optionId,
    this.optionScoreValue,
  );
}

//获取评教批次
Future<List> getCommentaryBatch() async {
  await configureDioFromStorage();
  Response response;
  response = await postDioWithCookie('/njwhd/student/studentEvaluate', {});
  Map data = response.data;
  List commentaryBatches = data['data'];
  return commentaryBatches;
}

//获取评教列表
Future<List> getCommentaryList(
  String pj01id,
  String batchId,
  String pj05id,
) async {
  await configureDioFromStorage();
  Response response;
  response = await postDioWithCookie(
    '/njwhd/student/teachingEvaluation?pj01id=${pj01id}&batchId=${batchId}&pj05id=${pj05id}&issubmit=all',
    {},
  );
  Map data = response.data;

  List commentaryList = data['data'];
  return commentaryList;
}

//获取评教题目
Future<List> getCommentaryQuestion(
  String batchId,
  String evaluationCategoriesId,
  String courseId,
  String teacherId,
  String noticeId,
) async {
  await configureDioFromStorage();
  Response response;
  response = await postDioWithCookie(
    '/njwhd/student/evaluationIndex?batchId=${batchId}&evaluationCategoriesId=${evaluationCategoriesId}&courseId=${courseId}&teacherId=${teacherId}&noticeId=${noticeId}&schoolClassificationId=""',
    {},
  );
  Map data = response.data;
  Map MapData = data['data'];
  List targetData = MapData['targetData'];
  List resultList = [];
  for (var i = 0; i < targetData.length; i++) {
    if (targetData[i]['parentTargetId'] == "") {
    } else {
      List commentaryQuestions = targetData[i]['optionData'];
      List<QuestionOption> QuestionList = [];
      for (int w = 0; w < commentaryQuestions.length; w++) {
        QuestionOption tempeQustionOption = QuestionOption(
          targetData[i]['targetId'],
          commentaryQuestions[w]['optionName'],
          commentaryQuestions[w]['optionId'],
          commentaryQuestions[w]['optionScoreValue'],
        );
        QuestionList.add(tempeQustionOption);
      }
      Map questionMap = {
        'targetName': targetData[i]['targetName'],
        'targetId': targetData[i]['targetId'],
        'optionList': QuestionList,
      };
      resultList.add(questionMap);
    }
  }
  return resultList;
}

//提交评教
Future<String> submitCommentary(
  String batchId,
  String courseId,
  String evaluationCategoriesId,
  String teacherId,
  String noticeId,
  List questionList,
) async {
  //处理QuesionList
  //List<Map> toPostList=[];
  //for(int i=0;i<questionList.length;i++){
  //  Map tempMap={
  //    "targetid": questionList[i].targetId,
  //    "targetval": questionList[i].optionId,
  //  };
  //  toPostList.add(tempMap);
  // }
  await configureDioFromStorage();
  Response response;
  response = await postDioWithCookie('/njwhd/student/saveEvaluate', {
    "batchId": batchId,
    "courseId": courseId,
    "evaluationCategoriesId": evaluationCategoriesId,
    "teacherId": teacherId,
    "noticeId": noticeId,
    "schoolClassificationId": "",
    "target": questionList,
  });
  Map data = response.data;
  print(data);
  if (data.containsKey('code')) {
    String result = data['code'];
    return result;
  } else {
    return data['errorMessage'];
  }
}
