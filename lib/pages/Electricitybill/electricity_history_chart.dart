import 'dart:math' as math;

import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:superhut/pages/Electricitybill/electricity_history_models.dart';

/// 用电趋势卡片：三个指标共用同一份数据，切换不触发网络请求。
class UsageChartCard extends StatelessWidget {
  const UsageChartCard({
    super.key,
    required this.records,
    required this.metric,
    required this.onMetricChanged,
    this.highlightedDate,
  });

  /// 按日期升序。
  final List<UsageRecord> records;
  final UsageMetric metric;
  final ValueChanged<UsageMetric> onMetricChanged;

  /// 明细表点选的日期，对应数据点会常驻高亮。
  final DateTime? highlightedDate;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return Container(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
      decoration: BoxDecoration(
        color: scheme.surfaceContainer,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                '趋势',
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                  color: scheme.onSurface,
                ),
              ),
              const Spacer(),
              _MetricTabs(metric: metric, onChanged: onMetricChanged),
            ],
          ),
          const SizedBox(height: 12),
          SizedBox(
            height: 200,
            child:
                records.isEmpty
                    ? Center(
                      child: Text(
                        '该区间暂无数据',
                        style: TextStyle(
                          fontSize: 13,
                          color: scheme.onSurfaceVariant,
                        ),
                      ),
                    )
                    : LineChart(
                      _buildData(context),
                      duration: const Duration(milliseconds: 260),
                      curve: Curves.easeOutCubic,
                    ),
          ),
        ],
      ),
    );
  }

  LineChartData _buildData(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final values =
        records.map((record) => metric.valueOf(record)).toList(growable: false);
    final maxValue = values.reduce(math.max);
    final minValue = values.reduce(math.min);

    double minY;
    double maxY;
    if (metric == UsageMetric.balance) {
      // 余额全程贴着某个值波动时，从 0 起画会把曲线压成一条直线。
      final span = (maxValue - minValue).abs();
      final pad = span < 0.5 ? math.max(maxValue.abs() * 0.05, 1.0) : span * 0.18;
      minY = minValue - pad;
      maxY = maxValue + pad;
    } else {
      minY = 0;
      maxY = maxValue <= 0 ? 1 : maxValue * 1.18;
    }
    final interval = math.max((maxY - minY) / 4, 0.01);

    final highlightIndex =
        highlightedDate == null
            ? -1
            : records.indexWhere(
              (record) => record.dateKey == formatApiDate(highlightedDate!),
            );

    // 只有一个数据点时 minX == maxX，fl_chart 会算出 NaN 的绘制比例。
    final singlePoint = records.length == 1;

    return LineChartData(
      minX: singlePoint ? -0.5 : 0,
      maxX: singlePoint ? 0.5 : (records.length - 1).toDouble(),
      minY: minY,
      maxY: maxY,
      clipData: const FlClipData.none(),
      gridData: FlGridData(
        show: true,
        drawVerticalLine: false,
        horizontalInterval: interval,
        getDrawingHorizontalLine:
            (value) => FlLine(
              color: scheme.outlineVariant.withValues(alpha: 0.45),
              strokeWidth: 1,
              dashArray: const [4, 4],
            ),
      ),
      borderData: FlBorderData(show: false),
      titlesData: FlTitlesData(
        topTitles: const AxisTitles(
          sideTitles: SideTitles(showTitles: false),
        ),
        rightTitles: const AxisTitles(
          sideTitles: SideTitles(showTitles: false),
        ),
        leftTitles: AxisTitles(
          sideTitles: SideTitles(
            showTitles: true,
            reservedSize: 42,
            interval: interval,
            getTitlesWidget:
                (value, meta) => SideTitleWidget(
                  meta: meta,
                  space: 6,
                  child: Text(
                    metric.formatAxis(value),
                    style: TextStyle(
                      fontSize: 10,
                      color: scheme.onSurfaceVariant,
                    ),
                  ),
                ),
          ),
        ),
        bottomTitles: AxisTitles(
          sideTitles: SideTitles(
            showTitles: true,
            reservedSize: 28,
            interval: 1,
            getTitlesWidget: (value, meta) {
              final index = value.round();
              if (index < 0 || index >= records.length) {
                return const SizedBox.shrink();
              }
              final isEdge = index == 0 || index == records.length - 1;
              final isMiddle = index == records.length ~/ 2;
              if (!isEdge && !isMiddle) return const SizedBox.shrink();
              final date = records[index].statTime;
              return SideTitleWidget(
                meta: meta,
                space: 6,
                child: Text(
                  '${date.month}/${date.day}',
                  style: TextStyle(
                    fontSize: 10,
                    color: scheme.onSurfaceVariant,
                  ),
                ),
              );
            },
          ),
        ),
      ),
      lineTouchData: LineTouchData(
        handleBuiltInTouches: true,
        touchTooltipData: LineTouchTooltipData(
          fitInsideHorizontally: true,
          fitInsideVertically: true,
          tooltipBorderRadius: BorderRadius.circular(10),
          tooltipPadding: const EdgeInsets.symmetric(
            horizontal: 10,
            vertical: 6,
          ),
          getTooltipColor: (_) => scheme.inverseSurface.withValues(alpha: 0.92),
          getTooltipItems: (touchedSpots) {
            return touchedSpots.map((spot) {
              final index = spot.x.round().clamp(0, records.length - 1);
              final date = records[index].statTime;
              return LineTooltipItem(
                '${date.month} 月 ${date.day} 日\n'
                '${metric.format(values[index])} ${metric.unit}',
                TextStyle(
                  color: scheme.onInverseSurface,
                  fontSize: 12,
                  height: 1.4,
                  fontWeight: FontWeight.w600,
                ),
              );
            }).toList();
          },
        ),
        getTouchedSpotIndicator: (barData, spotIndexes) {
          return spotIndexes
              .map(
                (_) => TouchedSpotIndicatorData(
                  FlLine(
                    color: scheme.primary.withValues(alpha: 0.35),
                    strokeWidth: 1.5,
                    dashArray: const [4, 4],
                  ),
                  FlDotData(
                    show: true,
                    getDotPainter:
                        (spot, percent, barData, index) => FlDotCirclePainter(
                          radius: 4,
                          color: scheme.primary,
                          strokeWidth: 2,
                          strokeColor: scheme.surface,
                        ),
                  ),
                ),
              )
              .toList();
        },
      ),
      lineBarsData: [
        LineChartBarData(
          spots: List.generate(
            values.length,
            (index) => FlSpot(index.toDouble(), values[index]),
          ),
          showingIndicators:
              highlightIndex >= 0 ? [highlightIndex] : const [],
          isCurved: true,
          curveSmoothness: 0.18,
          preventCurveOverShooting: true,
          barWidth: 2.6,
          isStrokeCapRound: true,
          gradient: LinearGradient(
            colors: [scheme.primary, scheme.primary.withValues(alpha: 0.72)],
          ),
          dotData: FlDotData(
            show: records.length <= 10,
            getDotPainter:
                (spot, percent, barData, index) => FlDotCirclePainter(
                  radius: 3,
                  color: scheme.primary,
                  strokeWidth: 1.5,
                  strokeColor: scheme.surface,
                ),
          ),
          belowBarData: BarAreaData(
            show: true,
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                scheme.primary.withValues(alpha: 0.30),
                scheme.primary.withValues(alpha: 0.02),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

/// 指标切换：内容层，保持 Material 纯色药丸，不使用玻璃。
class _MetricTabs extends StatelessWidget {
  const _MetricTabs({required this.metric, required this.onChanged});

  final UsageMetric metric;
  final ValueChanged<UsageMetric> onChanged;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return Container(
      padding: const EdgeInsets.all(3),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          for (final item in UsageMetric.values)
            GestureDetector(
              onTap: () => onChanged(item),
              behavior: HitTestBehavior.opaque,
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 180),
                curve: Curves.easeOut,
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 5,
                ),
                decoration: BoxDecoration(
                  color:
                      item == metric ? scheme.surface : Colors.transparent,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  item.label,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight:
                        item == metric ? FontWeight.w600 : FontWeight.w400,
                    color:
                        item == metric
                            ? scheme.primary
                            : scheme.onSurfaceVariant,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
