import 'package:flutter/material.dart';
import 'package:superhut/home/homeview/view.dart';

import '../utils/course/coursemain.dart';
import '../utils/token.dart';

enum CourseRefreshViewState { loading, success, failure }

class Getcoursepage extends StatefulWidget {
  final bool renew;

  const Getcoursepage({super.key, required this.renew});

  @override
  State<Getcoursepage> createState() => _GetcoursepageState();
}

class _GetcoursepageState extends State<Getcoursepage> {
  CourseRefreshViewState _viewState = CourseRefreshViewState.loading;
  double _progress = 0;
  bool _isRefreshing = false;

  @override
  void initState() {
    super.initState();
    _refreshCourses();
  }

  Future<void> _refreshCourses() async {
    if (_isRefreshing) return;

    setState(() {
      _isRefreshing = true;
      _viewState = CourseRefreshViewState.loading;
      _progress = 0;
    });

    try {
      final String token = await getToken();
      await saveClassToLocal(
        token,
        onProgress: (CourseRefreshProgress progress) {
          if (!mounted) return;
          setState(() => _progress = progress.value);
        },
      );

      if (!mounted) return;
      setState(() {
        _isRefreshing = false;
        _viewState = CourseRefreshViewState.success;
        _progress = 1;
      });

      await Future<void>.delayed(const Duration(seconds: 1));
      if (!mounted) return;
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute<void>(builder: (_) => const HomeviewPage()),
        (Route<dynamic> route) => false,
      );
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _isRefreshing = false;
        _viewState = CourseRefreshViewState.failure;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final bool canPop = _viewState == CourseRefreshViewState.failure;
    return PopScope(
      canPop: canPop,
      child: Scaffold(
        backgroundColor: Theme.of(context).colorScheme.surface,
        body: SafeArea(
          child: CourseRefreshContent(
            state: _viewState,
            progress: _progress,
            isRenew: widget.renew,
            onRetry: _refreshCourses,
            onBack: () => Navigator.of(context).maybePop(),
          ),
        ),
      ),
    );
  }
}

class CourseRefreshContent extends StatelessWidget {
  final CourseRefreshViewState state;
  final double progress;
  final bool isRenew;
  final VoidCallback? onRetry;
  final VoidCallback? onBack;

  const CourseRefreshContent({
    super.key,
    required this.state,
    required this.progress,
    this.isRenew = true,
    this.onRetry,
    this.onBack,
  });

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final ColorScheme colors = theme.colorScheme;
    final bool isLoading = state == CourseRefreshViewState.loading;
    final bool isSuccess = state == CourseRefreshViewState.success;
    final int percentage = (progress.clamp(0, 1) * 100).round();

    final String title = switch (state) {
      CourseRefreshViewState.loading => '正在刷新课表',
      CourseRefreshViewState.success => '课表刷新完成',
      CourseRefreshViewState.failure => '刷新失败',
    };
    final String description = switch (state) {
      CourseRefreshViewState.loading => '正在同步课程数据，请稍候',
      CourseRefreshViewState.success => '最新课程已经准备好了',
      CourseRefreshViewState.failure =>
        isRenew ? '请检查网络后重试，原有课表不会受到影响' : '请检查网络后重试，或返回重新登录',
    };

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
                  children: [
                    AnimatedContainer(
                      duration: const Duration(milliseconds: 260),
                      curve: Curves.easeOut,
                      width: 88,
                      height: 88,
                      decoration: BoxDecoration(
                        color:
                            isSuccess
                                ? colors.primaryContainer
                                : state == CourseRefreshViewState.failure
                                ? colors.errorContainer
                                : colors.primaryContainer.withValues(
                                  alpha: 0.65,
                                ),
                        shape: BoxShape.circle,
                      ),
                      child: AnimatedSwitcher(
                        duration: const Duration(milliseconds: 220),
                        child: Icon(
                          isSuccess
                              ? Icons.check_rounded
                              : state == CourseRefreshViewState.failure
                              ? Icons.refresh_rounded
                              : Icons.calendar_month_outlined,
                          key: ValueKey<CourseRefreshViewState>(state),
                          size: 42,
                          color:
                              state == CourseRefreshViewState.failure
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
                    if (isLoading || isSuccess) ...[
                      const SizedBox(height: 36),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(99),
                        child: LinearProgressIndicator(
                          minHeight: 6,
                          value: progress.clamp(0, 1),
                          backgroundColor: colors.surfaceContainerHighest,
                        ),
                      ),
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
                    if (state == CourseRefreshViewState.failure) ...[
                      const SizedBox(height: 32),
                      SizedBox(
                        width: double.infinity,
                        child: FilledButton(
                          onPressed: onRetry,
                          child: const Text('重新尝试'),
                        ),
                      ),
                      const SizedBox(height: 10),
                      SizedBox(
                        width: double.infinity,
                        child: TextButton(
                          onPressed: onBack,
                          child: const Text('返回'),
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
