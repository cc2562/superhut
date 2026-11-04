import 'dart:math' as math;

import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:superhut/pages/health/health_score_models.dart';
import 'package:superhut/pages/health/health_score_widgets.dart';

/// 青绿主色：与体测平台趋势图、App 的强调色保持一致。
const Color _healthAccent = Color(0xFF0E8C86);

/// 历年总分趋势卡。
///
/// [records] 需按学年学期升序；没有分数的记录会被跳过，不画成 0 分。
class HealthScoreTrendCard extends StatelessWidget {
  const HealthScoreTrendCard({super.key, required this.records});

  final List<HealthTermRecord> records;

  @override
  Widget build(BuildContext context) {
    final ColorScheme scheme = Theme.of(context).colorScheme;
    final List<HealthTermRecord> points =
        records.where((record) => record.score != null).toList();

    return HealthCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          HealthSectionHeader(
            title: '历年总分趋势',
            trailing: points.isEmpty ? null : '${points.length} 次',
          ),
          const SizedBox(height: 12),
          SizedBox(
            height: 200,
            child:
                points.isEmpty
                    ? Center(
                      child: Text(
                        '暂无可绘制的分数',
                        style: TextStyle(
                          fontSize: 13,
                          color: scheme.onSurfaceVariant,
                        ),
                      ),
                    )
                    : LineChart(
                      _buildData(context, points),
                      duration: const Duration(milliseconds: 260),
                      curve: Curves.easeOutCubic,
                    ),
          ),
        ],
      ),
    );
  }

  LineChartData _buildData(
    BuildContext context,
    List<HealthTermRecord> points,
  ) {
    final ColorScheme scheme = Theme.of(context).colorScheme;
    final List<double> values = points
        .map((record) => record.score ?? 0)
        .toList(growable: false);
    final double maxValue = values.reduce(math.max);
    final double maxY = math.max(120, (maxValue * 1.12).ceilToDouble());
    const double minY = 0;
    final double interval = maxY / 6;
    final bool singlePoint = points.length == 1;

    return LineChartData(
      minX: singlePoint ? -0.5 : 0,
      maxX: singlePoint ? 0.5 : (points.length - 1).toDouble(),
      minY: minY,
      maxY: maxY,
      clipData: const FlClipData.none(),
      gridData: FlGridData(
        show: true,
        drawVerticalLine: false,
        horizontalInterval: interval,
        getDrawingHorizontalLine:
            (value) => FlLine(
              color: scheme.outlineVariant.withValues(alpha: 0.4),
              strokeWidth: 1,
              dashArray: const <int>[4, 4],
            ),
      ),
      borderData: FlBorderData(show: false),
      titlesData: FlTitlesData(
        topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
        rightTitles: const AxisTitles(
          sideTitles: SideTitles(showTitles: false),
        ),
        leftTitles: AxisTitles(
          sideTitles: SideTitles(
            showTitles: true,
            reservedSize: 34,
            interval: interval,
            getTitlesWidget:
                (value, meta) => SideTitleWidget(
                  meta: meta,
                  space: 6,
                  child: Text(
                    value.round().toString(),
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
              final int index = value.round();
              if (index < 0 || index >= points.length) {
                return const SizedBox.shrink();
              }
              final bool show =
                  points.length <= 4 ||
                  index == 0 ||
                  index == points.length - 1 ||
                  index == points.length ~/ 2;
              if (!show) return const SizedBox.shrink();
              return SideTitleWidget(
                meta: meta,
                space: 6,
                child: Text(
                  _shortLabel(points[index]),
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
              final int index = spot.x.round().clamp(0, points.length - 1);
              final HealthTermRecord record = points[index];
              return LineTooltipItem(
                '${record.label}\n总分 ${formatHealthScore(record.score)}',
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
                    color: _healthAccent.withValues(alpha: 0.35),
                    strokeWidth: 1.5,
                    dashArray: const <int>[4, 4],
                  ),
                  FlDotData(
                    show: true,
                    getDotPainter:
                        (spot, percent, barData, index) => FlDotCirclePainter(
                          radius: 4,
                          color: _healthAccent,
                          strokeWidth: 2,
                          strokeColor: scheme.surface,
                        ),
                  ),
                ),
              )
              .toList();
        },
      ),
      lineBarsData: <LineChartBarData>[
        LineChartBarData(
          spots: List<FlSpot>.generate(
            values.length,
            (index) => FlSpot(index.toDouble(), values[index]),
          ),
          isCurved: true,
          curveSmoothness: 0.18,
          preventCurveOverShooting: true,
          barWidth: 3,
          isStrokeCapRound: true,
          color: _healthAccent,
          dotData: FlDotData(
            show: true,
            getDotPainter:
                (spot, percent, barData, index) => FlDotCirclePainter(
                  radius: 4,
                  color: _healthAccent,
                  strokeWidth: 2,
                  strokeColor: scheme.surface,
                ),
          ),
          belowBarData: BarAreaData(
            show: true,
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: <Color>[
                _healthAccent.withValues(alpha: 0.28),
                _healthAccent.withValues(alpha: 0.02),
              ],
            ),
          ),
        ),
      ],
    );
  }

  /// 2025-2026-1 → 25-26，避免横轴标签互相挤压。
  String _shortLabel(HealthTermRecord record) {
    final RegExpMatch? match = RegExp(
      r'^(\d{4})-(\d{4})',
    ).firstMatch(record.year);
    if (match != null) {
      return '${match.group(1)!.substring(2)}-${match.group(2)!.substring(2)}';
    }
    return record.label;
  }
}
