import 'package:flutter/material.dart';
import 'package:ionicons_plus/ionicons_plus.dart';
import 'package:superhut/login/auth_status_view.dart';
import 'package:superhut/pages/health/health_score_api.dart';
import 'package:superhut/pages/health/health_score_detail_page.dart';
import 'package:superhut/pages/health/health_score_models.dart';
import 'package:superhut/pages/health/health_score_trend_chart.dart';
import 'package:superhut/pages/health/health_score_widgets.dart';
import 'package:superhut/theme/glass/glass_scaffold.dart';
import 'package:superhut/theme/glass/glass_top_bar.dart';

/// 体测查询主页：最近一次总览 + 历年趋势 + 历年记录。
class HealthScorePage extends StatefulWidget {
  const HealthScorePage({super.key, this.api});

  /// 测试或复用会话时注入；默认新建独立实例。
  final HealthScoreApi? api;

  @override
  State<HealthScorePage> createState() => _HealthScorePageState();
}

class _HealthScorePageState extends State<HealthScorePage> {
  late final HealthScoreApi _api = widget.api ?? HealthScoreApi();

  HealthScoreSnapshot? _snapshot;
  Object? _error;
  bool _loading = true;
  int _requestSeq = 0;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load({bool showLoading = true}) async {
    final int seq = ++_requestSeq;
    if (showLoading) {
      setState(() {
        _loading = true;
        _error = null;
      });
    }

    try {
      final HealthScoreSnapshot snapshot = await _api.fetchSnapshot();
      if (!mounted || seq != _requestSeq) return;
      setState(() {
        _snapshot = snapshot;
        _error = null;
        _loading = false;
      });
    } catch (error) {
      if (!mounted || seq != _requestSeq) return;
      if (_snapshot != null) {
        // 下拉刷新失败时保留旧数据，只提示，不把整页打成错误态。
        ScaffoldMessenger.maybeOf(
          context,
        )?.showSnackBar(SnackBar(content: Text(_describe(error))));
        setState(() => _loading = false);
        return;
      }
      setState(() {
        _error = error;
        _loading = false;
      });
    }
  }

  Future<void> _refresh() => _load(showLoading: false);

  String _describe(Object? error) {
    if (error is HealthScoreAuthException) return error.message;
    if (error is HealthScoreException) return error.message;
    return '加载失败，请稍后重试';
  }

  bool _isAuthError(Object? error) => error is HealthScoreAuthException;

  void _openDetail(HealthTermRecord record) {
    if (!record.hasDetail) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('该学年缺少详情参数，无法查看')));
      return;
    }
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => HealthScoreDetailPage(api: _api, record: record),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final ColorScheme scheme = Theme.of(context).colorScheme;

    return GlassScaffold(
      title: '体测查询',
      backgroundColor: scheme.surface,
      actions: <Widget>[
        GlassActionButton(
          icon: Ionicons.refresh_outline,
          tooltip: '刷新',
          semanticLabel: '刷新体测成绩',
          onPressed: _loading ? null : () => _load(),
        ),
      ],
      body: _buildBody(context),
    );
  }

  Widget _buildBody(BuildContext context) {
    if (_loading && _snapshot == null) {
      return Padding(
        padding: EdgeInsets.only(top: glassTopInset(context)),
        child: const AuthStatusView(
          icon: Icons.fitness_center_rounded,
          title: '正在查询体测成绩',
          description: '正在连接学校体测平台，首次进入可能需要几秒',
          showProgress: true,
        ),
      );
    }

    if (_error != null && _snapshot == null) {
      final bool auth = _isAuthError(_error);
      return Padding(
        padding: EdgeInsets.only(top: glassTopInset(context)),
        child: AuthStatusView(
          icon: auth ? Icons.lock_outline_rounded : Icons.cloud_off_rounded,
          title: auth ? '登录状态已失效' : '体测数据加载失败',
          description: _describe(_error),
          isError: true,
          actions: <Widget>[
            // 认证类失败不做原地续期：入口页已经走过 renewToken，JWXT 有效而
            // hutToken 失效时再刷也恢复不了，直接退回功能选择页重新发起。
            if (auth)
              FilledButton.tonal(
                onPressed: () => Navigator.of(context).maybePop(),
                child: const Text('返回'),
              )
            else
              FilledButton(onPressed: () => _load(), child: const Text('重试')),
          ],
        ),
      );
    }

    final HealthScoreSnapshot snapshot = _snapshot!;
    final List<HealthTermRecord> records = snapshot.recordsByNewest;
    final HealthTermRecord? latest = snapshot.latest;

    return RefreshIndicator(
      onRefresh: _refresh,
      // 玻璃顶栏悬浮在内容上，下拉指示器要避开它。
      edgeOffset: glassTopInset(context),
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: EdgeInsets.fromLTRB(16, glassTopInset(context) + 8, 16, 32),
        children: <Widget>[
          if (latest == null)
            _EmptyCard(onRefresh: _refresh)
          else ...<Widget>[
            _OverviewCard(record: latest, totalCount: records.length),
            const SizedBox(height: 12),
            HealthScoreTrendCard(records: snapshot.recordsByOldest),
            const SizedBox(height: 22),
            HealthSectionHeader(title: '历年记录', trailing: '${records.length} 次'),
            const SizedBox(height: 8),
            _RecordList(records: records, onTap: _openDetail),
          ],
        ],
      ),
    );
  }
}

/// 最近一次体测总览。
class _OverviewCard extends StatelessWidget {
  const _OverviewCard({required this.record, required this.totalCount});

