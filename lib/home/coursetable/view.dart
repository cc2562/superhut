import 'dart:async';
import 'dart:math' as math;

import 'package:dynamic_color/dynamic_color.dart';
import 'package:enhanced_future_builder/enhanced_future_builder.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:intl/intl.dart';
import 'package:ionicons_plus/ionicons_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../theme/glass/glass_menu.dart';
import '../../theme/glass/glass_overlays.dart';
import '../../theme/glass/glass_segmented.dart';
import '../../theme/glass/glass_theme.dart';
import '../../theme/glass/glass_top_bar.dart';
import '../../utils/course/coursemain.dart';
import '../../utils/course/class_time_table.dart';
import '../../widget_refresh_service.dart';
import 'course_table_scroll_behavior.dart';
import 'logic.dart';
import 'schedule/custom_schedule_controller.dart';
import 'schedule/custom_schedule_detail_sheet.dart';
import 'schedule/custom_schedule_editor_page.dart';
import 'schedule/custom_schedule_event.dart';
import 'schedule/schedule_block.dart';
import 'schedule/schedule_timeline.dart';
import 'style/course_card_surface.dart';
import 'style/course_table_style.dart';
import 'style/course_table_style_controller.dart';
import '../../utils/course/getCourse.dart';
import '../../live_activity/class_live_activity_controller.dart';
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

  /// 自定义日程由 main 注册；这里兜底，避免直接进入课表页时取不到。
  late final CustomScheduleController _scheduleController =
      CustomScheduleController.maybeInstance ??
      Get.put(CustomScheduleController());

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

  /// 左上角「第 X 周」区域的锚点，用于定位玻璃菜单。
  final GlobalKey _weekSelectorKey = GlobalKey();

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

  /// 打开「回到当前周 / 回到今天」玻璃菜单，锚定在左上角周数区域下方。
  Future<void> _showDateMenu(BuildContext context) async {
    final box = _weekSelectorKey.currentContext?.findRenderObject();
    if (box is! RenderBox || !box.hasSize) return;
    final anchor = box.localToGlobal(Offset.zero) & box.size;
    final selected = await showGlassMenu<String>(
      context: context,
      anchor: anchor,
      items: [
        GlassMenuItem(
          value: 'current',
          label: _viewMode == CourseTableViewMode.day ? '回到今天' : '回到当前周',
          icon: Ionicons.locate_outline,
        ),
      ],
    );
    if (selected == 'current' && mounted) _backToRealWeek();
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
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final base =
        HSLColor.fromAHSL(
          1,
          hue.toDouble(),
          0.62,
          // 深色主题里把亮度抬高一点，避免色块在深背景上发闷。
          isDark ? 0.58 : 0.52,
        ).toColor();
    return base.harmonizeWith(Theme.of(context).colorScheme.primary);
  }

  /*
   * 当前课表外观设置（背景、课程块材质与文字色）。
   * 由「我的 → 课表外观」页写入，这里只读。
   */
  CourseTableStyle get _style =>
      CourseTableStyleController.instance.style.value;

  /*
   * 页面底色估算，供课程块的自适应文字判断对比度。
   */
  Color get _pageEstimate =>
      _style.estimatedPageColor(Theme.of(context).colorScheme);

  /* 某一天要画的全部块：教务课程 + 当天生效的自定义日程。 */
  List<DayBlock> _blocksOn(DateTime day) {
    return buildDayBlocks(
      courses: _courseData[_dateKey(day)] ?? const <Course>[],
      schedules: _scheduleController.eventsOn(day),
    );
  }

  Color _accentFor(DayBlock block) => block.isCourse
      ? _getCourseColor(block.course!.name)
      : block.schedule!.color;

  void _openBlock(DayBlock block) {
    if (block.isCourse) {
      _showCourseDetails(block.course!);
    } else {
      _showScheduleDetails(block.schedule!);
    }
  }

  String _formatMinutes(int minutes) {
    final int value = minutes.clamp(0, 24 * 60);
    final String hh = (value ~/ 60).toString().padLeft(2, '0');
    final String mm = (value % 60).toString().padLeft(2, '0');
    return '$hh:$mm';
  }

  String _blockTimeText(DayBlock block) =>
      '${_formatMinutes(block.startMinute)}–${_formatMinutes(block.endMinute)}';

  /*
   * 一列 = 一个定高 Stack：块按真实时间绝对定位，课间留出与真实时长一致的空白。
   * 时间重叠的块不合并成一块，而是按开始时间依次向右「扇出」，
   * 后开始的压在上层、右侧对齐，每块都露出自己的彩色左边。
   */
  Widget _buildDayColumn(
    List<DayBlock> blocks,
    TimelineWindow window,
    CourseTableStyle style,
  ) {
    final List<TimelineCluster<DayBlock>> clusters = clusterTimelineItems(
      blocks,
      startOf: (DayBlock block) => block.startMinute,
      endOf: (DayBlock block) => block.endMinute,
    );

    return SizedBox(
      height: window.height,
      child: LayoutBuilder(
        builder: (BuildContext context, BoxConstraints constraints) {
          final double columnWidth = constraints.maxWidth;
          return Stack(
            clipBehavior: Clip.hardEdge,
            children: <Widget>[
              for (final TimelineCluster<DayBlock> cluster in clusters)
                ..._buildStackedBlocks(cluster, columnWidth, window, style),
            ],
          );
        },
      ),
    );
  }

  List<Widget> _buildStackedBlocks(
    TimelineCluster<DayBlock> cluster,
    double columnWidth,
    TimelineWindow window,
    CourseTableStyle style,
  ) {
    final double step = cascadeStep(columnWidth: columnWidth);

    return <Widget>[
      for (int level = 0; level < cluster.items.length; level++)
        _buildBlockSlot(
          block: cluster.items[level],
          columnWidth: columnWidth,
          level: level,
          step: step,
          window: window,
          style: style,
        ),
    ];
  }

  Widget _buildBlockSlot({
    required DayBlock block,
    required double columnWidth,
    required int level,
    required double step,
    required TimelineWindow window,
    required CourseTableStyle style,
  }) {
    final double top = window.topFor(block.startMinute);
    final double rawHeight = window.heightForRange(
      block.startMinute,
      block.endMinute,
    );
    final double available = math.max(0, window.height - top);
    // 过短的事件（如 10 分钟）保底 22px 保证点得到；超出窗口底部时裁掉。
    final double height = math.max(rawHeight, 22).clamp(0, available).toDouble();

    // 缩进最多一层：第 0 块全宽，后面的块都缩进同一格并依次压在上层。
    final double inset = step * math.min(level, 1);
    final double width = math.max(1, columnWidth - 2 - inset);

    return Positioned(
      left: 1 + inset,
      width: width,
      top: top,
      height: height,
      child: _buildBlockCard(block, style, height),
    );
  }

  /* 单个块：课程与日程共用 CourseCardSurface，只有识别色与副标题不同。 */
  Widget _buildBlockCard(DayBlock block, CourseTableStyle style, double height) {
    final Color accent = _accentFor(block);
    final Color foreground = style.courseForeground(
      accent,
      pageEstimate: _pageEstimate,
    );
    final Color muted = foreground.withValues(alpha: 0.82);
    // 只有块太矮（< 44px）时才只留标题，避免 RenderFlex 溢出。
    // 不能按宽度判「窄」：手机七列布局单列本来就只有 45–53dp，
    // 否则所有块都会被判窄、地点与教师整片消失。
    final bool compact = height < 44;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 1),
      child: CourseCardSurface(
        accent: accent,
        style: style,
        borderRadius: 8,
        child: Material(
          type: MaterialType.transparency,
          child: InkWell(
            borderRadius: BorderRadius.circular(8),
            onTap: () => _openBlock(block),
            child: Padding(
              padding: const EdgeInsets.all(2),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Expanded(
                    child: Text(
                      block.title,
                      style: TextStyle(
                        color: foreground,
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                      ),
                      maxLines: 5,
                      overflow: TextOverflow.fade,
                    ),
                  ),
                  // 课程与自定义日程都显示地点；没填地点的日程不占这一行。
                  if (!compact && block.location.isNotEmpty)
                    Text(
                      block.location,
                      style: TextStyle(color: muted, fontSize: 10),
                      maxLines: block.isCourse ? 2 : 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  if (!compact && block.isCourse && block.secondary.isNotEmpty)
                    Text(
                      block.secondary,
                      style: TextStyle(color: muted, fontSize: 10),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  if (!compact && !block.isCourse)
                    Text(
                      _blockTimeText(block),
                      style: TextStyle(color: muted, fontSize: 10),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                ],
              ),
            ),
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
    showGlassDraggableSheet(
      context: context,
      initialChildSize: course.isExp ? 0.62 : 0.52,
      minChildSize: 0.35,
      maxChildSize: 0.85,
      bodyBuilder:
          (context, controller) => ListView(
            controller: controller,
            padding: const EdgeInsets.fromLTRB(24, 4, 24, 24),
            children: [
              Text(course.name, style: Theme.of(context).textTheme.titleLarge),
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
    );
  }

  /// 课表页右上角的「+」：玻璃开启时是圆形玻璃控件，关闭时回落 Material。
  Widget _buildAddScheduleButton() {
    if (context.glassTheme.enabled) {
      return GlassControlButton(
        icon: Icons.add_rounded,
        size: 34,
        iconSize: 18,
        tooltip: '新建日程',
        semanticLabel: '新建日程',
        onTap: _openScheduleEditor,
      );
    }
    return IconButton.filledTonal(
      onPressed: _openScheduleEditor,
      tooltip: '新建日程',
      icon: const Icon(Icons.add_rounded, size: 18),
      padding: EdgeInsets.zero,
      constraints: const BoxConstraints.tightFor(width: 34, height: 34),
      visualDensity: VisualDensity.compact,
    );
  }

  /// 新建 / 编辑日程；保存后由 Obx 监听控制器自动刷新课表。
  Future<void> _openScheduleEditor({CustomScheduleEvent? event}) async {
    // 周视图默认落在今天（不在本周时落在本周一），日视图就是当前天。
    final DateTime initialDate =
        _viewMode == CourseTableViewMode.day
            ? _currentDate
            : (_currentWeek == _currentRealWeek
                ? normalizeCourseDate(DateTime.now())
                : _getStartOfWeek(_currentDate));
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder:
            (BuildContext context) => CustomScheduleEditorPage(
              event: event,
              initialDate: initialDate,
              semesterFirstDay: _scheduleController.semesterFirstDay.value,
              semesterMaxWeek: _scheduleController.semesterMaxWeek.value,
            ),
      ),
    );
  }

  void _showScheduleDetails(CustomScheduleEvent event) {
    showGlassDraggableSheet(
      context: context,
      initialChildSize: 0.52,
      minChildSize: 0.3,
      maxChildSize: 0.85,
      bodyBuilder:
          (BuildContext context, ScrollController controller) =>
              CustomScheduleDetailSheet(
                event: event,
                scrollController: controller,
                onEdit: () => _openScheduleEditor(event: event),
                onDelete: () => _scheduleController.remove(event.id),
              ),
    );
  }

  Widget _buildNextCourseCard(CourseTableStyle style) {
    final courses = _courseData[_dateKey(_currentDate)] ?? const <Course>[];
    final nextCourses = findNextCoursesForDay(
      day: _currentDate,
      now: _now,
      courses: courses,
    );
    final colorScheme = Theme.of(context).colorScheme;

    return SizedBox(
      width: double.infinity,
      child: Padding(
        // 原 Card 的 margin，改材质后手动保留，避免日视图整体位移。
        padding: const EdgeInsets.fromLTRB(4, 0, 4, 10),
        child: CourseMaterialSurface(
          // 不是课程块，没有课程色：用主题色作基底，材质/模糊/不透明度跟随外观设置。
          tint: style.surfaceTint(colorScheme.primaryContainer),
          style: style,
          borderRadius: 12,
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
                          style: TextStyle(
                            color: colorScheme.onPrimaryContainer,
                          ),
                        ),
                      ],
                    );
                  }),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildDayTimeline(CourseTableStyle style) {
    final List<DayBlock> blocks = _blocksOn(_currentDate);
    if (blocks.isEmpty) {
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
            const Text('今天没有课程或日程'),
          ],
        ),
      );
    }

    // 同上：日视图的课程卡也是玻璃材质，拉伸期间同样会闪断。
    return ScrollConfiguration(
      behavior: const CourseTableScrollBehavior(),
      child: ListView.separated(
        padding: const EdgeInsets.only(bottom: 100),
        itemCount: blocks.length,
        separatorBuilder: (_, _) => const SizedBox(height: 10),
        itemBuilder: (BuildContext context, int index) {
          final DayBlock block = blocks[index];
          return Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SizedBox(
                width: 78,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      _blockTimeText(block),
                      maxLines: 1,
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      block.isCourse ? block.sectionLabel : '日程',
                      style: TextStyle(
                        color:
                            block.isCourse
                                ? Theme.of(context).colorScheme.outline
                                : _accentFor(block),
                        fontSize: 12,
                        fontWeight:
                            block.isCourse ? FontWeight.normal : FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child:
                    block.isCourse
                        ? _buildDayCourseCard(block, style)
                        : _buildDayScheduleCard(block),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildDayCourseCard(DayBlock block, CourseTableStyle style) {
    final Course course = block.course!;
    final Color courseColor = _accentFor(block);
    final Color onCourse = style.courseForeground(
      courseColor,
      pageEstimate: _pageEstimate,
    );
    final Color onCourseMuted = onCourse.withValues(alpha: 0.82);

    return CourseCardSurface(
      accent: courseColor,
      style: style,
      borderRadius: 12,
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () => _showCourseDetails(course),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                course.name,
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  color: onCourse,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                course.location.isEmpty ? '地点待定' : course.location,
                style: TextStyle(color: onCourseMuted),
              ),
              if (course.teacherName.isNotEmpty) ...[
                const SizedBox(height: 3),
                Text(
                  course.teacherName,
                  style: TextStyle(color: onCourseMuted),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  /// 日视图里的日程卡：Material 3 实心卡 + 左侧色条，与课程卡一眼可分。
  Widget _buildDayScheduleCard(DayBlock block) {
    final CustomScheduleEvent event = block.schedule!;
    final ColorScheme scheme = Theme.of(context).colorScheme;
    final Color accent = event.color;

    return Material(
      color: scheme.surfaceContainerHigh,
      borderRadius: BorderRadius.circular(12),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => _showScheduleDetails(event),
        child: IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Container(width: 4, color: accent),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(12, 12, 14, 12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        event.title,
                        style: Theme.of(context).textTheme.titleMedium
                            ?.copyWith(fontWeight: FontWeight.w600),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        event.location.isEmpty ? '地点待定' : event.location,
                        style: TextStyle(color: scheme.onSurfaceVariant),
                      ),
                      if (event.note.isNotEmpty) ...[
                        const SizedBox(height: 3),
                        Text(
                          event.note,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(color: scheme.onSurfaceVariant),
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
    // 自定义日程与课表分开加载：刷新课表不会覆盖它，这里只补一次内存状态。
    await _scheduleController.ensureLoaded();
    LiveNotificationManager.syncSchedule(_courseData);
    // iOS 灵动岛与 Android 实时通知共用同一份课表快照，互不影响。
    ClassLiveActivityController.maybeInstance?.syncSchedule(_courseData);
  }

  Widget _buildWeekHeader(List<DateTime> weekDays) {
    final scheme = Theme.of(context).colorScheme;
    final CourseTableStyle style = _style;
    return Row(
      children: [
        const Expanded(child: SizedBox()),
        ...weekDays.map((day) {
          final bool isToday = isSameCourseDate(day, _now);
          final String showText =
              '${_weekdayMap[day.weekday]!}\n${DateFormat('M-d').format(day)}';
          final Widget label = Padding(
            padding: const EdgeInsets.symmetric(vertical: 6),
            child: Text(
              showText,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.labelSmall?.copyWith(
                color:
                    isToday
                        ? scheme.onPrimaryContainer
                        : scheme.onSurfaceVariant,
                fontWeight: FontWeight.w600,
              ),
              maxLines: 2,
            ),
          );
          return Expanded(
            flex: 4,
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 8),
              // 只有今天需要表面：其余六格保持透明，不为它们各建一层空表面。
              child:
                  isToday
                      ? CourseMaterialSurface(
                        tint: style.surfaceTint(scheme.primaryContainer),
                        style: style,
                        borderRadius: 12,
                        child: label,
                      )
                      : label,
            ),
          );
        }),
      ],
    );
  }

  Widget _buildWeekGrid(List<DateTime> weekDays, CourseTableStyle style) {
    final Map<String, List<DayBlock>> blocksByDay = <String, List<DayBlock>>{
      for (final DateTime day in weekDays) _dateKey(day): _blocksOn(day),
    };
    // 七列共用一条固定纵轴：第 1 节到第 12 节（11、12 节是给自定义日程预留的
    // 显示范围），不随当周内容收缩，没课的节次也保留空格子；午休在轴上被折叠。
    final TimelineWindow window = TimelineWindow.weekGrid();
    final List<TimelineSection> sections = sectionsInsideWindow(window);
    final ColorScheme scheme = Theme.of(context).colorScheme;

    // 不挂 overscroll 指示器：安卓 12+ 的拉伸会逐帧缩放滚动内容，
    // 课程卡的模糊（BackdropFilter）会因此闪断，详见 CourseTableScrollBehavior。
    return ScrollConfiguration(
      behavior: const CourseTableScrollBehavior(),
      child: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.only(bottom: 100),
          child: SizedBox(
            height: window.height,
            child: Stack(
              children: <Widget>[
                // 节次分隔线：只做视觉参考，不参与命中测试。
                Positioned.fill(
                  child: IgnorePointer(
                    child: CustomPaint(
                      painter: _SectionGridPainter(
                        window: window,
                        sections: sections,
                        gutterWidth: 40,
                        color: scheme.outlineVariant.withValues(alpha: 0.45),
                      ),
                    ),
                  ),
                ),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    SizedBox(
                      width: 40,
                      height: window.height,
                      child: Stack(
                        children: <Widget>[
                          for (final TimelineSection section in sections)
                            Positioned(
                              left: 0,
                              right: 0,
                              top: window.topFor(section.startMinute),
                              height: window.heightForRange(
                                section.startMinute,
                                section.endMinute,
                              ),
                              child: Align(
                                alignment: Alignment.topCenter,
                                child: Padding(
                                  padding: const EdgeInsets.only(top: 2),
                                  child: Text(
                                    '${section.section}',
                                    style: TextStyle(
                                      color: scheme.onSurfaceVariant,
                                      fontSize: 10,
                                      height: 1.1,
                                    ),
                                  ),
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),
                    ...weekDays.map((DateTime day) {
                      return Expanded(
                        child: _buildDayColumn(
                          blocksByDay[_dateKey(day)] ?? const <DayBlock>[],
                          window,
                          style,
                        ),
                      );
                    }),
                  ],
                ),
              ],
            ),
          ),
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
      // 背景由首页外壳（homeview）整页铺设，这里必须透明才能透出背景图。
      backgroundColor: Colors.transparent,
      body: SafeArea(
        child: EnhancedFutureBuilder(
          future: _initializationFuture,
          rememberFutureResult: true,
          whenDone: (_) {
            // 只有课表内容订阅外观设置，切换材质/透明度时不重建外壳。
            return Obx(() {
              // 先读一次：整周没有课程时页面上没有任何课程块，若不在这里
              // 订阅，GetX 会因为 builder 未读到可观察变量而报错。
              final CourseTableStyle style =
                  CourseTableStyleController.instance.style.value;
              return _buildContent(
                context,
                style,
                weekDays,
                headerDateText,
                isViewingToday,
              );
            });
          },
          whenError: (_) => const Center(child: Text('课程表加载失败，请重新进入页面')),
          whenNotDone: const Center(child: Text('课程表加载中…')),
        ),
      ),
    );
  }

  /// 课表页正文：外观设置只影响课程块与文字颜色，布局保持原样。
  Widget _buildContent(
    BuildContext context,
    CourseTableStyle style,
    List<DateTime> weekDays,
    String headerDateText,
    bool isViewingToday,
  ) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 10),
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(4, 10, 4, 8),
            child: Row(
              children: [
                Expanded(
                  child: Align(
                    alignment: Alignment.centerLeft,
                    child: Material(
                      type: MaterialType.transparency,
                      child: InkWell(
                        key: _weekSelectorKey,
                        borderRadius: BorderRadius.circular(12),
                        onTap: () => _showDateMenu(context),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 4,
                            vertical: 2,
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                '第$_currentWeek周',
                                style: Theme.of(context).textTheme.headlineSmall
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
                    ),
                  ),
                ),
                GlassSegmented<CourseTableViewMode>(
                  segments: const [
                    GlassSegment(value: CourseTableViewMode.week, label: '周'),
                    GlassSegment(value: CourseTableViewMode.day, label: '日'),
                  ],
                  selected: _viewMode,
                  onChanged: _setViewMode,
                ),
                const SizedBox(width: 8),
                _buildAddScheduleButton(),
              ],
            ),
          ),
          if (_viewMode == CourseTableViewMode.week) _buildWeekHeader(weekDays),
          if (_viewMode == CourseTableViewMode.day && isViewingToday)
            _buildNextCourseCard(style),
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
                      ? _buildDayTimeline(style)
                      : _buildWeekGrid(weekDays, style),
            ),
          ),
        ],
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
    showGlassSheet<void>(
      context: context,
      isScrollControlled: true,
      padding: EdgeInsets.zero,
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

/// 周视图背景：按节次开始时间在日列上画横向分隔线。
///
/// 时间轴改成真实比例后，节次之间出现与课间时长一致的空白，
/// 这些细线让「第几节」仍然可读，又不抢课程块的注意力。
class _SectionGridPainter extends CustomPainter {
  const _SectionGridPainter({
    required this.window,
    required this.sections,
    required this.gutterWidth,
    required this.color,
  });

  final TimelineWindow window;
  final List<TimelineSection> sections;
  final double gutterWidth;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final Paint paint =
        Paint()
          ..color = color
          ..strokeWidth = 0.6;
    for (final TimelineSection section in sections) {
      final double y = window.topFor(section.startMinute);
      if (y <= 1 || y >= size.height - 1) continue;
      canvas.drawLine(Offset(gutterWidth, y), Offset(size.width, y), paint);
    }
  }

  @override
  bool shouldRepaint(covariant _SectionGridPainter oldDelegate) =>
      oldDelegate.window != window ||
      oldDelegate.sections.length != sections.length ||
      oldDelegate.color != color;
}
