import 'dart:math' as math;

import 'package:flex_color_picker/flex_color_picker.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:uuid/uuid.dart';

import '../../../theme/glass/glass_scaffold.dart';
import '../../../theme/glass/glass_segmented.dart';
import '../../../theme/glass/glass_top_bar.dart';
import '../../../utils/course/class_time_table.dart';
import '../logic.dart' show calculateSchoolWeekFromFirstDay;
import 'custom_schedule_controller.dart';
import 'custom_schedule_event.dart';

/// 时间录入方式：直接挑节次，或自定义时分。
enum _ScheduleTimeMode { section, custom }

/// 新建 / 编辑自定义日程。
///
/// 保存成功后 `pop(event)`，课表页据此刷新（Obx 已在监听控制器）。
class CustomScheduleEditorPage extends StatefulWidget {
  const CustomScheduleEditorPage({
    super.key,
    this.event,
    this.initialDate,
    this.semesterFirstDay = '',
    this.semesterMaxWeek = 0,
  });

  final CustomScheduleEvent? event;

  /// 从课表页进入时带的日期（日视图为当前天，周视图为本周一）。
  final DateTime? initialDate;

  final String semesterFirstDay;
  final int semesterMaxWeek;

  @override
  State<CustomScheduleEditorPage> createState() =>
      _CustomScheduleEditorPageState();
}

class _CustomScheduleEditorPageState extends State<CustomScheduleEditorPage> {
  late final CustomScheduleController _controller =
      CustomScheduleController.maybeInstance ??
      Get.put(CustomScheduleController());

  late final TextEditingController _titleController;
  late final TextEditingController _locationController;
  late final TextEditingController _noteController;

  late DateTime _date;
  late TimeOfDay _startTime;
  late TimeOfDay _endTime;

  /// 时间录入方式；两种方式共用 [_startTime] / [_endTime] 作为最终落库值。
  _ScheduleTimeMode _timeMode = _ScheduleTimeMode.section;

  /// 按节次录入时的起止节次（1-based），切换节次后立刻换算回时分。
  int _startSection = 1;
  int _endSection = 1;

  ScheduleRepeat _repeat = ScheduleRepeat.none;
  DateTime? _repeatUntil;
  late List<int> _weeks;
  late int _colorArgb;

  bool _saving = false;
  bool _customColorExpanded = false;

  /// 「自定义周次」开关：关闭时每周重复（weeks 存空列表）。
  bool _customWeeks = false;

  bool get _isEditing => widget.event != null;

  int get _maxWeek => math.max(widget.semesterMaxWeek, 1);

  @override
  void initState() {
    super.initState();
    final CustomScheduleEvent? event = widget.event;
    _titleController = TextEditingController(text: event?.title ?? '');
    _locationController = TextEditingController(text: event?.location ?? '');
    _noteController = TextEditingController(text: event?.note ?? '');

    final DateTime now = DateTime.now();
    final DateTime baseDate =
        event?.start ??
        widget.initialDate ??
        DateTime(now.year, now.month, now.day);

    _date = DateTime(baseDate.year, baseDate.month, baseDate.day);
    if (event != null) {
      _startTime = TimeOfDay.fromDateTime(event.start);
      _endTime = TimeOfDay.fromDateTime(event.end);
      // 起止时刻正好落在节次边界上时用「按节次」回显，否则保持自定义时分。
      final int? startSection = _sectionStartingAt(_startTime);
      final int? endSection = _sectionEndingAt(_endTime);
      if (startSection != null &&
          endSection != null &&
          endSection >= startSection) {
        _timeMode = _ScheduleTimeMode.section;
        _startSection = startSection;
        _endSection = endSection;
      } else {
        _timeMode = _ScheduleTimeMode.custom;
        _startSection = _nearestSectionFor(_startTime);
        _endSection = math.max(_startSection, _nearestSectionFor(_endTime));
      }
      _repeat = event.repeat;
      _repeatUntil = event.repeatUntil;
      _weeks = event.weeks.toList();
      _customWeeks = event.repeat == ScheduleRepeat.weekly && event.weeks.isNotEmpty;
      _colorArgb = event.colorArgb;
    } else {
      // 新建默认落在当前时间之后的第一节课：挑节次比调时分更快。
      _timeMode = _ScheduleTimeMode.section;
      _startSection = _firstSectionAfter(TimeOfDay.fromDateTime(now));
      _endSection = _startSection;
      _applySectionRange();
      _repeat = ScheduleRepeat.none;
      _weeks = <int>[];
      _colorArgb = ScheduleColors.defaultColor;
    }

    // 默认周次：新建时勾当前周，编辑时用已选周次。
    if (_weeks.isEmpty) {
      final int? currentWeek = calculateSchoolWeekFromFirstDay(
        widget.semesterFirstDay,
        _date,
      );
      if (currentWeek != null && currentWeek > 0 && currentWeek <= _maxWeek) {
        _weeks = <int>[currentWeek];
      }
    }
  }

