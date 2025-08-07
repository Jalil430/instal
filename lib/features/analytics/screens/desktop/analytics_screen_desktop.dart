import 'package:flutter/material.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/localization/app_localizations.dart';
import '../../../../shared/widgets/custom_icon_button.dart';
import '../../domain/entities/analytics_data.dart';
import '../../widgets/total_sales_section.dart';
import '../../widgets/key_metrics_section.dart';
import '../../widgets/installment_details_section.dart';
import '../../widgets/installment_status_section.dart';

class AnalyticsScreenDesktop extends StatelessWidget {
  final AnalyticsData analyticsData;
  final bool isRefreshing;
  final VoidCallback refreshAnalytics;

  const AnalyticsScreenDesktop({
    Key? key,
    required this.analyticsData,
    required this.isRefreshing,
    required this.refreshAnalytics,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;

    return Scaffold(
      backgroundColor: AppTheme.surfaceColor,
      body: Column(
        children: [
          // Header
          Container(
            padding: const EdgeInsets.fromLTRB(32, 28, 32, 20),
            decoration: const BoxDecoration(
              color: AppTheme.surfaceColor,
            ),
            child: Row(
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      l10n.analytics,
                      style: const TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w600,
                        letterSpacing: -0.5,
                      ),
                    ),
                  ],
                ),
                const Spacer(),
                // Refresh button
                CustomIconButton(
                  icon: Icons.refresh_rounded,
                  onPressed: refreshAnalytics,
                  size: 36,
                  animate: isRefreshing,
                  rotation: isRefreshing ? 1.0 : 0.0,
                  animationDuration: const Duration(milliseconds: 1000),
                  interactive: !isRefreshing,
                ),
              ],
            ),
          ),

          // Main Content
          Expanded(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
              child: _buildDesktopLayout(),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDesktopLayout() {
    return Column(
      children: [
        Expanded(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Expanded(child: TotalSalesSection(data: analyticsData.totalSales)),
              const SizedBox(width: 16),
              Expanded(child: KeyMetricsSection(data: analyticsData.keyMetrics)),
            ],
          ),
        ),
        const SizedBox(height: 16),
        Expanded(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Expanded(child: InstallmentDetailsSection(data: analyticsData.installmentDetails)),
              const SizedBox(width: 16),
              Expanded(child: InstallmentStatusSection(data: analyticsData.installmentStatus)),
            ],
          ),
        ),
      ],
    );
  }
} 