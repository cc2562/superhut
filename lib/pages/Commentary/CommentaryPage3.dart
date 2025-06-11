import 'dart:core';

import 'package:enhanced_future_builder/enhanced_future_builder.dart';
import 'package:flutter/material.dart';
import 'package:loading_animation_widget/loading_animation_widget.dart';
import 'package:superhut/pages/Commentary/CommentaryApi.dart';

class commentaryPage3 extends StatefulWidget {
  final String batchId;
  final String courseId;
  final String evaluationCategoriesId;
  final String teacherId;
  final String noticeId;

  commentaryPage3({
    super.key,
    required this.batchId,
    required this.courseId,
    required this.evaluationCategoriesId,
    required this.teacherId,
    required this.noticeId,
  });

  @override
  State<commentaryPage3> createState() => _commentaryPage3State();
}

class _commentaryPage3State extends State<commentaryPage3> {
  List<List<bool>>? _questionSelections;
  bool _isInitialized = false;
  List saveQusetionList = [];

  Future<List> getOptionList() async {
    if (_isInitialized) {
      return saveQusetionList;
    }
    List allOptionList = await getCommentaryQuestion(
      widget.batchId,
      widget.evaluationCategoriesId,
      widget.courseId,
      widget.teacherId,
      widget.noticeId,
    );
    // 初始化选项状态列表
    _questionSelections =
        allOptionList.map<List<bool>>((question) {
          return List<bool>.filled(question['optionList'].length, false);
        }).toList();
    print('rrr');
    _isInitialized = true;
    saveQusetionList = allOptionList;
    return allOptionList;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).colorScheme.surface,
      appBar: AppBar(
        elevation: 0,
        backgroundColor: Colors.transparent,
        actions: [
          TextButton(
            onPressed: () async {
              //getUserSelect();
              List _userSelect = await autoFinishCommentary();
              toSubmitCommentary(_userSelect);
            },
            child: Text('一键完成'),
          ),
        ],
      ),
      body: Container(
        margin: EdgeInsets.only(left: 10, right: 10),
        child: EnhancedFutureBuilder(
          future: getOptionList(),
          rememberFutureResult: true,
          whenDone: (List theOptionList) {
            return ListView.builder(
              itemCount: theOptionList.length + 1,
              itemBuilder: (BuildContext context, int index) {
                // 获取当前问题的选项状态
                if (index == theOptionList.length) {
                  return ElevatedButton(
                    onPressed: () {
                      List _select = getUserSelect();
                      if (_select.length < theOptionList.length) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text('需要完成所有题目才可以提交~')),
                        );
                        return;
                      }
                      print("通过");
                      toSubmitCommentary(_select);
                    },
                    child: Text('提交'),
                  );
                } else {
                  Map theSingleQuestionMap = theOptionList[index];
                  List<QuestionOption> optionList =
                      theSingleQuestionMap['optionList'];
                  return Card.filled(
                    color: Theme.of(context).colorScheme.surfaceContainer,
                    child: Padding(
                      padding: EdgeInsets.all(10),
                      child: Flex(
                        crossAxisAlignment: CrossAxisAlignment.center,
                        direction: Axis.horizontal,
                        children: [
                          Expanded(
                            flex: 10,
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  theSingleQuestionMap['targetName'],
                                  style: TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.bold,
                                    color:
                                        Theme.of(context).colorScheme.onSurface,
                                  ),
                                ),

                                SizedBox(height: 0),
                                ListView.builder(
                                  shrinkWrap: true,
                                  physics: NeverScrollableScrollPhysics(),
                                  itemCount: optionList.length,
                                  itemBuilder: (
                                    BuildContext context,
                                    int optionIndex,
                                  ) {
                                    List<bool> theSingleOptionSelect = [];
                                    for (
                                      var i = 0;
                                      i < optionList.length;
                                      i++
                                    ) {
                                      theSingleOptionSelect.add(false);
                                    }
                                    return CheckboxListTile(
                                      value:
                                          _questionSelections![index][optionIndex],
                                      onChanged: (v) {
                                        print(v);
                                        print(optionIndex);
                                        //先清楚所有选项
                                        for (
                                          var i = 0;
                                          i < optionList.length;
                                          i++
                                        ) {
                                          _questionSelections![index][i] =
                                              false;
                                        }
                                        setState(() {
                                          _questionSelections![index][optionIndex] =
                                              v!;
                                        });
                                        print(
                                          "THE: ${_questionSelections![index]}",
                                        );
                                      },
                                      title: Text(
                                        optionList[optionIndex].answer,
                                      ),
                                    );
                                  },
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
            );
          },
          whenNotDone: Center(
            child: LoadingAnimationWidget.inkDrop(
              color: Theme.of(context).primaryColor,
              size: 40,
            ),
          ),
        ),
      ),
    );
  }

  //获取用户选择的选项，以map形式记录

  // 获取用户选择的选项，以map形式记录
  List<Map<String, String>> getUserSelect() {
    List<Map<String, String>> selections = [];

    if (_questionSelections == null || saveQusetionList.isEmpty) {
      return selections; // 返回空列表如果没有数据
    }

    for (int i = 0; i < saveQusetionList.length; i++) {
      Map question = saveQusetionList[i];
      List<QuestionOption> options = question['optionList'];

      for (int j = 0; j < options.length; j++) {
        if (_questionSelections![i][j]) {
          selections.add({
            'targetid': question['targetId'], // 使用问题ID
            'targetval': options[j].optionId, // 使用选项ID
          });
          break; // 每个问题只选一个选项，找到后跳出内层循环
        }
      }
    }
    print(selections);
    return selections;
  }

  //一键完成
  Future<List<Map<String, String>>> autoFinishCommentary() async {
    List<Map<String, String>> selections = [];
    for (var i = 0; i < saveQusetionList.length; i++) {
      Map question = saveQusetionList[i];
      List<QuestionOption> options = question['optionList'];
      //循环找到最佳选项
      for (int j = 0; j < options.length; j++) {
        //选择一个不是最高的的
        if (i == 0) {
          print(options[j].optionScoreValue);
          if (double.parse(options[j].optionScoreValue) < 4.75) {
            //选择这一个
            selections.add({
              'targetid': question['targetId'], // 使用问题ID
              'targetval': options[j].optionId, // 使用选项ID
            });
            break;
          }
        } else {
          if (double.parse(options[j].optionScoreValue) >= 4.75) {
            //选择这一个
            selections.add({
              'targetid': question['targetId'], // 使用问题ID
              'targetval': options[j].optionId, // 使用选项ID
            });
            break;
          }
        }
      }
    }
    print(selections);
    return selections;
  }

  void toSubmitCommentary(List userSelect) async {
    String me = await submitCommentary(
      widget.batchId,
      widget.courseId,
      widget.evaluationCategoriesId,
      widget.teacherId,
      widget.noticeId,
      userSelect,
    );
    print(me);
    if (me == "success") {
      Navigator.pop(context);
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('提交成功~')));
    } else {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(me)));
    }
  }
}
