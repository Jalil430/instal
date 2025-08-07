import 'package:flutter/material.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/localization/app_localizations.dart';
import '../../../../shared/widgets/custom_icon_button.dart';
import '../../domain/entities/analytics_data.dart';
import '../../widgets/total_sales_section.dart';
import '../../widgets/key_metrics_section.dart';
import '../../widgets/installment_details_section.dart';
import '../../widgets/installment_status_section.dart';

class AnalyticsScreenMobile extends StatelessWidget {
  final AnalyticsData analyticsData;
  final bool isRefreshing;
  final VoidCallback refreshAnalytics;

  const AnalyticsScreenMobile({
    Key? key,
    required this.analyticsData,
    required this.isRefreshing,
    required this.refreshAnalytics,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final mediaQuery = MediaQuery.of(context);
    final statusBarHeight = mediaQuery.padding.top;

    return Scaffold(
      backgroundColor: AppTheme.surfaceColor,
      body: Column(
        children: [
          // Header with safe area for status bar
          Container(
            padding: EdgeInsets.fromLTRB(16, statusBarHeight + 16, 16, 16),
            decoration: const BoxDecoration(
              color: AppTheme.surfaceColor,
              boxShadow: [
                BoxShadow(
                  color: Color(0x0D000000),
                  blurRadius: 4,
                  offset: Offset(0, 2),
                ),
              ],
            ),
            child: Row(
              children: [
                Text(
                  l10n.analytics,
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w600,
                    letterSpacing: -0.5,
                  ),
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
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
              child: _buildMobileLayout(),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMobileLayout() {
    return SingleChildScrollView(
      child: Column(
        children: [
          SizedBox(
            height: 300, // Fixed height for the chart
            child: TotalSalesSection(data: analyticsData.totalSales),
          ),
          const SizedBox(height: 16),
          SizedBox(
            height: 250, // Smaller height for metrics
            child: KeyMetricsSection(data: analyticsData.keyMetrics),
          ),
          const SizedBox(height: 16),
          SizedBox(
            height: 250, // Smaller height for details
            child: InstallmentDetailsSection(data: analyticsData.installmentDetails),
          ),
          const SizedBox(height: 16),
          SizedBox(
            height: 300, // Fixed height for the status chart
            child: InstallmentStatusSection(data: analyticsData.installmentStatus),
          ),
          // Add padding at the bottom to ensure content isn't hidden behind bottom nav bar
          SizedBox(height: 16),
        ],
      ),
    );
  }
} 