  final HealthTermRecord record;
  final int totalCount;

  @override
  Widget build(BuildContext context) {
    final ColorScheme scheme = Theme.of(context).colorScheme;
    final List<Widget> info = <Widget>[
      if (record.grade.trim().isNotEmpty)
        _OverviewInfo(label: '年级', value: record.grade.trim()),
      if (record.bonus.trim().isNotEmpty)
        _OverviewInfo(label: '加分', value: record.bonus.trim()),
      _OverviewInfo(label: '测试次数', value: '$totalCount 次'),
    ];

    return HealthCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              Text(
                '最近一次',
                style: TextStyle(fontSize: 12, color: scheme.onSurfaceVariant),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  record.label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                    color: scheme.onSurfaceVariant,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: <Widget>[
              Text(
                formatHealthScore(record.score),
                style: TextStyle(
                  fontSize: 46,
                  height: 1,
                  fontWeight: FontWeight.w700,
                  letterSpacing: -1,
                  color: scheme.onSurface,
                ),
              ),
              Padding(
                padding: const EdgeInsets.only(left: 6, bottom: 5),
                child: Text(
                  '分',
                  style: TextStyle(
                    fontSize: 13,
                    color: scheme.onSurfaceVariant,
                  ),
                ),
              ),
              const Spacer(),
              Padding(
                padding: const EdgeInsets.only(bottom: 4),
                child: HealthLevelBadge(
                  level: record.level,
                  score: record.score,
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),
          Divider(
            height: 1,
            thickness: 1,
            color: scheme.outlineVariant.withValues(alpha: 0.5),
          ),
          const SizedBox(height: 14),
          Row(
            children: <Widget>[
              for (int i = 0; i < info.length; i++) ...<Widget>[
                if (i > 0) const SizedBox(width: 24),
                info[i],
              ],
            ],
          ),
        ],
      ),
    );
  }
}

class _OverviewInfo extends StatelessWidget {
  const _OverviewInfo({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final ColorScheme scheme = Theme.of(context).colorScheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Text(
          label,
          style: TextStyle(fontSize: 11, color: scheme.onSurfaceVariant),
        ),
        const SizedBox(height: 2),
        Text(
          value,
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: scheme.onSurface,
          ),
        ),
      ],
    );
  }
}

/// 历年记录列表：整张卡内按行分隔，点击进入学年详情。
class _RecordList extends StatelessWidget {
  const _RecordList({required this.records, required this.onTap});

  final List<HealthTermRecord> records;
  final ValueChanged<HealthTermRecord> onTap;

  @override
  Widget build(BuildContext context) {
    final ColorScheme scheme = Theme.of(context).colorScheme;

    return HealthCard(
      padding: EdgeInsets.zero,
      child: Column(
        children: <Widget>[
          for (int i = 0; i < records.length; i++) ...<Widget>[
            if (i > 0)
              Divider(
                height: 1,
                thickness: 1,
                indent: 16,
                endIndent: 16,
                color: scheme.outlineVariant.withValues(alpha: 0.5),
              ),
            InkWell(
              onTap: () => onTap(records[i]),
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 14, 12, 14),
                child: Row(
                  children: <Widget>[
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: <Widget>[
                          Text(
                            records[i].label,
                            style: TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w600,
                              color: scheme.onSurface,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            _subtitle(records[i]),
                            style: TextStyle(
                              fontSize: 12,
                              color: scheme.onSurfaceVariant,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 12),
                    Text(
                      formatHealthScore(records[i].score),
                      style: TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.w700,
                        color: scheme.onSurface,
                      ),
                    ),
                    const SizedBox(width: 10),
                    HealthLevelBadge(
                      level: records[i].level,
                      score: records[i].score,
                    ),
                    Icon(
                      Icons.chevron_right_rounded,
                      size: 20,
                      color: scheme.onSurfaceVariant,
                    ),
                  ],
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  String _subtitle(HealthTermRecord record) {
    final List<String> parts = <String>[
      if (record.grade.trim().isNotEmpty) '年级 ${record.grade.trim()}',
      if (record.bonus.trim().isNotEmpty) '加分 ${record.bonus.trim()}',
    ];
    return parts.isEmpty ? '查看项目明细' : parts.join(' · ');
  }
}

/// 无记录空态：保留下拉刷新与按钮刷新两条入口。
class _EmptyCard extends StatelessWidget {
  const _EmptyCard({required this.onRefresh});

  final Future<void> Function() onRefresh;

  @override
  Widget build(BuildContext context) {
    final ColorScheme scheme = Theme.of(context).colorScheme;
    return HealthCard(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 32),
      child: Column(
        children: <Widget>[
          Container(
            width: 72,
            height: 72,
            decoration: BoxDecoration(
              color: scheme.primaryContainer.withValues(alpha: 0.6),
              shape: BoxShape.circle,
            ),
            child: Icon(
              Icons.fitness_center_rounded,
              size: 34,
              color: scheme.onPrimaryContainer,
            ),
          ),
          const SizedBox(height: 20),
          Text(
            '暂无体测记录',
            style: TextStyle(
              fontSize: 17,
              fontWeight: FontWeight.w600,
              color: scheme.onSurface,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            '学校体测平台还没有返回你的成绩，下拉或点击刷新再试一次',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 13,
              height: 1.5,
              color: scheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 20),
          FilledButton.tonal(onPressed: onRefresh, child: const Text('刷新')),
        ],
      ),
    );
  }
}
