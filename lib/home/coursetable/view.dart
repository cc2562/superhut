import 'dart:async';

import 'package:dynamic_color/dynamic_color.dart';
import 'package:enhanced_future_builder/enhanced_future_builder.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:intl/intl.dart';
import 'package:ionicons_plus/ionicons_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../utils/course/coursemain.dart';
import '../../utils/course/class_time_table.dart';
import '../../widget_refresh_service.dart';
import 'logic.dart';
import '../../utils/course/getCourse.dart';
import '../../live_notification_manager.dart';

class CourseTableView extends StatefulWidget {
  const CourseTableView({super.key});

  @override
  State<CourseTableView> createState() => _CourseTableViewState();
}

/*
 * 课程数据模型类
 * @param name 课程名称
 * @param startSection 课程开始的节数（1-based）
 * @param duration 课程持续节数
 */

DateTime getMondayOfCurrentWeek() {
  final DateTime now = DateTime.now();
  // 计算当前日期与本周一的差值（星期一对应的weekday为1）
  int daysToSubtract = now.weekday - 1;
  // 处理周日的情况（Dart中周日weekday=7）
  if (now.weekday == 7) {
    daysToSubtract = 6;
  }
  // 刷新桌面小组件
  WidgetRefreshService.refreshCourseTableWidget();
  return now.subtract(Duration(days: daysToSubtract));
}

class _CourseTableViewState extends State<CourseTableView> {
  static const String _viewModePreferenceKey = 'courseTableViewMode';

  final CourseTableViewLogic logic = Get.put(CourseTableViewLogic());

  // DateTime _currentDate = DateTime.now();
  DateTime _currentDate = getMondayOfCurrentWeek();

  //设置周数
  //当前显示周数
  int _currentWeek = 1;
  int _allWeek = 100;

  //当前实际周数
  int _currentRealWeek = 1;

  CourseTableViewMode _viewMode = CourseTableViewMode.week;
  DateTime _now = DateTime.now();
  Timer? _clockTimer;
  late final Future<void> _initializationFuture;

  /*
   * 课程数据存储器
   * Key格式：yyyy-MM-dd 的日期字符串
   * Value：当天课程列表
   */
  late Map<String, List<Course>> _courseData = {};

  // 定义一个映射来存储 weekday 数字到中文星期名称的对应关系
  final Map<int, String> _weekdayMap = {
    1: '周一',
    2: '周二',
    3: '周三',
    4: '周四',
    5: '周五',
    6: '周六',
    7: '周日',
  };

  @override
  void initState() {
    super.initState();
    _initializationFuture = _initializeCourseTable();
    _clockTimer = Timer.periodic(const Duration(minutes: 1), (_) {
      if (!mounted) return;
      setState(() {
        _now = DateTime.now();
      });
    });
    //_loadExampleData();
    //_courseData = testc();
  }

  @override
  void dispose() {
    _clockTimer?.cancel();
    super.dispose();
  }

  Future<void> getWeek() async {
    final prefs = await SharedPreferences.getInstance();
    _allWeek = prefs.getInt('maxWeek') ?? 1;
    final calculatedWeek = calculateSchoolWeekFromFirstDay(
      prefs.getString('firstDay'),
      DateTime.now(),
    );
    if (calculatedWeek == null) {
      return;
    }
    _currentWeek = calculatedWeek;
    _currentRealWeek = calculatedWeek;
  }

  /*
   * 获取指定日期所在周的起始日期（周一）
   * @param date 要计算的日期
   * @return 当周周一对应的日期对象
   */
  DateTime _getStartOfWeek(DateTime date) {
    return date.subtract(Duration(days: date.weekday - 1));
  }

  void _backToRealWeek() {
    final today = normalizeCourseDate(DateTime.now());
    if (_currentWeek == _currentRealWeek &&
        (_viewMode == CourseTableViewMode.week ||
            isSameCourseDate(_currentDate, today))) {
      return;
    }
    setState(() {
      _currentDate =
          _viewMode == CourseTableViewMode.day ? today : _getStartOfWeek(today);
      _currentWeek = _currentRealWeek;
    });
  }

