import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:instal_app/core/theme/app_theme.dart';

class InstallmentStatusPieChart extends StatelessWidget {
  final String title;
  final int active;
  final int completed;
  final int overdue;

  const InstallmentStatusPieChart({
    super.key,
    required this.title,
    required this.active,
    required this.completed,
    required this.overdue,
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
            child: PieChart(
              PieChartData(
                sections: _buildSections(),
                centerSpaceRadius: 40,
                sectionsSpace: 2,
              ),
            ),
          ),
        ],
      ),
    );
  }

  List<PieChartSectionData> _buildSections() {
    return [
      PieChartSectionData(
        color: Colors.purple,
        value: active.toDouble(),
        title: '$active',
        radius: 50,
        titleStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white),
      ),
      PieChartSectionData(
        color: Colors.teal,
        value: completed.toDouble(),
        title: '$completed',
        radius: 50,
        titleStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white),
      ),
      PieChartSectionData(
        color: Colors.red,
        value: overdue.toDouble(),
        title: '$overdue',
        radius: 50,
        titleStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white),
      ),
    ];
  }
} 