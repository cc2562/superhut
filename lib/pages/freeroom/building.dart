import 'package:flutter/material.dart';
import 'package:superhut/pages/freeroom/room.dart';

class BuildingPage extends StatefulWidget {
  const BuildingPage({super.key});

  @override
  State<BuildingPage> createState() => _BuildingPageState();
}

class _BuildingPageState extends State<BuildingPage> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).colorScheme.surface,
      appBar: AppBar(
        title: const Text('选择教学楼'),
      ),
      body: Center(
        child: ListView.builder(
          itemCount: 10,
          itemBuilder: (context, index) {
            return Card.filled(
                color: Theme
                    .of(context)
                    .colorScheme
                    .surfaceContainer,
                child: InkWell(
                  onTap: (){
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder:
                            (context) =>FreeRoomPage(),
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
                                  Text('河西校区-计算机楼',
                                      style: TextStyle(
                                          fontSize: 18,
                                          fontWeight: FontWeight.bold,
                                          color: Theme
                                              .of(context)
                                              .primaryColor
                                      )
                                  ),
                                  Row(
                                    children: [
                                      Chip(label: Text(
                                          '总教室数:22',
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
      ),
    );
  }
}