  /*
   * 切换到上个月视图
   * 更新_currentDate为上月第一天
   */
  void _previousWeek() {
    if (_currentWeek <= 1) {
      return;
    }
    setState(() {
      _currentDate = DateTime(
        _currentDate.year,
        _currentDate.month,
        _currentDate.day - 7,
      );
      _currentWeek = _currentWeek - 1;
    });
  }

  void _previousDay() {
    final selection = moveCourseTableDay(
      date: _currentDate,
      currentWeek: _currentWeek,
      allWeeks: _allWeek,
      dayDelta: -1,
    );
    setState(() {
      _currentDate = selection.date;
      _currentWeek = selection.week;
    });
  }

  /*
   * 切换到下个月视图
   * 更新_currentDate为下月第一天
   */
  void _nextWeek() {
    if (_currentWeek >= _allWeek) {
      return;
    }
    setState(() {
      _currentDate = DateTime(
        _currentDate.year,
        _currentDate.month,
        _currentDate.day + 7,
      );
      _currentWeek = _currentWeek + 1;
    });
  }

  void _nextDay() {
    final selection = moveCourseTableDay(
      date: _currentDate,
      currentWeek: _currentWeek,
      allWeeks: _allWeek,
      dayDelta: 1,
    );
    setState(() {
      _currentDate = selection.date;
      _currentWeek = selection.week;
    });
  }

  void _goToPreviousPeriod() {
    if (_viewMode == CourseTableViewMode.day) {
      _previousDay();
    } else {
      _previousWeek();
    }
  }

  void _goToNextPeriod() {
    if (_viewMode == CourseTableViewMode.day) {
      _nextDay();
    } else {
      _nextWeek();
    }
  }

