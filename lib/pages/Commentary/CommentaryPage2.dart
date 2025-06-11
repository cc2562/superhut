import 'package:enhanced_future_builder/enhanced_future_builder.dart';
import 'package:flutter/material.dart';
import 'package:loading_animation_widget/loading_animation_widget.dart';
import 'package:superhut/pages/Commentary/CommentaryPage3.dart';

import 'CommentaryApi.dart';

class commentaryPage2 extends StatefulWidget {
  final String pj01id;
  final String batchId;
  final String pj05id;

  const commentaryPage2({
    required this.batchId,
    required this.pj01id,
    required this.pj05id,
  });

  @override
  State<commentaryPage2> createState() => _commentaryPage2State();
}

class _commentaryPage2State extends State<commentaryPage2> {
  //获取列表
  Future<List> getList() async {
    print("YE");
    print('成功');
    print(widget.pj01id);
    List CommentaryList = await getCommentaryList(
      widget.pj01id,
      widget.batchId,
      widget.pj05id,
    );
    return CommentaryList;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).colorScheme.surface,
      appBar: AppBar(
        title: Text('学生教评'),
        elevation: 0,
        backgroundColor: Colors.transparent,
      ),
      body: EnhancedFutureBuilder(
        future: getList(),
        rememberFutureResult: false,
        whenDone: (List theCommentaryList) {
          return Container(
            margin: EdgeInsets.only(left: 10, right: 10),
            child: ListView.builder(
              itemCount: theCommentaryList.length,
              itemBuilder: (BuildContext context, int index) {
                Map theCommentary = theCommentaryList[index];
                return GestureDetector(
                  child: Card.filled(
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
                                  theCommentary['courseName'],
                                  style: TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.bold,
                                    color:
                                        Theme.of(context).colorScheme.onSurface,
                                  ),
                                ),
                                SizedBox(height: 5),
                                Text(
                                  '课程编号：${theCommentary['courseNumber']}',
                                  style: TextStyle(
                                    fontSize: 15,
                                    fontWeight: FontWeight.normal,
                                    color:
                                        Theme.of(context).colorScheme.onSurface,
                                  ),
                                ),
                                SizedBox(height: 5),
                                Text(
                                  theCommentary['ktmc'],
                                  maxLines: 1,
                                  style: TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.normal,
                                    color:
                                        Theme.of(context).colorScheme.onSurface,
                                  ),
                                ),
                                SizedBox(height: 5),
                                Text(
                                  '授课教师：${theCommentary['teacherName']}',
                                  style: TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.normal,
                                    color:
                                        Theme.of(context).colorScheme.onSurface,
                                  ),
                                ),
                                SizedBox(height: 5),
                                Chip(
                                  label: Text(
                                    theCommentary['isSubmitCode'] == '1'
                                        ? '已评教'
                                        : '未评教',
                                    style: TextStyle(color: Colors.white),
                                  ),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(50),
                                  ),
                                  backgroundColor:
                                      theCommentary['isSubmitCode'] == '1'
                                          ? Colors.green
                                          : Colors.red,
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  onTap: () {
                    if (theCommentary['isSubmitCode'] == '1') {
                      ScaffoldMessenger.of(
                        context,
                      ).showSnackBar(SnackBar(content: Text('已经评教过啦~不能重复评教')));
                      return;
                    }
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder:
                            (context) => commentaryPage3(
                              batchId: widget.batchId,
                              courseId: theCommentary['courseNumber'],
                              evaluationCategoriesId:
                                  theCommentary['evaluationCategoriesId'],
                              teacherId: theCommentary['teacherId'],
                              noticeId: theCommentary['noticeId'],
                            ),
                      ),
                    ).then((v) {
                      setState(() {
                        getList();
                      });
                    });
                  },
                );
              },
            ),
          );
        },
        whenNotDone: Center(
          child: LoadingAnimationWidget.inkDrop(
            color: Theme.of(context).primaryColor,
            size: 40,
          ),
        ),
      ),
    );
  }
}
