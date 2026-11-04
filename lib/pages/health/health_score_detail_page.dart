import 'package:flutter/material.dart';
import 'package:ionicons_plus/ionicons_plus.dart';
import 'package:superhut/login/auth_status_view.dart';
import 'package:superhut/pages/health/health_score_api.dart';
import 'package:superhut/pages/health/health_score_models.dart';
import 'package:superhut/pages/health/health_score_widgets.dart';
import 'package:superhut/theme/glass/glass_scaffold.dart';
import 'package:superhut/theme/glass/glass_top_bar.dart';

/// 学年体测详情：按服务端表头列与行序渲染全部项目。
///
/// 不预设男女项目清单，也不按项目关键词过滤；男生 / 女生差异完全由接口
/// 返回的行序体现。
class HealthScoreDetailPage extends StatefulWidget {
  const HealthScoreDetailPage({
    super.key,
    required this.api,
    required this.record,
  });

  /// 与主页共用同一个实例，复用已建立的会话。
  final HealthScoreApi api;

  final HealthTermRecord record;

  @override
  State<HealthScoreDetailPage> createState() => _HealthScoreDetailPageState();
}

class _HealthScoreDetailPageState extends State<HealthScoreDetailPage> {
  HealthDetailTable? _table;
  Object? _error;
  bool _loading = true;
  int _requestSeq = 0;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final int seq = ++_requestSeq;
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final HealthDetailTable table = await widget.api.fetchDetail(
        widget.record,
      );
      if (!mounted || seq != _requestSeq) return;
      setState(() {
        _table = table;
        _loading = false;
      });
    } catch (error) {
      if (!mounted || seq != _requestSeq) return;
      setState(() {
        _error = error;
        _loading = false;
      });
    }
  }

  String _describe(Object? error) {
    if (error is HealthScoreAuthException) return error.message;
    if (error is HealthScoreException) return error.message;
    return '加载失败，请稍后重试';
  }

  @override
  Widget build(BuildContext context) {
    final ColorScheme scheme = Theme.of(context).colorScheme;

    return GlassScaffold(
      title: '体测详情',
      backgroundColor: scheme.surface,
      actions: <Widget>[
        GlassActionButton(
          icon: Ionicons.refresh_outline,
          tooltip: '刷新',
          semanticLabel: '刷新体测详情',
          onPressed: _loading ? null : _load,
        ),
      ],
      body: _buildBody(context),
    );
  }

  Widget _buildBody(BuildContext context) {
    if (_loading) {
      return Padding(
        padding: EdgeInsets.only(top: glassTopInset(context)),
        child: const AuthStatusView(
          icon: Icons.list_alt_rounded,
          title: '正在加载体测详情',
          description: '正在读取该学年各项目成绩',
          showProgress: true,
        ),
      );
    }

    if (_error != null) {
      final bool auth = _error is HealthScoreAuthException;
      return Padding(
        padding: EdgeInsets.only(top: glassTopInset(context)),
        child: AuthStatusView(
          icon: auth ? Icons.lock_outline_rounded : Icons.cloud_off_rounded,
          title: auth ? '登录状态已失效' : '详情加载失败',
          description: _describe(_error),
          isError: true,
          actions: <Widget>[
            // 认证类失败不做原地续期，直接退回上一页重新发起（同主页）。
            if (auth)
              FilledButton(
                onPressed: () => Navigator.of(context).maybePop(),
                child: const Text('返回'),
              )
            else ...<Widget>[
              FilledButton(onPressed: _load, child: const Text('重试')),
              TextButton(
                onPressed: () => Navigator.of(context).maybePop(),
                child: const Text('返回'),
              ),
            ],
          ],
        ),
      );
    }

    final HealthDetailTable table = _table!;
    return ListView(
      padding: EdgeInsets.fromLTRB(16, glassTopInset(context) + 8, 16, 32),
      children: <Widget>[
        _SummaryCard(record: widget.record),
        const SizedBox(height: 12),
        _DetailTableCard(table: table),
        const SizedBox(height: 14),
        Padding(padding: const EdgeInsets.symmetric(horizontal: 4)),
      ],
    );
  }
}