  Future<void> _setViewMode(CourseTableViewMode mode) async {
    if (_viewMode == mode) return;
    final today = normalizeCourseDate(DateTime.now());
    setState(() {
      if (mode == CourseTableViewMode.day) {
        _currentDate =
            _currentWeek == _currentRealWeek
                ? today
                : _getStartOfWeek(_currentDate);
      } else {
        _currentDate = _getStartOfWeek(_currentDate);
      }
      _viewMode = mode;
    });
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_viewModePreferenceKey, mode.name);
  }

  /*
   * 生成日期格式化键
   * @param date 要格式化的日期对象
   * @return yyyy-MM-dd格式的日期字符串
   */
  String _dateKey(DateTime date) => DateFormat('yyyy-MM-dd').format(date);

  /*
   * 根据课程名称生成固定颜色
   * @param seed 颜色生成种子字符串（课程名称）
   * @return HSL颜色空间生成的固定颜色
   */
  Color _getCourseColor(String seed) {
    final hue = seed.hashCode.abs() % 360;
    final base = HSLColor.fromAHSL(1, hue.toDouble(), 0.55, 0.55).toColor();
    return base.harmonizeWith(Theme.of(context).colorScheme.primary);
  }

  /*
   * 构建单日课程时间表布局
   * @param courses 当天的课程列表
   * @return 包含课程块和空白时间段的组件列表
   * 实现逻辑：
   * 1. 按开始节数排序课程
   * 2. 检查是否有重叠的课程，如果有则将它们放在同一个位置显示
   * 3. 填充课程之间的空白时间段
   * 4. 保证最多显示到第6节课
   */
  List<Widget> _buildDayCourses(List<Course> courses) {
    courses.sort((a, b) => a.startSection.compareTo(b.startSection));
    final widgets = <Widget>[];
    int currentSection = 1;

    for (int i = 0; i < courses.length; i++) {
      final course = courses[i];
      while (currentSection < course.startSection) {
        widgets.add(_buildTimeSlot(currentSection));
        currentSection++;
      }

      // 检查是否有重叠的课程
      List<Course> overlappingCourses = [course];
      for (int j = i + 1; j < courses.length; j++) {
        if (courses[j].startSection < course.startSection + course.duration) {
          overlappingCourses.add(courses[j]);
        } else {
          break;
        }
      }

      // 如果有重叠的课程，将它们放在同一个位置显示
      if (overlappingCourses.length > 1) {
        widgets.add(_buildOverlappingCourses(overlappingCourses));
        currentSection += course.duration;
        i += overlappingCourses.length - 1; // 跳过已经处理的重叠课程
      } else {
        widgets.add(_buildCourseItem(course));
        currentSection += course.duration;
      }
    }

    while (currentSection <= 10) {
      widgets.add(_buildTimeSlot(currentSection));
      currentSection++;
    }

    return widgets;
  }

  /*
   * 构建重叠课程显示块
   * @param courses 重叠的课程列表
   * @return 包含多个课程名称的彩色区块组件
   */
  Widget _buildOverlappingCourses(List<Course> courses) {
    double marginTB = 0, marginT = 1;
    if (courses[0].duration >= 2) {
      marginTB = courses[0].duration.toDouble();
    }
    if (courses[0].startSection == 1) {
      marginT = 0;
    }

    final scheme = Theme.of(context).colorScheme;
    final accent = _getCourseColor(courses.first.name);
    return Container(
      alignment: Alignment.topLeft,
      height: 60 * courses[0].duration.toDouble() + marginTB,
      decoration: BoxDecoration(
        border: Border(left: BorderSide(color: accent, width: 3)),
        color: scheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(6),
      ),
      margin: EdgeInsets.fromLTRB(1, marginT, 1, 1),
      padding: const EdgeInsets.all(2),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children:
            courses.map((course) {
              return Expanded(
                child: InkWell(
                  onTap: () => _showCourseDetails(course),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        course.name,
                        style: TextStyle(
                          color: scheme.onSurface,
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                        ),
                        textAlign: TextAlign.left,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      Text(
                        course.location,
                        style: TextStyle(
                          color: scheme.onSurfaceVariant,
                          fontSize: 10,
                          fontWeight: FontWeight.normal,
                        ),
                        textAlign: TextAlign.left,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      Text(
                        course.teacherName,
                        style: TextStyle(
                          color: scheme.onSurfaceVariant,
                          fontSize: 10,
                          fontWeight: FontWeight.normal,
                        ),
                        textAlign: TextAlign.left,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
              );
            }).toList(),
      ),
    );
  }

  /*
   * 构建单个课程显示块
   * @param course 课程对象
   * @return 包含课程名称的彩色区块组件
   */
  Widget _buildCourseItem(Course course) {
    double marginTB = 0, marginT = 1;
    if (course.duration >= 2) {
      marginTB = course.duration.toDouble();
    }
    if (course.startSection == 1) {
      marginT = 0;
    }
    final scheme = Theme.of(context).colorScheme;
    final accent = _getCourseColor(course.name);

    return Container(
      alignment: Alignment.topLeft,
      height: 60 * course.duration.toDouble() + marginTB,
      decoration: BoxDecoration(
        border: Border(left: BorderSide(color: accent, width: 3)),
        color: scheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(6),
      ),
      margin: EdgeInsets.fromLTRB(1, marginT, 1, 1),
      padding: const EdgeInsets.all(2),
      child: InkWell(
        onTap: () => _showCourseDetails(course),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Text(
                course.name,
                style: TextStyle(
                  color: scheme.onSurface,
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                ),
                textAlign: TextAlign.left,
                maxLines: 5,
                overflow: TextOverflow.fade,
              ),
            ),
            Text(
              course.location,
              style: TextStyle(
                color: scheme.onSurfaceVariant,
                fontSize: 10,
                fontWeight: FontWeight.normal,
              ),
              textAlign: TextAlign.left,
            ),
            Text(
              course.teacherName,
              style: TextStyle(
                color: scheme.onSurfaceVariant,
                fontSize: 10,
                fontWeight: FontWeight.normal,
              ),
              textAlign: TextAlign.left,
            ),
          ],
        ),
      ),
    );
  }

  /*
   * 构建空白时间段占位组件
   * @param section 当前节数编号
   * @return 带有节数标识的灰色边框占位块
   */
  Widget _buildTimeSlot(int section) {
    double marginT = 1;
    if (section == 1) {
      marginT = 0;
    }
    return Container(
      height: 60,
      decoration: BoxDecoration(
        //border: Border.all(color: Colors.grey.withOpacity(0.5)),
        //border: Border.all(color: Colors.grey.withOpacity(0.5)),
      ),
      margin: EdgeInsets.fromLTRB(1, marginT, 1, 1),
      child: Center(
        child: Text(
          '',
          style: TextStyle(
            color: Theme.of(context).colorScheme.onSurfaceVariant,
            fontSize: 10,
          ),
        ),
      ),
    );
  }

  String _courseTimeText(DateTime day, Course course) {
    final range = ClassTimeTable.getCourseTimeRange(day, course);
    return '${DateFormat('HH:mm').format(range['start']!)}–${DateFormat('HH:mm').format(range['end']!)}';
  }

  String _courseSectionText(Course course) {
    final endSection = course.startSection + course.duration - 1;
    return '第${course.startSection}–$endSection节';
  }

  void _showCourseDetails(Course course) {
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      builder:
          (context) => SafeArea(
            child: DraggableScrollableSheet(
              expand: false,
              initialChildSize: course.isExp ? 0.62 : 0.52,
              minChildSize: 0.35,
              maxChildSize: 0.85,
              builder:
                  (context, controller) => ListView(
                    controller: controller,
                    padding: const EdgeInsets.fromLTRB(24, 4, 24, 24),
                    children: [
                      Text(
                        course.name,
                        style: Theme.of(context).textTheme.titleLarge,
                      ),
                      const SizedBox(height: 10),
                      ListTile(
                        leading: Icon(
                          Ionicons.calendar_outline,
                          color: Theme.of(context).colorScheme.primary,
                        ),
                        title: Text(course.weekDuration),
                      ),
                      ListTile(
                        leading: Icon(
                          Ionicons.time_outline,
                          color: Theme.of(context).colorScheme.primary,
                        ),
                        title: Text(_courseSectionText(course)),
                      ),
                      ListTile(
                        leading: Icon(
                          Ionicons.person_outline,
                          color: Theme.of(context).colorScheme.primary,
                        ),
                        title: Text(course.teacherName),
                      ),
                      ListTile(
                        leading: Icon(
                          Ionicons.location_outline,
                          color: Theme.of(context).colorScheme.primary,
                        ),
                        title: Text(course.location),
                      ),
                      if (course.isExp && course.pcid.isNotEmpty)
                        ListTile(
                          leading: Icon(
                            Ionicons.people_outline,
                            color: Theme.of(context).colorScheme.primary,
                          ),
                          title: const Text('查看人员名单'),
                          onTap: () {
                            Navigator.pop(context);
                            _showExpStudents(course.pcid);
                          },
                        ),
                    ],
                  ),
            ),
          ),
    );
  }

  Widget _buildNextCourseCard() {
    final courses = _courseData[_dateKey(_currentDate)] ?? const <Course>[];
    final nextCourses = findNextCoursesForDay(
      day: _currentDate,
      now: _now,
      courses: courses,
    );
    final colorScheme = Theme.of(context).colorScheme;

    return SizedBox(
      width: double.infinity,
      child: Card.filled(
        margin: const EdgeInsets.fromLTRB(4, 0, 4, 10),
        color: colorScheme.primaryContainer,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '下一节课',
                style: TextStyle(
                  color: colorScheme.onPrimaryContainer,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),
              if (nextCourses.isEmpty)
                Text(
                  '今天没有下一节课',
                  style: TextStyle(color: colorScheme.onPrimaryContainer),
                )
              else
                ...nextCourses.indexed.map((entry) {
                  final index = entry.$1;
                  final course = entry.$2;
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (index > 0)
                        Divider(
                          color: colorScheme.onPrimaryContainer.withAlpha(50),
                        ),
                      Text(
                        course.name,
                        style: TextStyle(
                          color: colorScheme.onPrimaryContainer,
                          fontSize: 17,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        '${_courseTimeText(_currentDate, course)}  ${course.location}',
                        style: TextStyle(color: colorScheme.onPrimaryContainer),
                      ),
                    ],
                  );
                }),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDayTimeline() {
    final courses = sortCoursesForDay(
      _courseData[_dateKey(_currentDate)] ?? const <Course>[],
    );
    if (courses.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Ionicons.calendar_outline,
              size: 42,
              color: Theme.of(context).colorScheme.outline,
            ),
            const SizedBox(height: 10),
            const Text('当天没有课程'),
          ],
        ),
      );
    }

    return ListView.separated(
      padding: const EdgeInsets.only(bottom: 100),
      itemCount: courses.length,
      separatorBuilder: (_, _) => const SizedBox(height: 10),
      itemBuilder: (context, index) {
        final course = courses[index];
        final scheme = Theme.of(context).colorScheme;
        final courseColor = _getCourseColor(course.name);
        return Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(
              width: 78,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    _courseTimeText(_currentDate, course),
                    maxLines: 1,
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    _courseSectionText(course),
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.outline,
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Card.filled(
                margin: EdgeInsets.zero,
                color: scheme.surfaceContainerHigh,
                child: InkWell(
                  onTap: () => _showCourseDetails(course),
                  child: IntrinsicHeight(
                    child: Row(
                      children: [
                        Container(width: 4, color: courseColor),
                        Expanded(
                          child: Padding(
                            padding: const EdgeInsets.all(14),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  course.name,
                                  style: Theme.of(
                                    context,
                                  ).textTheme.titleMedium?.copyWith(
                                    color: scheme.onSurface,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  course.location.isEmpty
                                      ? '地点待定'
                                      : course.location,
                                  style: TextStyle(
                                    color: scheme.onSurfaceVariant,
                                  ),
                                ),
                                if (course.teacherName.isNotEmpty) ...[
                                  const SizedBox(height: 3),
                                  Text(
                                    course.teacherName,
                                    style: TextStyle(
                                      color: scheme.onSurfaceVariant,
                                    ),
                                  ),
                                ],
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  Future<void> _initializeCourseTable() async {
    final prefs = await SharedPreferences.getInstance();
    _viewMode = courseTableViewModeFromPreference(
      prefs.getString(_viewModePreferenceKey),
    );
    await getWeek();
    if (_viewMode == CourseTableViewMode.day) {
      _currentDate = normalizeCourseDate(DateTime.now());
    }
    _courseData = await loadClassFromLocal();
    LiveNotificationManager.syncSchedule(_courseData);
  }

  Widget _buildWeekHeader(List<DateTime> weekDays) {
    final scheme = Theme.of(context).colorScheme;
    return Row(
      children: [
        const Expanded(child: SizedBox()),
        ...weekDays.map((day) {
          final showText =
              '${_weekdayMap[day.weekday]!}\n${DateFormat('M-d').format(day)}';
          return Expanded(
            flex: 4,
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: DecoratedBox(
                decoration: BoxDecoration(
                  color:
                      isSameCourseDate(day, _now)
                          ? scheme.primaryContainer
                          : Colors.transparent,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 6),
                  child: Text(
                    showText,
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.labelSmall?.copyWith(
                      color:
                          isSameCourseDate(day, _now)
                              ? scheme.onPrimaryContainer
                              : scheme.onSurfaceVariant,
                      fontWeight: FontWeight.w600,
                    ),
                    maxLines: 2,
                  ),
                ),
              ),
            ),
          );
        }),
      ],
    );
  }

  Widget _buildWeekGrid(List<DateTime> weekDays) {
    return SingleChildScrollView(
      child: Padding(
        padding: const EdgeInsets.only(bottom: 100),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: SizedBox(
                width: 40,
                child: Column(
                  children: List.generate(10, (index) {
                    return Container(
                      height: 60,
                      margin: const EdgeInsets.fromLTRB(0, 1, 0, 1),
                      alignment: Alignment.center,
                      child: Text(
                        '${index + 1}',
                        style: TextStyle(
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                          fontSize: 10,
                        ),
                      ),
                    );
                  }),
                ),
              ),
            ),
            ...weekDays.map((day) {
              return Expanded(
                flex: 4,
                child: Padding(
                  padding: const EdgeInsets.only(top: 1),
                  child: Column(
                    children: _buildDayCourses(
                      _courseData[_dateKey(day)] ?? [],
                    ),
                  ),
                ),
              );
            }),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final weekStart = _getStartOfWeek(_currentDate);
    final weekDays = List.generate(7, (i) => weekStart.add(Duration(days: i)));
    final headerDateText =
        _viewMode == CourseTableViewMode.day
            ? '${DateFormat('M月d日').format(_currentDate)} ${_weekdayMap[_currentDate.weekday]}'
            : '${DateFormat('M月d日').format(weekDays.first)} – ${DateFormat('M月d日').format(weekDays.last)}';
    final isViewingToday = isSameCourseDate(_currentDate, _now);
    return Scaffold(
      backgroundColor: Theme.of(context).colorScheme.surface,
      body: SafeArea(
        child: EnhancedFutureBuilder(
          future: _initializationFuture,
          rememberFutureResult: true,
          whenDone: (_) {
            return Padding(
              padding: const EdgeInsets.symmetric(horizontal: 10),
              child: Column(
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(4, 10, 4, 8),
                    child: Row(
                      children: [
                        Expanded(
                          child: PopupMenuButton<String>(
                            tooltip: '日期选项',
                            position: PopupMenuPosition.under,
                            onSelected: (_) => _backToRealWeek(),
                            itemBuilder:
                                (_) => [
                                  PopupMenuItem(
                                    value: 'current',
                                    child: Text(
                                      _viewMode == CourseTableViewMode.day
                                          ? '回到今天'
                                          : '回到当前周',
                                    ),
                                  ),
                                ],
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  '第$_currentWeek周',
                                  style: Theme.of(context)
                                      .textTheme
                                      .headlineSmall
                                      ?.copyWith(fontWeight: FontWeight.w700),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  headerDateText,
                                  style: Theme.of(
                                    context,
                                  ).textTheme.bodySmall?.copyWith(
                                    color:
                                        Theme.of(
                                          context,
                                        ).colorScheme.onSurfaceVariant,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                        SegmentedButton<CourseTableViewMode>(
                          showSelectedIcon: false,
                          segments: const [
                            ButtonSegment(
                              value: CourseTableViewMode.week,
                              label: Text('周'),
                            ),
                            ButtonSegment(
                              value: CourseTableViewMode.day,
                              label: Text('日'),
                            ),
                          ],
                          selected: {_viewMode},
                          onSelectionChanged:
                              (selection) => _setViewMode(selection.first),
                        ),
                      ],
                    ),
                  ),
                  if (_viewMode == CourseTableViewMode.week)
                    _buildWeekHeader(weekDays),
                  if (_viewMode == CourseTableViewMode.day && isViewingToday)
                    _buildNextCourseCard(),
                  Expanded(
                    child: GestureDetector(
                      behavior: HitTestBehavior.opaque,
                      onHorizontalDragEnd: (details) {
                        final velocity = details.primaryVelocity ?? 0;
                        if (velocity > 10) {
                          _goToPreviousPeriod();
                        } else if (velocity < -10) {
                          _goToNextPeriod();
                        }
                      },
                      child:
                          _viewMode == CourseTableViewMode.day
                              ? _buildDayTimeline()
                              : _buildWeekGrid(weekDays),
                    ),
                  ),
                ],
              ),
            );
          },
          whenError: (_) => const Center(child: Text('课程表加载失败，请重新进入页面')),
          whenNotDone: const Center(child: Text('课程表加载中…')),
        ),
      ),
    );
  }

  Future<void> _showExpStudents(String pcid) async {
    if (pcid.isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('无法获取人员名单：缺少pcid，请在设置页刷新课表')));
      return;
    }
    Map re = await getExpStudentList(pcid);
    if (re['code']?.toString() != '1') {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('获取人员名单失败')));
      return;
    }
    Map data = re['data'] ?? {};
    Map baseData = data['baseData'] ?? {};
    List stu = data['studentList'] ?? [];

    if (!mounted) return;
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      builder:
          (context) => SafeArea(
            child: SizedBox(
              height: MediaQuery.sizeOf(context).height * 0.72,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(24, 4, 24, 0),
                    child: Text(
                      '${baseData['kcmc']?.toString() ?? ''} - ${baseData['pcname']?.toString() ?? ''}',
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(24, 6, 24, 10),
                    child: Text(
                      '学期：${baseData['xnxqmc']?.toString() ?? ''}',
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ),
                  Expanded(
                    child: ListView.separated(
                      padding: const EdgeInsets.only(bottom: 24),
                      itemCount: stu.length,
                      separatorBuilder: (_, _) => const Divider(height: 1),
                      itemBuilder: (context, index) {
                        var it = stu[index];
                        return ListTile(
                          leading: Icon(
                            Ionicons.person_outline,
                            color: Theme.of(context).colorScheme.primary,
                          ),
                          title: Text(it['xm']?.toString() ?? ''),
                          subtitle: Text(
                            '学号: ' +
                                (it['xh']?.toString() ?? '') +
                                '  班级: ' +
                                (it['bj']?.toString() ?? ''),
                          ),
                          trailing: Text(it['xbmc']?.toString() ?? ''),
                        );
                      },
                    ),
                  ),
                ],
              ),
            ),
          ),
    );
  }
}
