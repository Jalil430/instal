import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';

import '../../../core/localization/app_localizations.dart';
import '../../../core/theme/app_theme.dart';

class MetricItem extends StatelessWidget {
  final String title;
  final String value;
  final double? change;
  final bool higherIsBetter;
  final List<FlSpot> chartData;

  const MetricItem({
    super.key,
    required this.title,
    required this.value,
    this.change,
    this.higherIsBetter = true,
    required this.chartData,
  });

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    
    final hasChange = change != null;

    bool isGood;
    if (hasChange) {
      if (higherIsBetter) {
        isGood = change! >= 0;
      } else {
        isGood = change! <= 0;
      }
    } else {
      isGood = higherIsBetter;
    }

    final changeText = hasChange ? '${change!.abs().toStringAsFixed(1)}%' : '— %';
    final color = isGood ? AppTheme.successColor : AppTheme.errorColor;

    return Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.center,
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
                  if (hasChange)
                    Icon(
                      change! >= 0 ? Icons.arrow_upward : Icons.arrow_downward,
                      color: color,
                      size: 14,
                    ),
                  if (hasChange) const SizedBox(width: 4),
                  Text(
                    changeText,
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w400,
                      color: hasChange ? color : AppTheme.textSecondary,
                    ),
                  ),
                  if (hasChange) const SizedBox(width: 4),
                  Flexible(
                    child: Text(
                      l10n.vsPreview28days,
                      style: const TextStyle(
                        fontSize: 11,
                        color: AppTheme.textSecondary,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        SizedBox(
          width: 80,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              if (chartData.isNotEmpty)
                SizedBox(
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
                          belowBarData: BarAreaData(
                            show: true,
                            gradient: LinearGradient(
                              colors: [
                                color.withOpacity(0.3),
                                color.withOpacity(0.0),
                              ],
                              stops: const [0.5, 1.0],
                              begin: Alignment.topCenter,
                              end: Alignment.bottomCenter,
                            ),
                          ),
                          shadow: Shadow(
                            blurRadius: 8,
                            color: color.withOpacity(0.3),
                          ),
                        ),
                      ],
                      minY: 0,
                      maxY: 10,
                    ),
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }
} 