import 'dart:async';

import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:intl/intl.dart';
import 'package:liquid_glass_easy/liquid_glass_easy.dart';
import 'package:permission_handler/permission_handler.dart';

import '../../theme/glass/glass_overlays.dart';
import '../../theme/glass/glass_scaffold.dart';
import '../../theme/glass/glass_theme.dart';
import '../../utils/course/calendar/calendar_gateway.dart';
import '../../utils/course/calendar/calendar_sync_controller.dart';
import '../../utils/course/calendar/calendar_sync_store.dart';

/// 「日历同步」设置页：单向把课程与自定义日程写入系统日历。
///
/// 只在 Android / iOS 出现入口并可用；桌面端 [isAvailable] 为假。
class CalendarSyncPage extends StatefulWidget {
  const CalendarSyncPage({super.key});

  static bool get isAvailable =>
      const MethodChannelCalendarGateway().isSupported;

  @override
  State<CalendarSyncPage> createState() => _CalendarSyncPageState();
}

class _CalendarSyncPageState extends State<CalendarSyncPage> {
  /// main 里已经注册；这里兜底，避免深链进入本页时取不到。
  late final CalendarSyncController _controller =
      CalendarSyncController.maybeInstance ?? Get.put(CalendarSyncController());

  @override
  void initState() {
    super.initState();
    unawaited(_controller.load());
  }

  Future<void> _handleToggle(bool value) async {
    if (value) {
      final int count = await _controller.estimateEventCount();
      if (!mounted) return;
      final bool? confirmed = await showGlassDialog<bool>(
        context: context,
        title: const Text('开启日历同步'),
        content: Text(
          '将创建「${CalendarSyncStore.calendarName}」日历，并写入约 $count 个事件'
          '（整个学期的课程 + 自定义日程）。\n\n'
          '同步是单向的：日历 App 里新建或修改的内容不会回到超级包菜。',
        ),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('取消'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('开启'),
          ),
        ],
      );
      if (confirmed != true) return;
    }

