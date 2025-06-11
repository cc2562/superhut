import 'package:enhanced_future_builder/enhanced_future_builder.dart';
import 'package:flutter/material.dart';
import 'package:ionicons/ionicons.dart';
import 'package:loading_animation_widget/loading_animation_widget.dart';
import 'package:superhut/pages/Commentary/CommentaryApi.dart';
import 'package:superhut/pages/Commentary/CommentaryPage2.dart';

class commentaryPage1 extends StatefulWidget {
  const commentaryPage1({super.key});

  @override
  State<commentaryPage1> createState() => _commentaryPage1State();
}

class _commentaryPage1State extends State<commentaryPage1> {
  //获取批次
  Future<List> getBatches() async {
    print("YE");
    print('刷新啦！！！！！！！！！！！！！！！！！！！！');
    List batches = await getCommentaryBatch();
    return batches;
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
        future: getBatches(),
        rememberFutureResult: false,
        whenDone: (List batchesList) {
          return Container(
            margin: EdgeInsets.only(left: 10, right: 10),
            child: ListView.builder(
              itemCount: batchesList.length,
              itemBuilder: (BuildContext context, int index) {
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
                                  batchesList[index]['EVALUATIONBATCH'],
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
                                      batchesList[index]['KCLBMC'],
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
                                      batchesList[index]['XQMC'],
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
                              ],
                            ),
                          ),
                          Expanded(
                            child: Container(
                              decoration: BoxDecoration(shape: BoxShape.circle),
                              padding: EdgeInsets.all(8),
                              alignment: Alignment.center,
                              child: Icon(Icons.arrow_forward, size: 16),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder:
                            (context) => commentaryPage2(
                              batchId: batchesList[index]['BATCHID'],
                              pj01id: batchesList[index]['PJ01ID'],
                              pj05id: batchesList[index]['PJ05ID'],
                            ),
                      ),
                    );
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
