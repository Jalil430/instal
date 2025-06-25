import 'dart:math';

import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../../core/localization/app_localizations.dart';
import '../../../core/theme/app_theme.dart';
import '../../../shared/widgets/analytics_card.dart';

class KeyMetricsSection extends StatelessWidget {
  const KeyMetricsSection({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final currencyFormatter = NumberFormat.currency(locale: 'ru_RU', symbol: '₽', decimalDigits: 0);
    final metrics = [
      _MetricItem(
        title: l10n.totalRevenue,
        value: currencyFormatter.format(4562),
        change: '+12%',
        isPositive: true,
        chartData: _generate_chart_data(true),
      ),
      _MetricItem(
        title: l10n.totalVisitors,
        value: currencyFormatter.format(2562),
        change: '+4%',
        isPositive: true,
        chartData: _generate_chart_data(true),
      ),
      _MetricItem(
        title: l10n.totalTransactions,
        value: currencyFormatter.format(2262),
        change: '-0.89%',
        isPositive: false,
        chartData: _generate_chart_data(false),
      ),
      _MetricItem(
        title: l10n.totalProducts,
        value: currencyFormatter.format(2100),
        change: '+2%',
        isPositive: true,
        chartData: _generate_chart_data(true),
      ),
    ];
    return AnalyticsCard(
      padding: EdgeInsets.zero,
      child: Column(
        children: [
          Expanded(
            child: Row(
              children: [
                Expanded(
                    child: Padding(
                  padding: const EdgeInsets.all(20.0),
                  child: metrics[0],
                )),
                VerticalDivider(
                    color: AppTheme.subtleBorderColor, thickness: 1, width: 1),
                Expanded(
                    child: Padding(
                  padding: const EdgeInsets.all(20.0),
                  child: metrics[1],
                )),
              ],
            ),
          ),
          Divider(
              color: AppTheme.subtleBorderColor, thickness: 1, height: 1),
          Expanded(
            child: Row(
              children: [
                Expanded(
                    child: Padding(
                  padding: const EdgeInsets.all(20.0),
                  child: metrics[2],
                )),
                VerticalDivider(
                    color: AppTheme.subtleBorderColor, thickness: 1, width: 1),
                Expanded(
                    child: Padding(
                  padding: const EdgeInsets.all(20.0),
                  child: metrics[3],
                )),
              ],
            ),
          ),
        ],
      ),
    );
  }

  List<FlSpot> _generate_chart_data(bool isPositive) {
    final random = Random();
    final List<double> baseData;

    if (isPositive) {
      baseData = [3, 5, 4, 6, 7];
    } else {
      baseData = [7, 6, 4, 5, 3];
    }

    return List.generate(baseData.length, (index) {
      final y = baseData[index] + random.nextDouble() * 1.5 - 0.75;
      return FlSpot(index.toDouble(), y.clamp(0, 10));
    });
  }
}

class _MetricItem extends StatelessWidget {
  final String title;
  final String value;
  final String change;
  final bool isPositive;
  final List<FlSpot> chartData;

  const _MetricItem({
    required this.title,
    required this.value,
    required this.change,
    required this.isPositive,
    required this.chartData,
  });

  @override
  Widget build(BuildContext context) {
    final color = isPositive ? AppTheme.successColor : AppTheme.errorColor;
    final l10n = AppLocalizations.of(context)!;

    return Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w400,
                  color: AppTheme.textSecondary,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                value,
                style: const TextStyle(
                  fontSize: 27,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 26),
              Row(
                children: [
                  Text(
                    change,
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w400,
                      color: color,
                    ),
                  ),
                  Text(
                    l10n.vsPreview28days,
                    style: const TextStyle(
                      fontSize: 11,
                      color: AppTheme.textSecondary,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        SizedBox(
          width: 80,
          height: 40,
          child: LineChart(
            LineChartData(
              lineTouchData: const LineTouchData(enabled: false),
              gridData: const FlGridData(show: false),
              titlesData: const FlTitlesData(show: false),
              borderData: FlBorderData(show: false),
              lineBarsData: [
                LineChartBarData(
                  spots: chartData,
                  isCurved: true,
                  curveSmoothness: 0.2,
                  color: color,
                  barWidth: 1.5,
                  isStrokeCapRound: true,
                  dotData: const FlDotData(show: false),
                  belowBarData: BarAreaData(show: false),
                  shadow: Shadow(
                    blurRadius: 8,
                    color: color.withOpacity(0.8),
                  ),
                ),
              ],
              minY: 0,
              maxY: 10,
            ),
          ),
        ),
      ],
    );
  }
} 