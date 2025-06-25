import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import '../../../core/theme/app_theme.dart';
import '../../../shared/widgets/analytics_card.dart';
import '../../../core/localization/app_localizations.dart';

class InstallmentStatusSection extends StatefulWidget {
  const InstallmentStatusSection({super.key});

  @override
  State<InstallmentStatusSection> createState() =>
      _InstallmentStatusSectionState();
}

class _InstallmentStatusSectionState extends State<InstallmentStatusSection> {
  int? _touchedIndex;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    // Data is now ordered by urgency for the legend.
    final statusData = [
      {
        'status': l10n.overdue,
        'value': 15.0,
        'count': 40,
        'color': AppTheme.errorColor
      },
      {
        'status': l10n.dueToPay,
        'value': 10.0,
        'count': 25,
        'color': AppTheme.warningColor
      },
      {
        'status': l10n.upcoming,
        'value': 30.0,
        'count': 80,
        'color': AppTheme.pendingColor
      },
      {
        'status': l10n.paid,
        'value': 45.0,
        'count': 120,
        'color': AppTheme.successColor
      },
    ];

    // Find the most urgent status with active installments to display in the center.
    final dataForCenter = statusData.firstWhere(
      (d) => (d['count'] as int) > 0,
      orElse: () => statusData.last, // Default to 'paid' if all else is 0.
    );
    final centerPercentage = (dataForCenter['value'] as double).toInt();
    final centerLabel = dataForCenter['status'] as String;
    final centerColor = dataForCenter['color'] as Color;

    return AnalyticsCard(
      title: l10n.installmentStatus,
      child: Row(
        children: [
          // Legend
          Expanded(
            flex: 1,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: statusData.map((data) {
                final count = data['count'] as int;
                return _StatusIndicator(
                  color: data['color'] as Color,
                  text:
                      '${data['status']} (${(data['value'] as double).toInt()}%)',
                  countText: l10n.installmentsCount(count),
                );
              }).toList(),
            ),
          ),
          // Donut Chart
          Expanded(
            flex: 2,
            child: Stack(
              alignment: Alignment.center,
              children: [
                PieChart(
                  PieChartData(
                    pieTouchData: PieTouchData(
                      touchCallback: (FlTouchEvent event, pieTouchResponse) {
                        setState(() {
                          if (!event.isInterestedForInteractions ||
                              pieTouchResponse == null ||
                              pieTouchResponse.touchedSection == null) {
                            _touchedIndex = -1;
                            return;
                          }
                          _touchedIndex = pieTouchResponse
                              .touchedSection!.touchedSectionIndex;
                        });
                      },
                    ),
                    sectionsSpace: 0,
                    centerSpaceRadius: 60,
                    sections: List.generate(statusData.length, (i) {
                      final isTouched = i == _touchedIndex;
                      final radius = isTouched ? 35.0 : 30.0;
                      final data = statusData[i];
                      return PieChartSectionData(
                        color: data['color'] as Color,
                        value: data['value'] as double,
                        title: '',
                        radius: radius,
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

class _StatusIndicator extends StatelessWidget {
  final Color color;
  final String text;
  final String countText;

  const _StatusIndicator({
    required this.color,
    required this.text,
    required this.countText,
  });

  @override
  Widget build(BuildContext context) {
    final statusText = text.substring(0, text.indexOf('(') - 1);
    final percentageText = text.substring(text.indexOf('('));

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Row(
        children: [
          Container(
            width: 10,
            height: 10,
            decoration: BoxDecoration(
              color: color.withOpacity(0.15),
              shape: BoxShape.circle,
              border: Border.all(
                color: color,
                width: 1.5,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              RichText(
                text: TextSpan(
                  style: const TextStyle(
                    fontSize: 14,
                    color: AppTheme.textPrimary,
                    fontFamily: 'Inter',
                  ),
                  children: [
                    TextSpan(text: '$statusText '),
                    TextSpan(
                      text: percentageText,
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w400,
                        color: color,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 2),
              Text(
                countText,
                style: const TextStyle(
                  fontSize: 12,
                  color: AppTheme.textSecondary,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
} 