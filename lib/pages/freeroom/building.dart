import 'package:enhanced_future_builder/enhanced_future_builder.dart';
import 'package:flutter/material.dart';
import 'package:loading_animation_widget/loading_animation_widget.dart';
import 'package:superhut/pages/freeroom/room.dart';
import 'package:superhut/command/roomapi.dart';

import 'buildingBridge.dart';

class BuildingPage extends StatefulWidget {
  const BuildingPage({super.key});

  @override
  State<BuildingPage> createState() => _BuildingPageState();
}

class _BuildingPageState extends State<BuildingPage> {

  @override
  void initState() {
    // TODO: implement initState
    super.initState();
    GetBuilding();
  }
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).colorScheme.surface,
      appBar: AppBar(
        title: const Text('选择教学楼'),
      ),
      body: EnhancedFutureBuilder(
          future: GetBuilding(),
          rememberFutureResult: true,
          whenDone: (data){
        return Container(
          margin: EdgeInsets.only(left: 10,right: 10),
          child: ListView.builder(
            itemCount: data.length,
            itemBuilder: (context, index) {
              return Card.filled(
                  color: Theme
                      .of(context)
                      .colorScheme.surfaceContainer,
                  child: InkWell(
                    onTap: (){
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder:
                              (context) =>FreeRoomPage(buildingId: data[index].buildingId,buildingName: data[index].name,),
                        ),
                      );
                    },
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
                                    Text(data[index].name,
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
                                            '总教室数:${data[index].count}',
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
                            ]
                        )
                    ),
                  )
              );
            },

          ),
        );
          },
          whenNotDone: Center(child: LoadingAnimationWidget.inkDrop(color: Theme.of(context).primaryColor, size: 40),)

      ),
    );
  }
}
