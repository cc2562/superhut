import 'dart:async';

import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:liquid_glass_easy/liquid_glass_easy.dart';

import '../../live_activity/class_live_activity_controller.dart';
import '../../live_activity/class_live_activity_service.dart';
import '../../theme/glass/glass_scaffold.dart';
import '../../theme/glass/glass_theme.dart';

/// 提醒设置：目前只有「灵动岛课程提醒」一项。
///
/// 实时活动是 iOS 独占能力，Android 既不显示「我的」页入口，也不会进到这里；
/// 原有的 Android 实时通知不受影响。
class ReminderSettingsPage extends StatefulWidget {
  const ReminderSettingsPage({super.key});

  /// 当前平台是否具备实时活动能力（供「我的」页决定是否显示入口）。
  static bool get isAvailable => ClassLiveActivityService.isPlatformSupported;

  @override
  State<ReminderSettingsPage> createState() => _ReminderSettingsPageState();
}

class _ReminderSettingsPageState extends State<ReminderSettingsPage> {
  /// main 里已经注册过控制器；这里兜底，避免深链或测试直接进入本页时取不到。
  late final ClassLiveActivityController _controller =
      ClassLiveActivityController.maybeInstance ??
      Get.put(ClassLiveActivityController());

  @override
  void initState() {
    super.initState();
    // load() 幂等：已加载过则立即返回，不会重复探测。
    unawaited(_controller.load());
  }

  @override
  Widget build(BuildContext context) {
    final glass = context.glassTheme;
    final ThemeData theme = Theme.of(context);
    final ColorScheme scheme = theme.colorScheme;

    return GlassScaffold(
      title: '提醒设置',
      body: Obx(() {
        final bool enabled = _controller.enabled;
        // 系统关掉「实时活动」后开关置灰，并提示去系统设置打开。
        final bool systemSupported = _controller.systemSupported;
        final bool canToggle = systemSupported;

        return ListView(
          padding: EdgeInsets.fromLTRB(16, 8 + glassTopInset(context), 16, 32),
          children: <Widget>[
            Text('课程提醒', style: theme.textTheme.titleMedium),
            const SizedBox(height: 8),
            Card.outlined(
              child: ListTile(
                leading: const Icon(Icons.notifications_active_outlined),
                title: const Text('灵动岛课程提醒'),
                subtitle: Text(
                  canToggle
                      ? '课前 10 分钟显示倒计时与上课信息'
                      : '系统未允许「实时活动」，请到「设置 > 超级包菜」中开启',
                ),
                trailing: _GlassSwitch(
                  enabled: glass.enabled,
                  value: enabled,
                  onChanged: canToggle ? _handleToggle : null,
                ),
                onTap: canToggle ? () => _handleToggle(!enabled) : null,
              ),
            ),
            const SizedBox(height: 12),
            Card.filled(
              margin: EdgeInsets.zero,
              color: scheme.surfaceContainerHighest,
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      '上课前 10 分钟开始，在灵动岛或锁屏上显示科目、地点与倒计时；'
                      '上课后倒计时切换为下课时间，下课后自动收起。',
                      style: theme.textTheme.bodyMedium,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      '倒计时由系统负责刷新，不需要 App 一直运行在前台。',
                      style: theme.textTheme.bodySmall?.copyWith(
                        height: 1.6,
                        color: scheme.onSurfaceVariant,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      '仅 iPhone 14 Pro 及以上机型支持灵动岛；其它 iPhone 与 iPad '
                      '会在锁屏和通知中心显示同样的课程卡片。',
                      style: theme.textTheme.bodySmall?.copyWith(
                        height: 1.6,
                        color: scheme.onSurfaceVariant,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      '实时活动只能由 App 主动发起：App 被系统关闭后不会自动弹出，'
                      '重新打开时会补上当前正在上的课。关闭本开关会立即收起正在显示的活动。',
                      style: theme.textTheme.bodySmall?.copyWith(
                        height: 1.6,
                        color: scheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        );
      }),
    );
  }

  Future<void> _handleToggle(bool value) => _controller.setEnabled(value);
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
