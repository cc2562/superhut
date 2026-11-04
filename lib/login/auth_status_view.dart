import 'package:flutter/material.dart';

/// 统一认证流程的状态页：准备凭据、首次加载网页、加载失败三处共用。
///
/// 版式对齐「刷新课表」页（`CourseRefreshContent`）：居中 88 圆图标底、
/// `headlineSmall` 标题、`bodyMedium` 说明、圆角胶囊进度条与全宽按钮组，
/// 不叠加液态玻璃，页面底色就是 `surface`。
class AuthStatusView extends StatelessWidget {
  const AuthStatusView({
    super.key,
    required this.title,
    required this.description,
    this.icon = Icons.lock_outline_rounded,
    this.isError = false,
    this.showProgress = false,
    this.progress,
    this.actions = const <Widget>[],
  });

  /// 主标题。
  final String title;

  /// 标题下方的说明文字。
  final String description;

  /// 圆形底里的图标。
  final IconData icon;

  /// 失败态：圆形底与图标改用错误色。
  final bool isError;

  /// 是否在说明下方显示进度条。
  final bool showProgress;

  /// 进度值（0–1）；为 `null` 时显示不确定进度。
  final double? progress;

  /// 进度条下方的按钮组，逐个占满宽度。
  final List<Widget> actions;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final ColorScheme colors = theme.colorScheme;
    final double? value = progress?.clamp(0, 1).toDouble();
    final int percentage = ((value ?? 0) * 100).round();

    return LayoutBuilder(
      builder: (BuildContext context, BoxConstraints constraints) {
        return SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 24),
          child: ConstrainedBox(
            constraints: BoxConstraints(minHeight: constraints.maxHeight - 48),
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 440),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: <Widget>[
                    AnimatedContainer(
                      duration: const Duration(milliseconds: 260),
                      curve: Curves.easeOut,
                      width: 88,
                      height: 88,
                      decoration: BoxDecoration(
                        color:
                            isError
                                ? colors.errorContainer
                                : colors.primaryContainer.withValues(
                                  alpha: 0.65,
                                ),
                        shape: BoxShape.circle,
                      ),
                      child: AnimatedSwitcher(
                        duration: const Duration(milliseconds: 220),
                        child: Icon(
                          icon,
                          key: ValueKey<IconData>(icon),
                          size: 42,
                          color:
                              isError
                                  ? colors.onErrorContainer
                                  : colors.onPrimaryContainer,
                        ),
                      ),
                    ),
                    const SizedBox(height: 32),
                    AnimatedSwitcher(
                      duration: const Duration(milliseconds: 220),
                      child: Text(
                        title,
                        key: ValueKey<String>(title),
                        textAlign: TextAlign.center,
                        style: theme.textTheme.headlineSmall?.copyWith(
                          fontWeight: FontWeight.w700,
                          color: colors.onSurface,
                        ),
                      ),
                    ),
                    const SizedBox(height: 10),
                    Text(
                      description,
                      textAlign: TextAlign.center,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: colors.onSurfaceVariant,
                        height: 1.5,
                      ),
                    ),
                    if (showProgress) ...<Widget>[
                      const SizedBox(height: 36),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(99),
                        child: LinearProgressIndicator(
                          minHeight: 6,
                          value: value,
                          backgroundColor: colors.surfaceContainerHighest,
                        ),
                      ),
                      if (value != null) ...<Widget>[
                        const SizedBox(height: 12),
                        Align(
                          alignment: Alignment.centerRight,
                          child: Text(
                            '$percentage%',
                            style: theme.textTheme.labelMedium?.copyWith(
                              color: colors.onSurfaceVariant,
                            ),
                          ),
                        ),
                      ],
                    ],
                    if (actions.isNotEmpty) ...<Widget>[
                      const SizedBox(height: 32),
                      for (int index = 0; index < actions.length; index++)
                        Padding(
                          padding: EdgeInsets.only(top: index == 0 ? 0 : 10),
                          child: SizedBox(
                            width: double.infinity,
                            child: actions[index],
                          ),
                        ),
                    ],
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}
