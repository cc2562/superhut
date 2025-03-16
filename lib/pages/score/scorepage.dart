import 'package:enhanced_future_builder/enhanced_future_builder.dart';
import 'package:flutter/material.dart';
import 'package:ionicons/ionicons.dart';
import 'package:loading_animation_widget/loading_animation_widget.dart';
import 'package:superhut/pages/score/logic.dart';

class ScorePage extends StatefulWidget {
  const ScorePage({super.key});

  @override
  State<ScorePage> createState() => _ScorePageState();
}





class _ScorePageState extends State<ScorePage> {

  List semesterId = [];
  late String nowSemesterId="all";
  late List<Score> scoreList;
  late String zxf,zxfjd,pjjd;
  String selectedId ="all";
  bool first = true;


  void ShowLoadingDialog(){
    showDialog(
      barrierDismissible: false,
        context: context,
        builder: (context){
          return PopScope(
            canPop: false,
            child: Dialog(
              backgroundColor: Colors.transparent,
              child: LoadingAnimationWidget.inkDrop(color: Theme.of(context).primaryColor, size: 40),
            ),
          );
        }
    );
  }
  Future<void> getTimeList() async {
    if(first) {



      Map timeMap = await semesterIdfc();
      Map scoreMap = await getScore(nowSemesterId);
      setState(() {
        semesterId = timeMap['idlist'];
        nowSemesterId = timeMap['nowid'];
        selectedId = nowSemesterId;
        scoreList = scoreMap['achievement'];
        zxf = scoreMap['yxzxf'];
        zxfjd = scoreMap['zxfjd'];
        pjjd = scoreMap['pjxfjd'];
      });
      first =false;
    }else{
      return;
    }
  }
  @override
  void initState() {
    super.initState();

  }

