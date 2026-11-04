import 'package:flutter/material.dart';
import 'package:superhut/pages/Electricitybill/electricity_history_models.dart';

/// 每日明细表：按日期倒序，数值右对齐，支持点行联动曲线高亮。
class UsageTableCard extends StatelessWidget {
  const UsageTableCard({
    super.key,
    required this.records,
    required this.highlightedDate,
    required this.onSelect,
  });

  /// 按日期降序。
  final List<UsageRecord> records;
  final DateTime? highlightedDate;
  final ValueChanged<UsageRecord> onSelect;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final highlightKey =
        highlightedDate == null ? null : formatApiDate(highlightedDate!);

    return Container(
      padding: const EdgeInsets.fromLTRB(8, 16, 8, 8),
      decoration: BoxDecoration(
        color: scheme.surfaceContainer,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  '每日明细',
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    color: scheme.onSurface,
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  '共 ${records.length} 天',
                  style: TextStyle(
                    fontSize: 12,
                    color: scheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 4),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8),
            child: Text(
              '电量单位 kWh，金额单位元',
              style: TextStyle(fontSize: 11, color: scheme.onSurfaceVariant),
            ),
          ),
          const SizedBox(height: 12),
          _TableHeader(scheme: scheme),
          if (records.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 24),
              child: Center(
                child: Text(
                  '该区间暂无明细',
                  style: TextStyle(
                    fontSize: 13,
                    color: scheme.onSurfaceVariant,
                  ),
                ),
              ),
            )
          else
            for (final record in records)
              _TableRow(
                record: record,
                scheme: scheme,
                selected: highlightKey == record.dateKey,
                onTap: () => onSelect(record),
              ),
        ],
      ),
    );
  }
}

class _TableHeader extends StatelessWidget {
  const _TableHeader({required this.scheme});

  final ColorScheme scheme;

  @override
  Widget build(BuildContext context) {
    final style = TextStyle(fontSize: 11, color: scheme.onSurfaceVariant);

    return Padding(
      padding: const EdgeInsets.fromLTRB(8, 0, 8, 8),
      child: Row(
        children: [
          Expanded(flex: 24, child: Text('日期', style: style)),
          Expanded(
            flex: 19,
            child: Text('用电', style: style, textAlign: TextAlign.right),
          ),
          Expanded(
            flex: 19,
            child: Text('消费', style: style, textAlign: TextAlign.right),
          ),
          Expanded(
            flex: 19,
            child: Text('充值', style: style, textAlign: TextAlign.right),
          ),
          Expanded(
            flex: 21,
            child: Text('余额', style: style, textAlign: TextAlign.right),
          ),
        ],
      ),
    );
  }
}

class _TableRow extends StatelessWidget {
  const _TableRow({
    required this.record,
    required this.scheme,
    required this.selected,
    required this.onTap,
  });

  final UsageRecord record;
  final ColorScheme scheme;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final date = record.statTime;
    final numberStyle = TextStyle(
      fontSize: 12.5,
      fontWeight: FontWeight.w500,
      color: scheme.onSurface,
      fontFeatures: const [FontFeature.tabularFigures()],
    );

    return Material(
      color:
          selected
              ? scheme.primary.withValues(alpha: 0.08)
              : Colors.transparent,
      borderRadius: BorderRadius.circular(8),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        child: Container(
          height: 44,
          padding: const EdgeInsets.symmetric(horizontal: 8),
          decoration: BoxDecoration(
            border: Border(
              bottom: BorderSide(
                color: scheme.outlineVariant.withValues(alpha: 0.28),
                width: 1,
              ),
            ),
          ),
          child: Row(
            children: [
              Expanded(
                flex: 24,
                child: Row(
                  children: [
                    if (selected)
                      Container(
                        width: 2,
                        height: 16,
                        margin: const EdgeInsets.only(right: 6),
                        decoration: BoxDecoration(
                          color: scheme.primary,
                          borderRadius: BorderRadius.circular(1),
                        ),
                      ),
                    Text(
                      '${date.month}/${date.day}',
                      style: TextStyle(
                        fontSize: 12.5,
                        fontWeight: FontWeight.w500,
                        color:
                            selected ? scheme.primary : scheme.onSurface,
                      ),
                    ),
                    const SizedBox(width: 4),
                    Text(
                      _weekdayLabel(date.weekday),
                      style: TextStyle(
                        fontSize: 10,
                        color: scheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
              Expanded(
                flex: 19,
                child: Text(
                  record.kwh.toStringAsFixed(2),
                  style: numberStyle,
                  textAlign: TextAlign.right,
                ),
              ),
              Expanded(
                flex: 19,
                child: Text(
                  record.cost.toStringAsFixed(2),
                  style: numberStyle,
                  textAlign: TextAlign.right,
                ),
              ),
              Expanded(
                flex: 19,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    if (record.recharge > 0) ...[
                      Container(
                        width: 5,
                        height: 5,
                        decoration: const BoxDecoration(
                          color: Color(0xFF4CAF50),
                          shape: BoxShape.circle,
                        ),
                      ),
                      const SizedBox(width: 4),
                    ],
                    Text(
                      record.recharge > 0
                          ? record.recharge.toStringAsFixed(2)
                          : '—',
                      style: TextStyle(
                        fontSize: 12.5,
                        fontWeight:
                            record.recharge > 0
                                ? FontWeight.w600
                                : FontWeight.w400,
                        color:
                            record.recharge > 0
                                ? const Color(0xFF2E7D32)
                                : scheme.onSurfaceVariant,
                        fontFeatures: const [FontFeature.tabularFigures()],
                      ),
                      textAlign: TextAlign.right,
                    ),
                  ],
                ),
              ),
              Expanded(
                flex: 21,
                child: Text(
                  record.balance.toStringAsFixed(2),
                  style: numberStyle,
                  textAlign: TextAlign.right,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _weekdayLabel(int weekday) {
    const labels = ['一', '二', '三', '四', '五', '六', '日'];
    return '周${labels[(weekday - 1).clamp(0, 6)]}';
  }
}
