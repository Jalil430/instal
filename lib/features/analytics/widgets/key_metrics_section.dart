import 'package:flutter/material.dart';
import 'package:instal_app/features/analytics/domain/entities/analytics_data.dart';
import 'package:instal_app/features/analytics/widgets/metric_item.dart';
import 'package:intl/intl.dart';
import '../../../core/localization/app_localizations.dart';
import '../../../core/theme/app_theme.dart';
import '../../../shared/widgets/analytics_card.dart';
import '../../../shared/widgets/responsive_layout.dart';

class KeyMetricsSection extends StatelessWidget {
  final KeyMetricsData data;

  const KeyMetricsSection({super.key, required this.data});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final currencyFormatter =
        NumberFormat.currency(locale: 'ru_RU', symbol: '₽', decimalDigits: 0);

    return AnalyticsCard(
      padding: EdgeInsets.zero,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final isSmallScreen = constraints.maxWidth < 400;
          
          return Column(
            children: [
              Expanded(
                child: Row(
                  children: [
                    Expanded(
                      child: Padding(
                        padding: EdgeInsets.all(isSmallScreen ? 12.0 : 20.0),
                        child: MetricItem(
                          title: l10n.totalRevenue,
                          value: currencyFormatter.format(data.totalRevenue),
                          change: data.totalRevenueChange,
                          isCompact: isSmallScreen,
                        ),
                      ),
                    ),
                    VerticalDivider(width: 1, color: AppTheme.subtleBorderColor),
                    Expanded(
                      child: Padding(
                        padding: EdgeInsets.all(isSmallScreen ? 12.0 : 20.0),
                        child: MetricItem(
                          title: l10n.newInstallments,
                          value: data.newInstallments.toString(),
                          change: data.newInstallmentsChange,
                          isCompact: isSmallScreen,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              Divider(height: 1, color: AppTheme.subtleBorderColor),
              Expanded(
                child: Row(
                  children: [
                    Expanded(
                      child: Padding(
                        padding: EdgeInsets.all(isSmallScreen ? 12.0 : 20.0),
                        child: MetricItem(
                          title: l10n.collectionRate,
                          value: '${data.collectionRate.toStringAsFixed(1)}%',
                          change: data.collectionRateChange,
                          isCompact: isSmallScreen,
                        ),
                      ),
                    ),
                    VerticalDivider(width: 1, color: AppTheme.subtleBorderColor),
                    Expanded(
                      child: Padding(
                        padding: EdgeInsets.all(isSmallScreen ? 12.0 : 20.0),
                        child: MetricItem(
                          title: l10n.portfolioGrowth,
                          value: currencyFormatter.format(data.portfolioGrowth),
                          change: data.portfolioGrowthChange,
                          isCompact: isSmallScreen,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          );
        }
      ),
    );
  }
} 