/// 学年摘要：学年学期 / 总分 / 等级。
class _SummaryCard extends StatelessWidget {
  const _SummaryCard({required this.record});

  final HealthTermRecord record;

  @override
  Widget build(BuildContext context) {
    final ColorScheme scheme = Theme.of(context).colorScheme;

    return HealthCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Expanded(
                flex: 3,
                child: _SummaryCell(
                  label: '学年学期',
                  value: record.label,
                  valueSize: 15,
                ),
              ),
              Expanded(
                flex: 2,
                child: _SummaryCell(
                  label: '总分',
                  value: formatHealthScore(record.score),
                  valueSize: 28,
                  emphasize: true,
                ),
              ),
              Expanded(
                flex: 2,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      '等级',
                      style: TextStyle(
                        fontSize: 11,
                        color: scheme.onSurfaceVariant,
                      ),
                    ),
                    const SizedBox(height: 6),
                    HealthLevelBadge(level: record.level, score: record.score),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Text(
            '数据来自学校体测平台',
            style: TextStyle(fontSize: 11, color: scheme.onSurfaceVariant),
          ),
        ],
      ),
    );
  }
}

class _SummaryCell extends StatelessWidget {
  const _SummaryCell({
    required this.label,
    required this.value,
    this.valueSize = 15,
    this.emphasize = false,
  });

  final String label;
  final String value;
  final double valueSize;
  final bool emphasize;

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
        const SizedBox(height: 6),
        Text(
          value,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            fontSize: valueSize,
            fontWeight: emphasize ? FontWeight.w700 : FontWeight.w600,
            height: 1.1,
            color: emphasize ? scheme.primary : scheme.onSurface,
          ),
        ),
      ],
    );
  }
}

/// 项目明细表。列名与行序均来自服务端解析结果。
class _DetailTableCard extends StatelessWidget {
  const _DetailTableCard({required this.table});

  final HealthDetailTable table;

  @override
  Widget build(BuildContext context) {
    final ColorScheme scheme = Theme.of(context).colorScheme;

    return HealthCard(
      padding: EdgeInsets.zero,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 18, 20, 14),
            child: HealthSectionHeader(
              title: '项目明细',
              trailing: table.isEmpty ? null : '共 ${table.rows.length} 项',
            ),
          ),
          if (table.isEmpty)
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 28),
              child: Text(
                '该学年没有返回项目明细',
                style: TextStyle(fontSize: 13, color: scheme.onSurfaceVariant),
              ),
            )
          else
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.only(bottom: 8),
              child: ConstrainedBox(
                constraints: BoxConstraints(
                  minWidth: MediaQuery.sizeOf(context).width - 32,
                ),
                child: DataTable(
                  headingRowHeight: 42,
                  dataRowMinHeight: 44,
                  dataRowMaxHeight: 60,
                  horizontalMargin: 20,
                  columnSpacing: 20,
                  dividerThickness: 0.6,
                  headingRowColor: WidgetStatePropertyAll<Color?>(
                    scheme.surfaceContainerHighest.withValues(alpha: 0.55),
                  ),
                  columns: <DataColumn>[
                    for (final String column in table.columns)
                      DataColumn(
                        label: Text(
                          column,
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: scheme.onSurfaceVariant,
                          ),
                        ),
                      ),
                  ],
                  rows: <DataRow>[
                    for (final List<String> row in table.rows)
                      DataRow(
                        cells: <DataCell>[
                          for (int i = 0; i < table.columns.length; i++)
                            DataCell(
                              Text(
                                i < row.length ? row[i] : '',
                                style: TextStyle(
                                  fontSize: 13,
                                  height: 1.35,
                                  color:
                                      i == 0
                                          ? scheme.onSurface
                                          : scheme.onSurfaceVariant,
                                  fontWeight:
                                      i == 0
                                          ? FontWeight.w600
                                          : FontWeight.w400,
                                ),
                              ),
                            ),
                        ],
                      ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
}
