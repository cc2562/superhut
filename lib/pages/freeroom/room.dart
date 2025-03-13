import 'package:flutter/material.dart';
class FreeRoomPage extends StatefulWidget {
  const FreeRoomPage({super.key});

  @override
  State<FreeRoomPage> createState() => _FreeRoomPageState();
}

class _FreeRoomPageState extends State<FreeRoomPage> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).colorScheme.surface,
      appBar: AppBar(
        title: const Text('河西校区-公共楼'),
      ),
      body: Flex(direction: Axis.vertical,
      children: [
        Flex(direction: Axis.horizontal,
          children: [
            Expanded(
              child:  Row(
                children: [
                  Text('日期'),
                  DropdownButton(
                    onChanged: (v) async {

                    },
                    borderRadius: BorderRadius.circular(10),
                    menuWidth: 150,
                    alignment: Alignment.centerRight,
                    enableFeedback: true,
                    isExpanded: false,
                    value: 'all',underline: Container(height: 0,),
                    items: [
                      DropdownMenuItem(
                          value: "all",
                          child: Text("2025-03-12")
                      ),
                      DropdownMenuItem(
                          value: "11",
                          child: Text("2025-03-12")
                      ),
                      //   ...semesterId.map((e) => DropdownMenuItem(
                      //     value: e,
                      //      child: Text(e)
                      // )
                      // )
                    ],
                  )
                ],
              ),
            ),
            Expanded(
              child:   Row(
                children: [
                  Text('节次'),
                  DropdownButton(
                    onChanged: (v) async {

                    },
                    borderRadius: BorderRadius.circular(10),
                    menuWidth: 150,
                    alignment: Alignment.centerRight,
                    enableFeedback: true,
                    isExpanded: false,
                    value: 'all',underline: Container(height: 0,),
                    items: [
                      DropdownMenuItem(
                          value: "all",
                          child: Text("2025-03-12")
                      ),
                      DropdownMenuItem(
                          value: "11",
                          child: Text("2025-03-12")
                      ),
                      //   ...semesterId.map((e) => DropdownMenuItem(
                      //     value: e,
                      //      child: Text(e)
                      // )
                      // )
                    ],
                  )
                ],
              ),
            ),
          ],
        ),
        Expanded(
          child: SingleChildScrollView(
            child: Column(
              children: [

                ListView.builder(
                    physics: NeverScrollableScrollPhysics(),
                    shrinkWrap: true,
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
                                            Text('公共110（多媒体教室）',
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
                                                    '总座位数:129',
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
                    }
                )
              ],
            ),
          ),
        )
      ],
      )
    );
  }
}
