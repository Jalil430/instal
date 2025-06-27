import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:instal_app/features/analytics/domain/entities/analytics_data.dart';
import 'package:instal_app/features/analytics/widgets/status_indicator.dart';
import '../../../core/theme/app_theme.dart';
import '../../../shared/widgets/analytics_card.dart';
import '../../../core/localization/app_localizations.dart';

class InstallmentStatusSection extends StatelessWidget {
  final InstallmentStatusData data;

  const InstallmentStatusSection({super.key, required this.data});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final total = data.overdueCount + data.dueToPayCount + data.upcomingCount + data.paidCount;

    final statusData = [
      {
        'status': l10n.overdue,
        'value': total > 0 ? (data.overdueCount / total) * 100 : 0.0,
        'count': data.overdueCount,
        'color': AppTheme.errorColor
      },
      {
        'status': l10n.dueToPay,
        'value': total > 0 ? (data.dueToPayCount / total) * 100 : 0.0,
        'count': data.dueToPayCount,
        'color': AppTheme.warningColor
      },
      {
        'status': l10n.upcoming,
        'value': total > 0 ? (data.upcomingCount / total) * 100 : 0.0,
        'count': data.upcomingCount,
        'color': AppTheme.pendingColor
      },
      {
        'status': l10n.paid,
        'value': total > 0 ? (data.paidCount / total) * 100 : 0.0,
        'count': data.paidCount,
        'color': AppTheme.successColor
      },
    ];

    final dataForCenter = statusData.firstWhere(
      (d) => (d['count'] as int) > 0,
      orElse: () => statusData.last,
    );
    final centerPercentage = (dataForCenter['value'] as double).toInt();
    final centerLabel = dataForCenter['status'] as String;
    final centerColor = dataForCenter['color'] as Color;

    return AnalyticsCard(
      title: l10n.installmentStatus,
      child: Row(
        children: [
          Expanded(
            flex: 1,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: statusData.map((data) {
                final count = data['count'] as int;
                return StatusIndicator(
                  color: data['color'] as Color,
                  text:
                      '${data['status']} (${(data['value'] as double).toInt()}%)',
                  countText: l10n.installmentsCount(count),
                );
              }).toList(),
            ),
          ),
          Expanded(
            flex: 2,
            child: Stack(
              alignment: Alignment.center,
              children: [
                PieChart(
                  PieChartData(
                    sectionsSpace: 0,
                    centerSpaceRadius: 60,
                    sections: List.generate(statusData.length, (i) {
                      final data = statusData[i];
                      return PieChartSectionData(
                        color: data['color'] as Color,
                        value: data['value'] as double,
                        title: '',
                        radius: 30.0,
                      );
                    }),
                  ),
                ),
                Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      '$centerPercentage%',
                      style: TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.w600,
                        color: centerColor,
                        shadows: [
                          BoxShadow(
                            color: centerColor.withOpacity(0.2),
                            blurRadius: 4,
                          ),
                        ],
                      ),
                    ),
                    Text(
                      centerLabel,
                      style: const TextStyle(
                        fontSize: 13,
                        color: AppTheme.textSecondary,
                      ),
                    ),
                  ],
                )
              ],
            ),
          ),
        ],
      ),
    );
  }
} 