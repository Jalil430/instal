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

class AnalyticsScreenDesktop extends StatelessWidget {
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

  const AnalyticsScreenDesktop({
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

    return Scaffold(
      backgroundColor: AppTheme.surfaceColor,
      body: Column(
        children: [
          // Header
          Container(
            padding: const EdgeInsets.fromLTRB(32, 28, 32, 20),
            decoration: const BoxDecoration(color: AppTheme.surfaceColor),
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
                SizedBox(width: 260, child: _buildWalletDropdown(l10n)),
                const SizedBox(width: 16),
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
              child: _buildDesktopLayout(l10n),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDesktopLayout(AppLocalizations l10n) {
    return Scrollbar(
      thumbVisibility: true,
      child: SingleChildScrollView(
        padding: const EdgeInsets.only(bottom: 16),
        child: Column(
          children: [
            SizedBox(
              height: 360,
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Expanded(
                    child: TotalSalesSection(data: analyticsData.totalSales),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: KeyMetricsSection(data: analyticsData.keyMetrics),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            SizedBox(
              height: 320,
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Expanded(
                    child: InstallmentDetailsSection(
                      data: installmentDetailsData,
                      walletLabel: _currentWalletLabel(l10n),
                      isLoading: isWalletDataLoading,
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: InstallmentStatusSection(
                      data: analyticsData.installmentStatus,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            SizedBox(
              height: 520,
              child: ProfitAnalyticsSection(
                data: profitAnalyticsData,
                walletLabel: _currentWalletLabel(l10n),
                isLoading: isWalletDataLoading,
              ),
            ),
          ],
        ),
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
