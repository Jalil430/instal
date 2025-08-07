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
      child: LayoutBuilder(
        builder: (context, constraints) {
          final isSmallScreen = constraints.maxWidth < 400;
          
          return isSmallScreen
              ? _buildMobileLayout(statusData, centerPercentage, centerLabel, centerColor, l10n)
              : _buildDesktopLayout(statusData, centerPercentage, centerLabel, centerColor, l10n);
        }
      ),
    );
  }
  
  Widget _buildDesktopLayout(
      List<Map<String, dynamic>> statusData,
      int centerPercentage,
      String centerLabel,
      Color centerColor,
      AppLocalizations l10n) {
    return Row(
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
              _buildPieChart(statusData, 60, 30.0),
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
    );
  }
  
  Widget _buildMobileLayout(
      List<Map<String, dynamic>> statusData,
      int centerPercentage,
      String centerLabel,
      Color centerColor,
      AppLocalizations l10n) {
    return Column(
      children: [
        // Pie chart at the top
        Expanded(
          flex: 1,
          child: Stack(
            alignment: Alignment.center,
            children: [
              _buildPieChart(statusData, 45, 30.0),
              Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    '$centerPercentage%',
                    style: TextStyle(
                      fontSize: 15,
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
                      fontSize: 10,
                      color: AppTheme.textSecondary,
                    ),
                  ),
                ],
              )
            ],
          ),
        ),
        
        // Status indicators at the bottom in a row
        Padding(
          padding: const EdgeInsets.only(top: 8.0, left: 8.0, right: 8.0),
          child: Row(
            children: [
              // First column: first two status indicators
              Expanded(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    StatusIndicator(
                      color: statusData[0]['color'] as Color,
                      text: '${statusData[0]['status']} (${(statusData[0]['value'] as double).toInt()}%)',
                      countText: l10n.installmentsCount(statusData[0]['count'] as int),
                      isCompact: true,
                    ),
                    StatusIndicator(
                      color: statusData[1]['color'] as Color,
                      text: '${statusData[1]['status']} (${(statusData[1]['value'] as double).toInt()}%)',
                      countText: l10n.installmentsCount(statusData[1]['count'] as int),
                      isCompact: true,
                    ),
                  ],
                ),
              ),
              // Second column: second two status indicators
              Expanded(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    StatusIndicator(
                      color: statusData[2]['color'] as Color,
                      text: '${statusData[2]['status']} (${(statusData[2]['value'] as double).toInt()}%)',
                      countText: l10n.installmentsCount(statusData[2]['count'] as int),
                      isCompact: true,
                    ),
                    StatusIndicator(
                      color: statusData[3]['color'] as Color,
                      text: '${statusData[3]['status']} (${(statusData[3]['value'] as double).toInt()}%)',
                      countText: l10n.installmentsCount(statusData[3]['count'] as int),
                      isCompact: true,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
  
  Widget _buildPieChart(List<Map<String, dynamic>> statusData, double centerSpaceRadius, double radius) {
    // Check if there's any non-zero data
    bool hasData = statusData.any((data) => (data['value'] as double) > 0);
    
    // If no data, show a placeholder circle
    if (!hasData) {
      return Container(
        width: centerSpaceRadius * 2 + radius * 2,
        height: centerSpaceRadius * 2 + radius * 2,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: AppTheme.subtleBorderColor.withOpacity(0.3),
        ),
        child: Center(
          child: Text(
            'Нет данных',
            style: TextStyle(
              color: AppTheme.textSecondary,
              fontSize: 14,
            ),
          ),
        ),
      );
    }
    
    return PieChart(
      PieChartData(
        sectionsSpace: 0,
        centerSpaceRadius: centerSpaceRadius,
        sections: List.generate(statusData.length, (i) {
          final data = statusData[i];
          final value = data['value'] as double;
          
          // Skip sections with zero value
          if (value <= 0) {
            return PieChartSectionData(
              color: Colors.transparent,
              value: 0,
              title: '',
              radius: 0,
              showTitle: false,
            );
          }
          
          return PieChartSectionData(
            color: data['color'] as Color,
            value: value,
            title: '',
            radius: radius,
          );
        }),
      ),
    );
  }
} 