    final bool ok = await _controller.setEnabled(value);
    if (!mounted) return;
    if (value && !ok) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('没有日历权限，无法写入系统日历'),
          action: SnackBarAction(label: '去设置', onPressed: openAppSettings),
        ),
      );
    }
  }

  Future<void> _pickReminder() async {
    final int? selected = await showGlassSheet<int>(
      context: context,
      builder:
          (BuildContext context) => SafeArea(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                Padding(
                  padding: const EdgeInsets.fromLTRB(24, 8, 24, 8),
                  child: Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      '提醒时间',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                  ),
                ),
                for (final int minutes in CalendarSyncStore.reminderOptions)
                  ListTile(
                    title: Text(minutes == 0 ? '不提醒' : '提前 $minutes 分钟'),
                    trailing:
                        minutes == _controller.reminderMinutes
                            ? Icon(
                              Icons.check_rounded,
                              color: Theme.of(context).colorScheme.primary,
                            )
                            : null,
                    onTap: () => Navigator.of(context).pop(minutes),
                  ),
                const SizedBox(height: 8),
              ],
            ),
          ),
    );
    if (selected != null) {
      await _controller.setReminderMinutes(selected);
    }
  }

  Future<void> _clearSynced() async {
    final bool? confirmed = await showGlassDialog<bool>(
      context: context,
      title: const Text('清除已同步事件'),
      content: const Text('会删除「超级包菜课表」里由本 App 写入的全部事件，日历本身保留。'),
      actions: <Widget>[
        TextButton(
          onPressed: () => Navigator.of(context).pop(false),
          child: const Text('取消'),
        ),
        TextButton(
          onPressed: () => Navigator.of(context).pop(true),
          child: const Text('清除'),
        ),
      ],
    );
    if (confirmed != true) return;
    await _controller.clearSyncedEvents();
    if (!mounted) return;
    // 清理不完整时不要报「已清除」：失败的记录仍留在簿记里等下一轮重试。
    final String error = _controller.lastError.value;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(error.isEmpty ? '已清除同步事件' : error)),
    );
  }

  @override
  Widget build(BuildContext context) {
    final AppGlassTheme glass = context.glassTheme;
    final ThemeData theme = Theme.of(context);
    final ColorScheme scheme = theme.colorScheme;

    return GlassScaffold(
      title: '日历同步',
      body: Obx(() {
        final bool enabled = _controller.enabled;
        final bool syncing = _controller.syncing.value;
        final DateTime? lastSync = _controller.lastSyncAt;
        final String error = _controller.lastError.value;

        return ListView(
          padding: EdgeInsets.fromLTRB(16, 8 + glassTopInset(context), 16, 40),
          children: <Widget>[
            Text('同步范围', style: theme.textTheme.titleMedium),
            const SizedBox(height: 8),
            Card.outlined(
              margin: EdgeInsets.zero,
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      '把整个学期的课程与自定义日程写入系统日历的'
                      '「${CalendarSyncStore.calendarName}」，在系统日历 App 里可以查看和提醒。',
                      style: theme.textTheme.bodyMedium,
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 20),
            Text('同步开关', style: theme.textTheme.titleMedium),
            const SizedBox(height: 8),
            Card.outlined(
              margin: EdgeInsets.zero,
              child: ListTile(
                leading: Icon(
                  Icons.event_available_outlined,
                  color: scheme.primary,
                ),
                title: const Text('同步到系统日历'),
                subtitle: Text(
                  !_controller.isSupported
                      ? '当前平台不支持系统日历'
                      : enabled
                      ? (syncing ? '正在同步…' : '已开启')
                      : '开启后自动保持日历与课表一致',
                ),
                trailing: _GlassSwitch(
                  enabled: glass.enabled,
                  value: enabled,
                  onChanged:
                      _controller.isSupported && !syncing
                          ? _handleToggle
                          : null,
                ),
                onTap:
                    _controller.isSupported && !syncing
                        ? () => _handleToggle(!enabled)
                        : null,
              ),
            ),
            const SizedBox(height: 20),
            Text('提醒', style: theme.textTheme.titleMedium),
            const SizedBox(height: 8),
            Card.outlined(
              margin: EdgeInsets.zero,
              child: ListTile(
                leading: Icon(Icons.alarm_outlined, color: scheme.primary),
                title: const Text('日历提醒'),
                subtitle: Text(
                  _controller.reminderMinutes == 0
                      ? '不提醒（仍可在系统日历里手动设置）'
                      : '事件开始前 ${_controller.reminderMinutes} 分钟提醒',
                ),
                trailing: const Icon(Icons.chevron_right),
                onTap: enabled && !syncing ? _pickReminder : null,
              ),
            ),
            const SizedBox(height: 20),
            Text('状态', style: theme.textTheme.titleMedium),
            const SizedBox(height: 8),
            Card.outlined(
              margin: EdgeInsets.zero,
              child: Column(
                children: <Widget>[
                  ListTile(
                    leading: const Icon(Icons.calendar_month_outlined),
                    title: const Text('目标日历'),
                    trailing: Text(CalendarSyncStore.calendarName),
                  ),
                  const Divider(height: 1),
                  ListTile(
                    leading: const Icon(Icons.history_outlined),
                    title: const Text('上次同步'),
                    trailing: Text(
                      lastSync == null
                          ? '尚未同步'
                          : DateFormat('M月d日 HH:mm').format(lastSync),
                    ),
                  ),
                  const Divider(height: 1),
                  ListTile(
                    leading: const Icon(Icons.event_note_outlined),
                    title: const Text('已同步事件'),
                    trailing: Text('${_controller.syncedCount} 条'),
                  ),
                ],
              ),
            ),
            if (error.isNotEmpty) ...<Widget>[
              const SizedBox(height: 12),
              Card.filled(
                margin: EdgeInsets.zero,
                color: scheme.errorContainer,
                child: Padding(
                  padding: const EdgeInsets.all(14),
                  child: Row(
                    children: <Widget>[
                      Icon(Icons.error_outline, color: scheme.onErrorContainer),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          error,
                          style: TextStyle(color: scheme.onErrorContainer),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
            const SizedBox(height: 20),
            if (syncing) ...<Widget>[
              ClipRRect(
                borderRadius: BorderRadius.circular(99),
                child: LinearProgressIndicator(
                  minHeight: 6,
                  value: _controller.progress.value,
                  backgroundColor: scheme.surfaceContainerHighest,
                ),
              ),
              const SizedBox(height: 10),
            ],
            FilledButton.icon(
              onPressed:
                  enabled && !syncing ? () => _controller.syncNow() : null,
              icon: const Icon(Icons.sync),
              label: const Text('立即同步'),
            ),
            const SizedBox(height: 8),
            TextButton(
              onPressed:
                  enabled && !syncing && _controller.syncedCount > 0
                      ? _clearSynced
                      : null,
              style: TextButton.styleFrom(foregroundColor: scheme.error),
              child: const Text('清除已同步事件'),
            ),
          ],
        );
      }),
    );
  }
}

/// 与其他设置页一致的开关：玻璃开启时用玻璃开关，否则回落 Material。
class _GlassSwitch extends StatelessWidget {
  const _GlassSwitch({
    required this.enabled,
    required this.value,
    required this.onChanged,
  });

  final bool enabled;
  final bool value;
  final ValueChanged<bool>? onChanged;

  @override
  Widget build(BuildContext context) {
    if (!enabled || onChanged == null) {
      return Switch(value: value, onChanged: onChanged);
    }
    return LiquidGlassSwitch(
      value: value,
      onChanged: onChanged!,
      activeColor: Theme.of(context).colorScheme.primary,
    );
  }
}
