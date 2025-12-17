import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/localization/app_localizations.dart';
import '../../../../shared/widgets/custom_icon_button.dart';
import '../../../../shared/widgets/custom_dropdown.dart';
import '../../domain/entities/analytics_data.dart';
import '../../widgets/installment_details_section.dart';
import '../../widgets/installment_status_section.dart';
import '../../widgets/profit_analytics_section.dart';
import '../../../wallets/domain/entities/wallet.dart';
import '../../../wallets/domain/entities/wallet_balance.dart';

class AnalyticsScreenDesktop extends StatefulWidget {
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
  final InstallmentStatusData installmentStatusData;
  final Map<String, WalletBalance> walletBalances;

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
    required this.installmentStatusData,
    required this.walletBalances,
  }) : super(key: key);

  @override
  State<AnalyticsScreenDesktop> createState() => _AnalyticsScreenDesktopState();
}

class _AnalyticsScreenDesktopState extends State<AnalyticsScreenDesktop> {
  final ScrollController _scrollController = ScrollController();

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

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
                SizedBox(
                  width: 260,
                  height: 36,
                  child: _buildWalletDropdown(l10n),
                ),
                const SizedBox(width: 16),
                // Refresh button
                CustomIconButton(
                  icon: Icons.refresh_rounded,
                  onPressed: widget.refreshAnalytics,
                  size: 36,
                  animate: widget.isRefreshing,
                  rotation: widget.isRefreshing ? 1.0 : 0.0,
                  animationDuration: const Duration(milliseconds: 1000),
                  interactive: !widget.isRefreshing,
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
      controller: _scrollController,
      child: SingleChildScrollView(
        controller: _scrollController,
        primary: false,
        physics: const RangeMaintainingScrollPhysics(parent: ClampingScrollPhysics()),
        padding: const EdgeInsets.only(bottom: 16),
        child: Column(
          children: [
            SizedBox(
              height: 520,
              child: ProfitAnalyticsSection(
                data: widget.profitAnalyticsData,
                walletLabel: _currentWalletLabel(l10n),
                isLoading: widget.isWalletDataLoading,
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
                      data: widget.installmentDetailsData,
                      walletLabel: _currentWalletLabel(l10n),
                      isLoading: widget.isWalletDataLoading,
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: InstallmentStatusSection(
                      data: widget.installmentStatusData,
                      isLoading: widget.isWalletDataLoading,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildWalletDropdown(AppLocalizations l10n) {
    final currency = NumberFormat.currency(
      locale: l10n.locale.languageCode == 'ru' ? 'ru_RU' : 'en_US',
      symbol: l10n.locale.languageCode == 'ru' ? '₽' : '\$',
      decimalDigits: 2,
    );

    final options = <String, String>{
      'all': l10n.allWallets,
      'noWallet': l10n.withoutWallet,
      ...{
        for (final wallet in widget.wallets)
          wallet.id:
              '${wallet.name} (${currency.format(widget.walletBalances[wallet.id]?.balance ?? 0)})',
      },
    };

    return SizedBox(
      height: 40,
      child: widget.isWalletsLoading
          ? Container(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              decoration: BoxDecoration(
                color: AppTheme.subtleBackgroundColor,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: AppTheme.borderColor),
              ),
              child: Row(
                children: [
                  const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    l10n.loadingWallets,
                    style: const TextStyle(
                      color: AppTheme.textSecondary,
                      fontSize: 14,
                      fontWeight: FontWeight.w400,
                    ),
                  ),
                ],
              ),
            )
          : CustomDropdown<String>(
              value: widget.selectedWalletId ?? 'all',
              items: options,
              onChanged: (value) {
                final v = value ?? 'all';
                if (v == 'all') {
                  widget.onWalletSelected(null);
                } else {
                  widget.onWalletSelected(v);
                }
              },
              hint: l10n.allWallets,
              width: double.infinity,
              height: 40,
            ),
    );
  }

  String _currentWalletLabel(AppLocalizations l10n) {
    if (widget.selectedWalletId == null) {
      return l10n.allWallets;
    }
    for (final wallet in widget.wallets) {
      if (wallet.id == widget.selectedWalletId) {
        return wallet.name;
      }
    }
    return widget.wallets.isNotEmpty ? widget.wallets.first.name : l10n.allWallets;
  }
}