  @override
  Widget build(BuildContext context) {
    return EnhancedFutureBuilder(
        future: getTimeList(),
        rememberFutureResult: true,
        whenDone: (da){
          return Scaffold(
            backgroundColor: Theme.of(context).colorScheme.surface,
            appBar: AppBar(
              title: Text("成绩查询"),
              actions: [
                DropdownButton(
                  onChanged: (v) async {
                    setState(() {
                      selectedId =v.toString();
                    });
                    ShowLoadingDialog();
                    if(selectedId=="all"){
                      Map scoreMap = await getScore("");
                      Navigator.of(context).pop(true);
                      setState(() {
                        scoreList = scoreMap['achievement'];
                        zxf = scoreMap['yxzxf'];
                        zxfjd = scoreMap['zxfjd'];
                        pjjd = scoreMap['pjxfjd'];
                      });
                    }else{
                      Map scoreMap = await getScore(selectedId);
                      Navigator.of(context).pop(true);
                      setState(() {
                        scoreList = scoreMap['achievement'];
                        zxf = scoreMap['yxzxf'];
                        zxfjd = scoreMap['zxfjd'];
                        pjjd = scoreMap['pjxfjd'];
                      });
                    }
                  },
                  borderRadius: BorderRadius.circular(10),
                  menuWidth: 150,
                  alignment: Alignment.centerRight,
                  enableFeedback: true,
                  isExpanded: false,
                  value: selectedId,underline: Container(height: 0,),
                  items: [
                    DropdownMenuItem(
                        value: "all",
                        child: Text("全部")
                    ),
                    ...semesterId.map((e) => DropdownMenuItem(
                        value: e,
                        child: Text(e)
                    ))
                  ],
                ),
              ],

            ),
            body: Container(

                margin: EdgeInsets.only(left: 10,right: 10),
                child: ListView.builder(
                  itemCount: scoreList.length+1,
                  itemBuilder: (context,index){
                    print(scoreList.length);
                    if(scoreList.isEmpty){
                      return Column(
                        children: [
                          BigTopCard(),
                          SizedBox(height: 10,),
                          Text("当前学期没有成绩")
                        ],
                      );
                    }
                    if(index==0){
                      return BigTopCard();
                    }
                    else{
                      var ins = index - 1;
                      return Card.filled(
                          color: Theme
                              .of(context)
                              .colorScheme
                              .surfaceContainer,
                          child: Padding(padding: EdgeInsets.all(10),
                              child: Flex(
                                  crossAxisAlignment: CrossAxisAlignment
                                      .start,
                                  direction: Axis.horizontal,
                                  children: [
                                    Expanded(
                                      flex: 10,
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment
                                            .start,
                                        children: [
                                          Text(scoreList[ins].courseName,
                                              style: TextStyle(
                                                  fontSize: 18,
                                                  fontWeight: FontWeight.bold,
                                                  color: Theme
                                                      .of(context)
                                                      .colorScheme.onSurface
                                              )
                                          ),
                                          Row(
                                            children: [
                                              Chip(label: Text(
                                                  scoreList[ins].courseNature,
                                                  style: TextStyle(
                                                    fontSize: 12,
                                                  )
                                              ),
                                                backgroundColor: Theme
                                                    .of(context)
                                                    .colorScheme
                                                    .surface,
                                                padding: EdgeInsets.symmetric(
                                                    vertical: 0,
                                                    horizontal: 0),
                                              ),
                                              SizedBox(width: 5,),
                                              Chip(label: Text(
                                                  "绩点:${scoreList[ins]
                                                      .gradePoints}",
                                                  style: TextStyle(
                                                    fontSize: 12,
                                                  )
                                              ),
                                                backgroundColor: Theme
                                                    .of(context)
                                                    .colorScheme
                                                    .surface,
                                                padding: EdgeInsets.symmetric(
                                                    vertical: 0,
                                                    horizontal: 0),
                                              ),
                                              SizedBox(width: 5,),
                                              Chip(label: Text(
                                                  "学分:${scoreList[ins]
                                                      .credit}",
                                                  style: TextStyle(
                                                    fontSize: 12,
                                                  )
                                              ),
                                                backgroundColor: Theme
                                                    .of(context)
                                                    .colorScheme
                                                    .surface,
                                                padding: EdgeInsets.symmetric(
                                                    vertical: 0,
                                                    horizontal: 0),
                                              ),
                                            ],
                                          )
                                        ],
                                      ),
                                    ),
                                    Expanded(
                                        flex: 3,
                                        child: Padding(
                                          padding: EdgeInsets.only(right: 10),
                                          child: Column(
                                            crossAxisAlignment: CrossAxisAlignment
                                                .end,
                                            children: [
                                              Text(scoreList[ins].fraction,
                                                  style: TextStyle(
                                                      fontSize: 18,
                                                      fontWeight: FontWeight
                                                          .bold,
                                                      color: Theme
                                                          .of(context)
                                                          .colorScheme.onSurface
                                                  )
                                              ),
                                              Text(scoreList[ins].state,
                                                  style: TextStyle(
                                                      fontSize: 12,

                                                      color: Theme
                                                          .of(context)
                                                          .colorScheme.onSurface
                                                  )
                                              ),
                                            ],
                                          ),
                                        )
                                    )
                                  ]
                              )
                          )
                      );
                    }
                  },
                )
            ),
          );
        },
        whenNotDone: Scaffold(
          appBar: AppBar(
            title: Text("成绩查询"),
          ),
          body: Center(
            child:  LoadingAnimationWidget.inkDrop(color: Theme.of(context).primaryColor, size: 40),
          ),
        ));
  }

  Widget BigTopCard(){
    return Card.filled(
        color: Theme.of(context).colorScheme.surfaceContainer,
        child: Padding(padding: EdgeInsets.fromLTRB(20, 10, 20, 10),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text("成绩汇总",
                style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: Theme.of(context).primaryColor
                ),
              ),
              SizedBox(height: 10,),
              Flex(
                direction: Axis.horizontal,
                children: [
                  Expanded(child: Column(
                    children: [
                      Text("已修总学分",
                        style: TextStyle(

                            color: Theme.of(context).primaryColor
                        ),
                      ),
                      Text(zxf,
                        style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: Theme.of(context).primaryColor
                        ),
                      ),
                    ],
                  )),
                  Expanded(child: Column(
                    children: [
                      Text("总学分绩点",
                        style: TextStyle(

                            color: Theme.of(context).primaryColor
                        ),
                      ),
                      Text(zxfjd,
                        style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: Theme.of(context).primaryColor
                        ),
                      ),
                    ],
                  )),
                  Expanded(child: Column(
                    children: [
                      Text("平均学分绩点",
                        style: TextStyle(

                            color: Theme.of(context).primaryColor
                        ),
                      ),
                      Text(pjjd,
                        style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: Theme.of(context).primaryColor
                        ),
                      ),
                    ],
                  )),
                ],
              ),
              SizedBox(height: 10,),
              TextButton(onPressed: (){}, child: Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  Icon(Ionicons.help_circle_outline,size: 14,),
                  Text("不同数据分别代表什么",style: TextStyle(fontSize: 12),)
                ],
              ))
            ],
          ),
        )
    );
  }
}
