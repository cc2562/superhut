import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show SystemNavigator;

import 'agreement_documents.dart';
import 'agreement_page.dart';

/// 启动同意页（全屏、不可返回、不可手势关闭）。
///
/// 只有在用户勾选「我已阅读并同意《用户协议》与《隐私政策》」并点击
/// 「同意并继续」之后，调用方才会记录同意并启动 Clarity 采集；
/// 未勾选时主按钮禁用（`onPressed: null`），点「不同意」则退出应用。
///
/// 两个回调都以参数注入，便于在 widget 测试里断言而不用真的退出进程。
class AgreementConsentPage extends StatefulWidget {
  const AgreementConsentPage({super.key, required this.onAccept, this.onExit});

  /// 用户同意后执行：落盘同意版本、启动统计 SDK、切到正式页面。
  ///
  /// 传入本页的 [BuildContext]（位于 `MaterialApp` 之内、带 `MediaQuery`），
  /// Clarity 的初始化要求这样一个「widget 已构建」的 context。
  final Future<void> Function(BuildContext context) onAccept;

  /// 用户拒绝后执行；不传则使用内置的退出逻辑。
  final Future<void> Function()? onExit;

  @override
  State<AgreementConsentPage> createState() => _AgreementConsentPageState();
}

class _AgreementConsentPageState extends State<AgreementConsentPage> {
  bool _agreed = false;

  /// 防止连点「同意并继续」触发两次启动。
  bool _submitting = false;

  void _toggleAgreed() {
    if (_submitting) return;
    setState(() => _agreed = !_agreed);
  }

  Future<void> _handleAccept() async {
    if (!_agreed || _submitting) return;
    setState(() => _submitting = true);
    try {
      await widget.onAccept(context);
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  Future<void> _handleExit() async {
    final Future<void> Function()? onExit = widget.onExit;
    if (onExit != null) {
      await onExit();
      return;
    }
    // iOS 不允许程序自行退出（会被审核拒绝），只提示用户手动关闭；
    // Android / 桌面直接结束当前任务。
    if (defaultTargetPlatform == TargetPlatform.iOS) {
      if (!mounted) return;
      await showDialog<void>(
        context: context,
        builder:
            (context) => AlertDialog(
              title: const Text('无法继续使用'),
              content: const Text('需要同意《用户协议》与《隐私政策》才能使用本应用，请手动关闭应用。'),
              actions: <Widget>[
                TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: const Text('我知道了'),
                ),
              ],
            ),
      );
      return;
    }
    await SystemNavigator.pop();
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
    final ThemeData theme = Theme.of(context);
    final ColorScheme scheme = theme.colorScheme;

    return PopScope(
      // 同意页是进入应用的唯一入口，任何形式的返回都不应绕过它。
      canPop: false,
      child: Scaffold(
        body: SafeArea(
          child: LayoutBuilder(
            builder: (context, constraints) {
              return SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(24, 32, 24, 24),
                child: ConstrainedBox(
                  constraints: BoxConstraints(
                    minHeight: constraints.maxHeight - 56,
                    maxWidth: 560,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: <Widget>[
                      _buildHeader(theme),
                      const SizedBox(height: 28),
                      _buildDocumentList(theme),
                      const SizedBox(height: 24),
                      _buildAgreementCheckbox(theme),
                      const SizedBox(height: 20),
                      FilledButton(
                        onPressed:
                            _agreed && !_submitting ? _handleAccept : null,
                        style: FilledButton.styleFrom(
                          minimumSize: const Size.fromHeight(48),
                        ),
                        child:
                            _submitting
                                ? const SizedBox(
                                  width: 20,
                                  height: 20,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                  ),
                                )
                                : const Text('同意并继续'),
                      ),
                      const SizedBox(height: 4),
                      TextButton(
                        onPressed: _submitting ? null : _handleExit,
                        child: Text(
                          '不同意，退出应用',
                          style: TextStyle(color: scheme.onSurfaceVariant),
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
      ),
    );
  }

  Widget _buildHeader(ThemeData theme) {
    final ColorScheme scheme = theme.colorScheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: <Widget>[
        Container(
          width: 64,
          height: 64,
          decoration: BoxDecoration(
            color: scheme.primaryContainer,
            borderRadius: BorderRadius.circular(20),
          ),
          child: Icon(
            Icons.school_outlined,
            size: 32,
            color: scheme.onPrimaryContainer,
          ),
        ),
        const SizedBox(height: 16),
        Text(
          '欢迎使用超级包菜',
          textAlign: TextAlign.center,
          style: theme.textTheme.headlineSmall?.copyWith(
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 10),
        Text(
          '在开始之前，请阅读并同意以下协议。为了改进产品体验，我们会在您同意后'
          '使用匿名的使用行为统计，具体范围与关闭方式见《隐私政策》。',
          textAlign: TextAlign.center,
          style: theme.textTheme.bodyMedium?.copyWith(
            height: 1.6,
            color: scheme.onSurfaceVariant,
          ),
        ),
      ],
    );
  }

  Widget _buildDocumentList(ThemeData theme) {
    return Card.outlined(
      margin: EdgeInsets.zero,
      clipBehavior: Clip.antiAlias,
      child: Column(
        children: <Widget>[
          for (int i = 0; i < AgreementDocuments.all.length; i++) ...<Widget>[
            if (i > 0) const Divider(height: 1),
            ListTile(
              leading: Icon(
                i == 0
                    ? Icons.description_outlined
                    : Icons.privacy_tip_outlined,
                color: theme.colorScheme.onSurfaceVariant,
              ),
              title: Text('《${AgreementDocuments.all[i].title}》'),
              subtitle: const Text('点击查看全文'),
              trailing: const Icon(Icons.chevron_right, size: 20),
              onTap: () => _openDocument(AgreementDocuments.all[i]),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildAgreementCheckbox(ThemeData theme) {
    final ColorScheme scheme = theme.colorScheme;
    final TextStyle? textStyle = theme.textTheme.bodyMedium?.copyWith(
      height: 1.6,
    );

    Widget link(AgreementDocument document) {
      return GestureDetector(
        onTap: () => _openDocument(document),
        child: Text(
          '《${document.title}》',
          style: textStyle?.copyWith(
            color: scheme.primary,
            fontWeight: FontWeight.w600,
          ),
        ),
      );
    }

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        // 勾选框与文案第一行对齐；整行文案也可点击切换，扩大命中区域。
        SizedBox(
          width: 40,
          height: 28,
          child: Checkbox(
            value: _agreed,
            onChanged: _submitting ? null : (_) => _toggleAgreed(),
          ),
        ),
        Expanded(
          child: GestureDetector(
            onTap: _toggleAgreed,
            behavior: HitTestBehavior.opaque,
            child: Padding(
              padding: const EdgeInsets.only(top: 3),
              child: Wrap(
                crossAxisAlignment: WrapCrossAlignment.center,
                children: <Widget>[
                  Text('我已阅读并同意', style: textStyle),
                  link(AgreementDocuments.userAgreement),
                  Text('与', style: textStyle),
                  link(AgreementDocuments.privacyPolicy),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
}
