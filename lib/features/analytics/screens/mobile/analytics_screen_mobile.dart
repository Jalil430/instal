import 'package:flutter/material.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/localization/app_localizations.dart';
import '../../../../shared/widgets/custom_icon_button.dart';
import '../../domain/entities/analytics_data.dart';
import '../../widgets/total_sales_section.dart';
import '../../widgets/key_metrics_section.dart';
import '../../widgets/installment_details_section.dart';
import '../../widgets/installment_status_section.dart';
import '../../widgets/profit_analytics_section.dart';
import '../../../wallets/domain/entities/wallet.dart';

class AnalyticsScreenMobile extends StatelessWidget {
  final AnalyticsData analyticsData;
  final bool isRefreshing;
  final VoidCallback refreshAnalytics;
  final List<Wallet> wallets;
  final bool isWalletsLoading;
  final String? selectedWalletId;
  final ValueChanged<String?> onWalletSelected;
  final ProfitAnalyticsData profitAnalyticsData;
  final InstallmentDetailsData installmentDetailsData;
  final bool isWalletDataLoading;

  const AnalyticsScreenMobile({
    Key? key,
    required this.analyticsData,
    required this.isRefreshing,
    required this.refreshAnalytics,
    required this.wallets,
    required this.isWalletsLoading,
    required this.selectedWalletId,
    required this.onWalletSelected,
    required this.profitAnalyticsData,
    required this.installmentDetailsData,
    required this.isWalletDataLoading,
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
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
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
                const SizedBox(height: 12),
                _buildWalletDropdown(l10n),
              ],
            ),
          ),

          // Main Content
          Expanded(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
              child: _buildMobileLayout(l10n),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMobileLayout(AppLocalizations l10n) {
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
            child: InstallmentDetailsSection(
              data: installmentDetailsData,
              walletLabel: _currentWalletLabel(l10n),
              isLoading: isWalletDataLoading,
            ),
          ),
          const SizedBox(height: 16),
          SizedBox(
            height: 300, // Fixed height for the status chart
            child: InstallmentStatusSection(
              data: analyticsData.installmentStatus,
            ),
          ),
          const SizedBox(height: 16),
          SizedBox(
            height: 500,
            child: ProfitAnalyticsSection(
              data: profitAnalyticsData,
              walletLabel: _currentWalletLabel(l10n),
              isLoading: isWalletDataLoading,
            ),
          ),
          // Add padding at the bottom to ensure content isn't hidden behind bottom nav bar
          SizedBox(height: 16),
        ],
      ),
    );
  }

  Widget _buildWalletDropdown(AppLocalizations l10n) {
    if (isWalletsLoading) {
      return Container(
        height: 52,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppTheme.subtleBorderColor),
          color: AppTheme.subtleBackgroundColor,
        ),
        child: Row(
          children: [
            const SizedBox(
              width: 18,
              height: 18,
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                l10n.loadingWallets,
                style: const TextStyle(color: AppTheme.textSecondary),
              ),
            ),
          ],
        ),
      );
    }

    final dropdownItems = <DropdownMenuItem<String?>>[
      DropdownMenuItem(value: null, child: Text(l10n.allWallets)),
      ...wallets.map(
        (wallet) =>
            DropdownMenuItem(value: wallet.id, child: Text(wallet.name)),
      ),
    ];

    return DropdownButtonFormField<String?>(
      value: selectedWalletId,
      items: dropdownItems,
      onChanged: onWalletSelected,
      decoration: InputDecoration(
        labelText: l10n.wallet,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 12,
          vertical: 10,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: AppTheme.subtleBorderColor),
        ),
      ),
    );
  }

  String _currentWalletLabel(AppLocalizations l10n) {
    if (selectedWalletId == null) {
      return l10n.allWallets;
    }
    for (final wallet in wallets) {
      if (wallet.id == selectedWalletId) {
        return wallet.name;
      }
    }
    return l10n.allWallets;
  }
}
