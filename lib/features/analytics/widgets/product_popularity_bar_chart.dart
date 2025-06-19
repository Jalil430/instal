import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:instal_app/core/theme/app_theme.dart';

class ProductPopularityBarChart extends StatelessWidget {
  final String title;
  final Map<String, int> productPopularity;

  const ProductPopularityBarChart({
    super.key,
    required this.title,
    required this.productPopularity,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 300,
      padding: const EdgeInsets.all(AppTheme.spacingMd),
      decoration: BoxDecoration(
        color: AppTheme.surfaceColor,
        borderRadius: BorderRadius.circular(AppTheme.borderRadiusMedium),
        border: Border.all(color: AppTheme.borderColor),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: AppTheme.spacingMd),
          Expanded(
            child: BarChart(
              BarChartData(
                alignment: BarChartAlignment.spaceAround,
                maxY: _getMaxY(),
                barGroups: _buildBarGroups(),
                titlesData: FlTitlesData(
                  leftTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  bottomTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      getTitlesWidget: (value, meta) {
                        final index = value.toInt();
                        if (index >= 0 && index < productPopularity.keys.length) {
                          return SideTitleWidget(
                            axisSide: meta.axisSide,
                            child: Text(
                              productPopularity.keys.elementAt(index),
                              style: const TextStyle(fontSize: 10),
                            ),
                          );
                        }
                        return const SizedBox();
                      },
                      reservedSize: 30,
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  double _getMaxY() {
    if (productPopularity.isEmpty) return 0;
    return productPopularity.values.reduce((a, b) => a > b ? a : b).toDouble() + 2;
  }

  List<BarChartGroupData> _buildBarGroups() {
    final entries = productPopularity.entries.toList();
    return List.generate(entries.length, (index) {
      final entry = entries[index];
      return BarChartGroupData(
        x: index,
        barRods: [
          BarChartRodData(
            toY: entry.value.toDouble(),
            color: Colors.amber,
            width: 16,
          ),
        ],
      );
    });
  }
} 