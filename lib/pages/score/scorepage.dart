import 'package:enhanced_future_builder/enhanced_future_builder.dart';
import 'package:flutter/material.dart';
import 'package:ionicons_plus/ionicons_plus.dart';
import 'package:loading_animation_widget/loading_animation_widget.dart';
import 'package:superhut/pages/score/logic.dart';
import 'package:superhut/theme/glass/glass_menu.dart';
import 'package:superhut/theme/glass/glass_scaffold.dart';
import 'package:superhut/theme/glass/glass_top_bar.dart';

class ScorePage extends StatefulWidget {
  const ScorePage({super.key});

  @override
  State<ScorePage> createState() => _ScorePageState();
}

class _ScorePageState extends State<ScorePage> {
  List semesterId = [];
  late String nowSemesterId = "all";
  late List<Score> scoreList;
  late String zxf, zxfjd, pjjd;
  String selectedId = "all";
  bool first = true;

  /// 学期选择按钮的锚点，用于定位玻璃菜单。
  final GlobalKey _semesterMenuKey = GlobalKey();

  /// 切换学期并刷新成绩（原 DropdownButton.onChanged 的逻辑）。
  Future<void> _loadScores(String id) async {
    setState(() => selectedId = id);
    ShowLoadingDialog();
    final Map scoreMap = await getScore(id == 'all' ? '' : id);
    if (!mounted) return;
    Navigator.of(context).pop(true);
    setState(() {
      scoreList = scoreMap['achievement'];
      zxf = scoreMap['yxzxf'];
      zxfjd = scoreMap['zxfjd'];
      pjjd = scoreMap['pjxfjd'];
    });
  }

  /// 顶部右上角的学期选择玻璃菜单。
  Future<void> _showSemesterMenu(BuildContext context) async {
    final box = _semesterMenuKey.currentContext?.findRenderObject();
    if (box is! RenderBox || !box.hasSize) return;
    final anchor = box.localToGlobal(Offset.zero) & box.size;
    final selected = await showGlassMenu<String>(
      context: context,
      anchor: anchor,
      items: [
        const GlassMenuItem(value: 'all', label: '全部'),
        for (final id in semesterId)
          GlassMenuItem<String>(value: id.toString(), label: id.toString()),
      ],
    );
    if (selected != null) await _loadScores(selected);
  }

  void ShowLoadingDialog() {
    showDialog(
      barrierDismissible: false,
      context: context,
      builder: (context) {
        return PopScope(
          canPop: false,
          child: Dialog(
            backgroundColor: Colors.transparent,
            child: LoadingAnimationWidget.inkDrop(
              color: Theme.of(context).primaryColor,
              size: 40,
            ),
          ),
        );
      },
    );
  }

