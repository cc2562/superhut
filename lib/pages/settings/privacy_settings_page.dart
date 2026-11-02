import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:liquid_glass_easy/liquid_glass_easy.dart';

import '../../agreement/agreement_documents.dart';
import '../../agreement/agreement_page.dart';
import '../../privacy/analytics_recorder.dart';
import '../../privacy/privacy_consent_controller.dart';
import '../../theme/glass/glass_scaffold.dart';
import '../../theme/glass/glass_theme.dart';

/// 隐私设置：行为分析的可选开关与协议入口。
///
/// 这是「我的」页唯一的隐私入口，避免用户协议 / 隐私政策各挂一个入口、
/// 却找不到真正能关闭采集的地方。
///
/// [recorder] 允许注入，测试里用 fake 断言「开关 -> 采集动作」的调用关系；
/// 默认走 Microsoft Clarity。
class PrivacySettingsPage extends StatefulWidget {
  const PrivacySettingsPage({super.key, this.recorder});

  final AnalyticsRecorder? recorder;

  @override
  State<PrivacySettingsPage> createState() => _PrivacySettingsPageState();
}

class _PrivacySettingsPageState extends State<PrivacySettingsPage> {
  late final AnalyticsRecorder _recorder =
      widget.recorder ?? const ClarityAnalyticsRecorder();

  PrivacyConsentController get _controller =>
      Get.find<PrivacyConsentController>();

  Future<void> _handleToggle(bool enabled) async {
    if (enabled) {
      await _controller.setAnalyticsConsent(true);
      if (!mounted) return;
      await _recorder.enable(context);
      return;
    }

    final bool confirmed = await _confirmWithdraw();
    if (!confirmed) return;
    await _controller.setAnalyticsConsent(false);
    await _recorder.withdraw();
  }

  /// 关闭前确认：写清楚「立即停止」与「既往处理不撤回」。
  Future<bool> _confirmWithdraw() async {
    final bool? result = await showDialog<bool>(
      context: context,
      builder:
          (dialogContext) => AlertDialog(
            title: const Text('关闭使用体验分析？'),
            content: const Text(
              '关闭后将立即停止后续的行为数据采集，不会影响课表、成绩等核心功能。\n\n'
              '撤回同意不影响撤回前已经完成的处理。如需删除此前已上传的分析数据，'
              '请发送邮件至 syywqs@foxmail.com 申请。',
            ),
            actions: <Widget>[
              TextButton(
                onPressed: () => Navigator.of(dialogContext).pop(false),
                child: const Text('取消'),
              ),
              FilledButton(
                onPressed: () => Navigator.of(dialogContext).pop(true),
                child: const Text('仍要关闭'),
              ),
            ],
          ),
    );
    return result ?? false;
  }

  void _openDocument(AgreementDocument document) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (context) => AgreementPage(document: document),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final glass = context.glassTheme;
    final ThemeData theme = Theme.of(context);
    final ColorScheme scheme = theme.colorScheme;

    return GlassScaffold(
      title: '隐私设置',
      body: Obx(() {
        final bool enabled = _controller.analyticsConsent;
        return ListView(
          padding: EdgeInsets.fromLTRB(16, 8 + glassTopInset(context), 16, 32),
          children: <Widget>[
            Text('使用体验分析', style: theme.textTheme.titleMedium),
            const SizedBox(height: 8),
            Card.outlined(
              child: ListTile(
                leading: const Icon(Icons.insights_outlined),
                title: const Text('使用体验分析'),
                subtitle: const Text('Microsoft Clarity'),
                trailing: _GlassSwitch(
                  enabled: glass.enabled,
                  value: enabled,
                  onChanged: _handleToggle,
                ),
                onTap: () => _handleToggle(!enabled),
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
                      '这项功能是可选的，关闭后课表、成绩、水电费等核心功能不受影响。',
                      style: theme.textTheme.bodyMedium,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      '开启后，我们会通过 Microsoft Clarity 记录页面操作轨迹、点击热图、'
                      '崩溃与性能信息以及设备与版本信息，用于定位问题和改进体验；'
                      '统一认证、教务、缴费等网页已整体启用遮罩，'
                      '这些页面的内容与输入不会被记录。',
                      style: theme.textTheme.bodySmall?.copyWith(
                        height: 1.6,
                        color: scheme.onSurfaceVariant,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      '保持体验分析的开启能够让我们更准确地定位问题，让超级包菜变得更好~',
                      style: theme.textTheme.bodySmall?.copyWith(
                        height: 1.6,
                        color: scheme.onSurfaceVariant,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      '撤回同意不影响撤回前已经完成的处理；删除历史数据需邮件申请。',
                      style: theme.textTheme.bodySmall?.copyWith(
                        height: 1.6,
                        color: scheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 24),
            Text('协议与政策', style: theme.textTheme.titleMedium),
            const SizedBox(height: 8),
            Card.outlined(
              clipBehavior: Clip.antiAlias,
              child: Column(
                children: <Widget>[
                  for (
                    int i = 0;
                    i < AgreementDocuments.all.length;
                    i++
                  ) ...<Widget>[
                    if (i > 0) const Divider(height: 1),
                    ListTile(
                      leading: Icon(
                        i == 0
                            ? Icons.description_outlined
                            : Icons.privacy_tip_outlined,
                        color: scheme.onSurfaceVariant,
                      ),
                      title: Text('《${AgreementDocuments.all[i].title}》'),
                      subtitle: Text('版本 ${AgreementDocuments.version}'),
                      trailing: const Icon(Icons.chevron_right, size: 20),
                      onTap: () => _openDocument(AgreementDocuments.all[i]),
                    ),
                  ],
                ],
              ),
            ),
          ],
        );
      }),
    );
  }
}

/// 与「外观与主题」页一致的开关：玻璃开启时用玻璃开关，否则回落 Material。
class _GlassSwitch extends StatelessWidget {
  const _GlassSwitch({
    required this.enabled,
    required this.value,
    required this.onChanged,
  });

  final bool enabled;
  final bool value;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    if (!enabled) {
      return Switch(value: value, onChanged: onChanged);
    }
    return LiquidGlassSwitch(
      value: value,
      onChanged: onChanged,
      activeColor: Theme.of(context).colorScheme.primary,
    );
  }
}