  @override
  void dispose() {
    _titleController.dispose();
    _locationController.dispose();
    _noteController.dispose();
    super.dispose();
  }

  DateTime get _startDateTime => DateTime(
    _date.year,
    _date.month,
    _date.day,
    _startTime.hour,
    _startTime.minute,
  );

  DateTime get _endDateTime => DateTime(
    _date.year,
    _date.month,
    _date.day,
    _endTime.hour,
    _endTime.minute,
  );

  bool get _timeRangeValid => _endDateTime.isAfter(_startDateTime);

  bool get _canSave => _titleController.text.trim().isNotEmpty && _timeRangeValid;

  Future<void> _pickDate() async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _date,
      firstDate: DateTime(2020),
      lastDate: DateTime(2100),
    );
    if (picked != null && mounted) {
      setState(() => _date = picked);
    }
  }

  /// Material 时间选择器，强制 24 小时制（不受系统 12/24 设置影响）。
  Future<TimeOfDay?> _pickTime24({required TimeOfDay initial}) {
    return showTimePicker(
      context: context,
      initialTime: initial,
      builder: (BuildContext context, Widget? child) {
        return MediaQuery(
          data: MediaQuery.of(
            context,
          ).copyWith(alwaysUse24HourFormat: true),
          child: child!,
        );
      },
    );
  }

  Future<void> _pickTimeRange() async {
    final TimeOfDay? start = await _pickTime24(initial: _startTime);
    if (!mounted) return;
    if (start == null) return;
    setState(() => _startTime = start);

    final TimeOfDay? end = await _pickTime24(initial: _endTime);
    if (!mounted) return;
    if (end == null) return;
    setState(() => _endTime = end);
  }

  String _formatTime(TimeOfDay time) =>
      '${time.hour.toString().padLeft(2, '0')}:'
      '${time.minute.toString().padLeft(2, '0')}';

  /// 某一节的开始时刻。
  TimeOfDay _sectionStartTime(int section) {
    final int minutes = ClassTimeTable.sectionStartMinute(section);
    return TimeOfDay(hour: minutes ~/ 60, minute: minutes % 60);
  }

  /// 某一节的结束时刻。
  TimeOfDay _sectionEndTime(int section) {
    final int minutes = ClassTimeTable.sectionEndMinute(section);
    return TimeOfDay(hour: minutes ~/ 60, minute: minutes % 60);
  }

  /// 开始时刻正好等于某节开始时间的节次；没有则返回 `null`。
  int? _sectionStartingAt(TimeOfDay time) {
    for (int section = 1; section <= ClassTimeTable.sectionCount; section++) {
      if (_sectionStartTime(section) == time) return section;
    }
    return null;
  }

  /// 结束时刻正好等于某节结束时间的节次；没有则返回 `null`。
  int? _sectionEndingAt(TimeOfDay time) {
    for (int section = 1; section <= ClassTimeTable.sectionCount; section++) {
      if (_sectionEndTime(section) == time) return section;
    }
    return null;
  }

  /// 当前时刻之后的第一节；当天已经没有课时回落到第 1 节。
  int _firstSectionAfter(TimeOfDay time) {
    final int minute = time.hour * 60 + time.minute;
    for (int section = 1; section <= ClassTimeTable.sectionCount; section++) {
      if (ClassTimeTable.sectionEndMinute(section) > minute) return section;
    }
    return 1;
  }

  /// 包含该时刻的节次；落在课间时取最近的一节。
  int _nearestSectionFor(TimeOfDay time) {
    final int minute = time.hour * 60 + time.minute;
    int best = 1;
    int bestDistance = 1 << 30;
    for (int section = 1; section <= ClassTimeTable.sectionCount; section++) {
      final int start = ClassTimeTable.sectionStartMinute(section);
      final int end = ClassTimeTable.sectionEndMinute(section);
      if (minute >= start && minute <= end) return section;
      final int distance = minute < start ? start - minute : minute - end;
      if (distance < bestDistance) {
        bestDistance = distance;
        best = section;
      }
    }
    return best;
  }

  /// 把当前节次换算成起止时刻。
  void _applySectionRange() {
    _startTime = _sectionStartTime(_startSection);
    _endTime = _sectionEndTime(_endSection);
  }

  /// 切换录入方式；切到「按节次」时把当前时分对齐到最近的节次边界。
  void _setTimeMode(_ScheduleTimeMode mode) {
    if (mode == _timeMode) return;
    setState(() {
      _timeMode = mode;
      if (mode != _ScheduleTimeMode.section) return;
      _startSection =
          _sectionStartingAt(_startTime) ?? _nearestSectionFor(_startTime);
      final int endSection =
          _sectionEndingAt(_endTime) ?? _nearestSectionFor(_endTime);
      _endSection = math.max(_startSection, endSection);
      _applySectionRange();
    });
  }

  /// 打开节次选择面板；[isStart] 决定改开始还是结束节次。
  Future<void> _pickSection({required bool isStart}) async {
    final int minSection = isStart ? 1 : _startSection;
    final int current = isStart ? _startSection : _endSection;
    final int? picked = await showModalBottomSheet<int>(
      context: context,
      showDragHandle: true,
      builder: (BuildContext sheetContext) {
        return SafeArea(
          child: ListView(
            shrinkWrap: true,
            children: <Widget>[
              Padding(
                padding: const EdgeInsets.fromLTRB(24, 4, 24, 8),
                child: Text(
                  isStart ? '选择开始节次' : '选择结束节次',
                  style: Theme.of(sheetContext).textTheme.titleMedium,
                ),
              ),
              for (
                int section = minSection;
                section <= ClassTimeTable.sectionCount;
                section++
              )
                ListTile(
                  title: Text('第 $section 节'),
                  subtitle: Text(
                    '${_formatTime(_sectionStartTime(section))} – '
                    '${_formatTime(_sectionEndTime(section))}',
                  ),
                  selected: section == current,
                  trailing:
                      section == current ? const Icon(Icons.check_rounded) : null,
                  onTap: () => Navigator.of(sheetContext).pop(section),
                ),
            ],
          ),
        );
      },
    );
    if (picked == null || !mounted) return;
    setState(() {
      if (isStart) {
        _startSection = picked;
        if (_endSection < _startSection) _endSection = _startSection;
      } else {
        _endSection = picked;
      }
      _applySectionRange();
    });
  }

  Future<void> _pickRepeatUntil() async {
    final DateTime firstDate =
        _repeatUntil ?? _date;
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: firstDate.isAfter(_date) ? firstDate : _date,
      firstDate: _date,
      lastDate: DateTime(2100),
    );
    if (picked != null && mounted) {
      setState(() => _repeatUntil = picked);
    }
  }

  Future<void> _save() async {
    if (!_canSave || _saving) return;
    setState(() => _saving = true);

    final CustomScheduleEvent next = CustomScheduleEvent(
      id: widget.event?.id ?? const Uuid().v4(),
      title: _titleController.text.trim(),
      location: _locationController.text.trim(),
      note: _noteController.text.trim(),
      start: _startDateTime,
      end: _endDateTime,
      colorArgb: _colorArgb,
      repeat: _repeat,
      repeatUntil: _repeat == ScheduleRepeat.none ? null : _repeatUntil,
      weeks:
          _repeat == ScheduleRepeat.weekly && _customWeeks
              ? (_weeks.toList()..sort())
              : const <int>[],
    );

    try {
      await _controller.upsert(next);
      if (mounted) Navigator.of(context).pop(next);
    } catch (error) {
      if (!mounted) return;
      setState(() => _saving = false);
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('日程保存失败，请重试')));
    }
  }

  Future<void> _delete() async {
    final bool? confirmed = await showDialog<bool>(
      context: context,
      builder:
          (BuildContext dialogContext) => AlertDialog(
            title: const Text('删除日程'),
            content: const Text('删除后不可恢复，已同步到系统日历的事件会在下次同步时移除。'),
            actions: <Widget>[
              TextButton(
                onPressed: () => Navigator.of(dialogContext).pop(false),
                child: const Text('取消'),
              ),
              TextButton(
                onPressed: () => Navigator.of(dialogContext).pop(true),
                child: const Text('删除'),
              ),
            ],
          ),
    );
    if (confirmed != true || !mounted) return;

    final String? id = widget.event?.id;
    if (id == null) return;
    await _controller.remove(id);
    if (mounted) Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final ColorScheme scheme = theme.colorScheme;

    return GlassScaffold(
      title: _isEditing ? '编辑日程' : '新建日程',
      actions: <Widget>[
        GlassActionButton(
          icon: Icons.check_rounded,
          tooltip: '保存',
          semanticLabel: '保存',
          onPressed: _canSave && !_saving ? _save : null,
        ),
      ],
      body: ListView(
        padding: EdgeInsets.fromLTRB(16, 8 + glassTopInset(context), 16, 40),
        children: <Widget>[
          _buildTitleCard(theme),
          const SizedBox(height: 12),
          _buildTimeCard(theme, scheme),
          const SizedBox(height: 12),
          _buildDetailCard(theme),
          const SizedBox(height: 12),
          _buildRepeatCard(theme, scheme),
          const SizedBox(height: 12),
          _buildColorCard(theme, scheme),
          const SizedBox(height: 20),
          FilledButton(
            onPressed: _canSave && !_saving ? _save : null,
            child: Text(_saving ? '保存中…' : '保存'),
          ),
          if (_isEditing) ...<Widget>[
            const SizedBox(height: 8),
            TextButton(
              onPressed: _saving ? null : _delete,
              style: TextButton.styleFrom(foregroundColor: scheme.error),
              child: const Text('删除日程'),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildTitleCard(ThemeData theme) {
    return Card.filled(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 6, 16, 10),
        child: TextField(
          controller: _titleController,
          autofocus: !_isEditing,
          textInputAction: TextInputAction.done,
          style: theme.textTheme.headlineSmall?.copyWith(
            fontWeight: FontWeight.w600,
          ),
          decoration: const InputDecoration(
            hintText: '日程标题',
            border: InputBorder.none,
            filled: false,
          ),
          onChanged: (_) => setState(() {}),
        ),
      ),
    );
  }

  Widget _buildTimeCard(ThemeData theme, ColorScheme scheme) {
    final bool bySection = _timeMode == _ScheduleTimeMode.section;
    return Card.outlined(
      margin: EdgeInsets.zero,
      child: Column(
        children: <Widget>[
          ListTile(
            leading: Icon(Icons.event_outlined, color: scheme.primary),
            title: const Text('日期'),
            trailing: Text(
              '${_date.year}年${_date.month}月${_date.day}日',
              style: theme.textTheme.bodyLarge,
            ),
            onTap: _pickDate,
          ),
          const Divider(height: 1),
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
            child: SizedBox(
              width: double.infinity,
              child: GlassSegmented<_ScheduleTimeMode>(
                expand: true,
                segments: const <GlassSegment<_ScheduleTimeMode>>[
                  GlassSegment(
                    value: _ScheduleTimeMode.section,
                    label: '按节次',
                  ),
                  GlassSegment(
                    value: _ScheduleTimeMode.custom,
                    label: '自定义时间',
                  ),
                ],
                selected: _timeMode,
                onChanged: _setTimeMode,
              ),
            ),
          ),
          const Divider(height: 1),
          if (bySection) ...<Widget>[
            ListTile(
              leading: Icon(Icons.looks_one_outlined, color: scheme.primary),
              title: const Text('开始节次'),
              trailing: Text(
                '第 $_startSection 节  ${_formatTime(_startTime)}',
                style: theme.textTheme.titleSmall,
              ),
              onTap: () => _pickSection(isStart: true),
            ),
            const Divider(height: 1),
            ListTile(
              leading: Icon(Icons.looks_two_outlined, color: scheme.primary),
              title: const Text('结束节次'),
              trailing: Text(
                '第 $_endSection 节  ${_formatTime(_endTime)}',
                style: theme.textTheme.titleSmall,
              ),
              onTap: () => _pickSection(isStart: false),
            ),
          ] else
            ListTile(
              leading: Icon(Icons.schedule_outlined, color: scheme.primary),
              title: const Text('时间'),
              subtitle: const Text('24 小时制'),
              trailing: Text(
                '${_formatTime(_startTime)} – ${_formatTime(_endTime)}',
                style: theme.textTheme.titleSmall,
              ),
              onTap: _pickTimeRange,
            ),
          if (!_timeRangeValid)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  '结束时间需要晚于开始时间',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: scheme.error,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildDetailCard(ThemeData theme) {
    return Card.outlined(
      margin: EdgeInsets.zero,
      child: Column(
        children: <Widget>[
          ListTile(
            leading: const Icon(Icons.place_outlined),
            title: TextField(
              controller: _locationController,
              decoration: const InputDecoration(
                hintText: '地点（选填）',
                border: InputBorder.none,
                filled: false,
              ),
            ),
          ),
          const Divider(height: 1),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
            child: TextField(
              controller: _noteController,
              maxLength: 200,
              maxLines: 3,
              minLines: 1,
              decoration: const InputDecoration(
                hintText: '备注（选填）',
                border: InputBorder.none,
                filled: false,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRepeatCard(ThemeData theme, ColorScheme scheme) {
    return Card.outlined(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 12, 12, 8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4),
              child: Text('重复', style: theme.textTheme.titleSmall),
            ),
            const SizedBox(height: 10),
            SizedBox(
              width: double.infinity,
              child: GlassSegmented<ScheduleRepeat>(
                expand: true,
                segments: const <GlassSegment<ScheduleRepeat>>[
                  GlassSegment(value: ScheduleRepeat.none, label: '不重复'),
                  GlassSegment(value: ScheduleRepeat.daily, label: '每天'),
                  GlassSegment(value: ScheduleRepeat.weekly, label: '每周'),
                  GlassSegment(value: ScheduleRepeat.monthly, label: '每月'),
                ],
                selected: _repeat,
                onChanged: (ScheduleRepeat value) {
                  setState(() {
                    _repeat = value;
                    if (value == ScheduleRepeat.none) _repeatUntil = null;
                  });
                },
              ),
            ),
            if (_repeat == ScheduleRepeat.weekly) ...<Widget>[
              const Divider(height: 1),
              ListTile(
                contentPadding: const EdgeInsets.symmetric(horizontal: 4),
                leading: Icon(Icons.calendar_view_week, color: scheme.primary),
                title: const Text('自定义周次'),
                subtitle: Text(
                  _customWeeks
                      ? '只在勾选的周重复'
                      : '每周固定重复，不挑周次',
                ),
                trailing: Switch(
                  value: _customWeeks,
                  onChanged: (bool value) => setState(() => _customWeeks = value),
                ),
                onTap: () => setState(() => _customWeeks = !_customWeeks),
              ),
              if (_customWeeks) ...<Widget>[
                const SizedBox(height: 6),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 4),
                  child: Text(
                    '重复周次',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: scheme.onSurfaceVariant,
                    ),
                  ),
                ),
                const SizedBox(height: 6),
                Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: <Widget>[
                    for (int week = 1; week <= _maxWeek; week++)
                      FilterChip(
                        label: Text('$week'),
                        selected: _weeks.contains(week),
                        onSelected: (bool selected) {
                          setState(() {
                            if (selected) {
                              _weeks.add(week);
                            } else {
                              _weeks.remove(week);
                            }
                          });
                        },
                      ),
                  ],
                ),
              ],
            ],
            if (_repeat != ScheduleRepeat.none)
              ListTile(
                contentPadding: const EdgeInsets.symmetric(horizontal: 4),
                leading: Icon(
                  Icons.event_repeat_outlined,
                  color: scheme.primary,
                ),
                title: const Text('重复结束日期'),
                subtitle: Text(
                  _repeatUntil == null
                      ? '不设结束日期'
                      : scheduleFormatDate(_repeatUntil!),
                ),
                trailing:
                    _repeatUntil == null
                        ? const Icon(Icons.chevron_right)
                        : IconButton(
                          icon: const Icon(Icons.close),
                          tooltip: '清除',
                          onPressed: () => setState(() => _repeatUntil = null),
                        ),
                onTap: _pickRepeatUntil,
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildColorCard(ThemeData theme, ColorScheme scheme) {
    return Card.outlined(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Text('颜色', style: theme.textTheme.titleSmall),
            const SizedBox(height: 12),
            Wrap(
              spacing: 12,
              runSpacing: 12,
              children: <Widget>[
                for (final int preset in ScheduleColors.presets)
                  _ColorDot(
                    color: Color(preset),
                    selected: _colorArgb == preset,
                    onTap: () => setState(() => _colorArgb = preset),
                  ),
                _CustomColorDot(
                  color: ScheduleColors.resolve(_colorArgb),
                  selected: !ScheduleColors.presets.contains(_colorArgb),
                  onTap:
                      () => setState(
                        () => _customColorExpanded = !_customColorExpanded,
                      ),
                ),
              ],
            ),
            if (_customColorExpanded) ...<Widget>[
              const SizedBox(height: 12),
              ColorPicker(
                color: ScheduleColors.resolve(_colorArgb),
                pickersEnabled: const <ColorPickerType, bool>{
                  ColorPickerType.primary: true,
                  ColorPickerType.wheel: true,
                },
                pickerTypeLabels: const <ColorPickerType, String>{
                  ColorPickerType.primary: '色板',
                  ColorPickerType.wheel: '色轮',
                },
                enableOpacity: false,
                enableShadesSelection: false,
                showColorCode: false,
                onColorChanged: (Color value) {
                  setState(() => _colorArgb = value.toARGB32());
                },
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _ColorDot extends StatelessWidget {
  const _ColorDot({
    required this.color,
    required this.selected,
    required this.onTap,
  });

  final Color color;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final ColorScheme scheme = Theme.of(context).colorScheme;
    return Semantics(
      selected: selected,
      button: true,
      child: InkResponse(
        onTap: onTap,
        radius: 24,
        child: Container(
          width: 36,
          height: 36,
          decoration: BoxDecoration(
            color: color,
            shape: BoxShape.circle,
            border: Border.all(
              color: selected ? scheme.onSurface : Colors.transparent,
              width: 2,
            ),
          ),
          child:
              selected
                  ? const Icon(Icons.check, size: 18, color: Colors.white)
                  : null,
        ),
      ),
    );
  }
}

class _CustomColorDot extends StatelessWidget {
  const _CustomColorDot({
    required this.color,
    required this.selected,
    required this.onTap,
  });

  final Color color;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final ColorScheme scheme = Theme.of(context).colorScheme;
    return Semantics(
      label: '自定义颜色',
      selected: selected,
      button: true,
      child: InkResponse(
        onTap: onTap,
        radius: 24,
        child: Container(
          width: 36,
          height: 36,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: SweepGradient(
              colors: <Color>[
                Colors.red,
                Colors.orange,
                Colors.yellow,
                Colors.green,
                Colors.cyan,
                Colors.blue,
                Colors.purple,
                Colors.red,
              ],
            ),
            border: Border.all(
              color: selected ? scheme.onSurface : scheme.outlineVariant,
              width: 2,
            ),
          ),
          child: Center(
            child: Icon(
              Icons.colorize,
              size: 16,
              color: selected ? Colors.white : scheme.onSurfaceVariant,
            ),
          ),
        ),
      ),
    );
  }
}