  Future<void> getTimeList() async {
    if (first) {
      Map timeMap = await semesterIdfc();
      setState(() {
        semesterId = timeMap['idlist'];
        nowSemesterId = timeMap['nowid'];
      });
      Map scoreMap = await getScore(nowSemesterId);
      setState(() {
        selectedId = nowSemesterId;
        scoreList = scoreMap['achievement'];
        zxf = scoreMap['yxzxf'];
        zxfjd = scoreMap['zxfjd'];
        pjjd = scoreMap['pjxfjd'];
      });

      first = false;
    } else {
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
      whenDone: (da) {
        return GlassScaffold(
          title: '成绩查询',
          backgroundColor: Theme.of(context).colorScheme.surface,
          actions: [
            SizedBox(
              key: _semesterMenuKey,
              child: GlassActionButton(
                icon: Ionicons.funnel_outline,
                tooltip: '选择学期',
                semanticLabel: '选择学期',
                onPressed: () => _showSemesterMenu(context),
              ),
            ),
          ],
          // 顶部避让放在滚动容器 padding 里（而不是 Container margin），
          // 内容才能滚到玻璃下方，不会在顶栏下面留一条底色带。
          body: ListView.builder(
            padding: EdgeInsets.fromLTRB(10, glassTopInset(context), 10, 0),
            itemCount: scoreList.length + 1,
            itemBuilder: (context, index) {
              print(scoreList.length);
              if (scoreList.isEmpty) {
                return Column(
                  children: [
                    BigTopCard(),
                    SizedBox(height: 10),
                    Text("当前学期没有成绩"),
                  ],
                );
              }
              if (index == 0) {
                return BigTopCard();
              } else {
                var ins = index - 1;
                return Card.filled(
                  color: Theme.of(context).colorScheme.surfaceContainer,
                  child: Padding(
                    padding: EdgeInsets.all(10),
                    child: Flex(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      direction: Axis.horizontal,
                      children: [
                        Expanded(
                          flex: 10,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                scoreList[ins].courseName,
                                style: TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                  color:
                                      Theme.of(context).colorScheme.onSurface,
                                ),
                              ),
                              Row(
                                children: [
                                  Chip(
                                    label: Text(
                                      scoreList[ins].courseNature,
                                      style: TextStyle(fontSize: 12),
                                    ),
                                    backgroundColor:
                                        Theme.of(context).colorScheme.surface,
                                    padding: EdgeInsets.symmetric(
                                      vertical: 0,
                                      horizontal: 0,
                                    ),
                                  ),
                                  SizedBox(width: 5),
                                  Chip(
                                    label: Text(
                                      "绩点:${scoreList[ins].gradePoints}",
                                      style: TextStyle(fontSize: 12),
                                    ),
                                    backgroundColor:
                                        Theme.of(context).colorScheme.surface,
                                    padding: EdgeInsets.symmetric(
                                      vertical: 0,
                                      horizontal: 0,
                                    ),
                                  ),
                                  SizedBox(width: 5),
                                  Chip(
                                    label: Text(
                                      "学分:${scoreList[ins].credit}",
                                      style: TextStyle(fontSize: 12),
                                    ),
                                    backgroundColor:
                                        Theme.of(context).colorScheme.surface,
                                    padding: EdgeInsets.symmetric(
                                      vertical: 0,
                                      horizontal: 0,
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                        Expanded(
                          flex: 3,
                          child: Padding(
                            padding: EdgeInsets.only(right: 10),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.end,
                              children: [
                                Text(
                                  scoreList[ins].fraction,
                                  style: TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.bold,
                                    color:
                                        Theme.of(context).colorScheme.onSurface,
                                  ),
                                ),
                                Text(
                                  scoreList[ins].state,
                                  style: TextStyle(
                                    fontSize: 12,

                                    color:
                                        Theme.of(context).colorScheme.onSurface,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              }
            },
          ),
        );
      },
      whenNotDone: GlassScaffold(
        title: '成绩查询',
        body: Center(
          child: LoadingAnimationWidget.inkDrop(
            color: Theme.of(context).primaryColor,
            size: 40,
          ),
        ),
      ),
    );
  }

  Widget BigTopCard() {
    return Card.filled(
      color: Theme.of(context).colorScheme.surfaceContainer,
      child: Padding(
        padding: EdgeInsets.fromLTRB(20, 10, 20, 10),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              "成绩汇总",
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: Theme.of(context).primaryColor,
              ),
            ),
            SizedBox(height: 10),
            Flex(
              direction: Axis.horizontal,
              children: [
                Expanded(
                  child: Column(
                    children: [
                      Text(
                        "已修总学分",
                        style: TextStyle(color: Theme.of(context).primaryColor),
                      ),
                      Text(
                        zxf,
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: Theme.of(context).primaryColor,
                        ),
                      ),
                    ],
                  ),
                ),
                Expanded(
                  child: Column(
                    children: [
                      Text(
                        "总学分绩点",
                        style: TextStyle(color: Theme.of(context).primaryColor),
                      ),
                      Text(
                        zxfjd,
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: Theme.of(context).primaryColor,
                        ),
                      ),
                    ],
                  ),
                ),
                Expanded(
                  child: Column(
                    children: [
                      Text(
                        "平均学分绩点",
                        style: TextStyle(color: Theme.of(context).primaryColor),
                      ),
                      Text(
                        pjjd,
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: Theme.of(context).primaryColor,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            SizedBox(height: 10),
            TextButton(
              onPressed: () {},
              child: Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  Icon(Ionicons.help_circle_outline, size: 14),
                  Text("不同数据分别代表什么", style: TextStyle(fontSize: 12)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
