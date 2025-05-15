import 'package:enhanced_future_builder/enhanced_future_builder.dart';
import 'package:flutter/material.dart';
import 'package:ionicons/ionicons.dart';
import 'package:loading_animation_widget/loading_animation_widget.dart';
import 'package:superhut/pages/ExamSchedule/exam_schedule_bridge.dart';

class ExamSchedulePage extends StatefulWidget {
  const ExamSchedulePage({super.key});

  @override
  State<ExamSchedulePage> createState() => _ExamSchedulePageState();
}

class _ExamSchedulePageState extends State<ExamSchedulePage> {

  //定义安排MAP
  List examSchedules = [];
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

  Future getExamSchedule() async {
    examSchedules = await getSchedule();
    print(examSchedules);
    return true;
  }
  @override
  void initState() {
    super.initState();
  }
  @override
  Widget build(BuildContext context) {
    return EnhancedFutureBuilder(
        future: getExamSchedule(),
        rememberFutureResult: true,
        whenDone: (da){
          return Scaffold(
            backgroundColor: Theme.of(context).colorScheme.surface,
            appBar: AppBar(
              title: Text("考试安排"),

            ),
            body: Container(

                margin: EdgeInsets.only(left: 10,right: 10),
                child: ListView.builder(
                  itemCount: examSchedules.length,
                  itemBuilder: (context,index){
                    print(examSchedules.length);
                    if(examSchedules.isEmpty){
                      return Column(
                        children: [
                          SizedBox(height: 10,),
                          Text("当前学期暂时没有考试安排")
                        ],
                      );
                    }
                    else{
                      var ins = index;
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
                                          Text(examSchedules[ins]['courseName'],
                                              style: TextStyle(
                                                  fontSize: 18,
                                                  fontWeight: FontWeight.bold,
                                                  color: Theme
                                                      .of(context)
                                                      .colorScheme.onSurface
                                              )
                                          ),
                                          SizedBox(height: 5,),
                                          Row(
                                            children: [
                                              Icon(Ionicons.location,size: 20,color: Theme
                                                  .of(context)
                                                  .colorScheme.onSurface.withAlpha(100),),
                                              SizedBox(width: 5,),
                                              Text('${examSchedules[ins]['examinationPlace']}',style: TextStyle(
                                                  fontSize: 15,
                                                  fontWeight: FontWeight.normal,
                                                  color: Theme
                                                      .of(context)
                                                      .colorScheme.onSurface
                                              ),
                                              ),
                                            ],
                                          ),
                                          SizedBox(height: 5,),
                                          Row(
                                            children: [
                                              Icon(Ionicons.calendar,size: 20,color: Theme
                                                  .of(context)
                                                  .colorScheme.onSurface.withAlpha(100),),
                                              SizedBox(width: 5,),
                                              Text('${examSchedules[ins]['time']}',style: TextStyle(
                                                  fontSize: 14,
                                                  fontWeight: FontWeight.normal,
                                                  color: Theme
                                                      .of(context)
                                                      .colorScheme.onSurface
                                              ),
                                              ),
                                            ],
                                          ),
                                          SizedBox(height: 10,),
                                          Row(
                                            crossAxisAlignment: CrossAxisAlignment.end,
                                            mainAxisAlignment: MainAxisAlignment.end,
                                            children: [
                                              Text('${examSchedules[ins]['courseNumber']}',style: TextStyle(
                                                  fontSize: 8,
                                                  fontWeight: FontWeight.normal,
                                                  color: Theme
                                                      .of(context)
                                                      .colorScheme.onSurface.withAlpha(100)
                                              ),
                                                textAlign: TextAlign.end,
                                              ),
                                            ],
                                          )
                                        ],
                                      ),
                                    ),

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
            title: Text("考试安排"),
          ),
          body: Center(
            child:  LoadingAnimationWidget.inkDrop(color: Theme.of(context).primaryColor, size: 40),
          ),
        ));
  }
}
