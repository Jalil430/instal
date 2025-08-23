import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/localization/app_localizations.dart';
import '../domain/entities/wallet.dart';
import '../domain/entities/wallet_balance.dart';

class WalletSelectionField extends StatelessWidget {
  final List<Wallet> wallets;
  final Map<String, WalletBalance> walletBalances;
  final Wallet? selectedWallet;
  final ValueChanged<Wallet?> onWalletSelected;
  final VoidCallback? onCreateWallet;
  final bool showLabel;
  final String? label;
  final bool isLoading;

  const WalletSelectionField({
    super.key,
    required this.wallets,
    required this.walletBalances,
    this.selectedWallet,
    required this.onWalletSelected,
    this.onCreateWallet,
    this.showLabel = true,
    this.label,
    this.isLoading = false,
  });

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final currencyFormat = NumberFormat.currency(
      locale: l10n?.locale.languageCode == 'ru' ? 'ru_RU' : 'en_US',
      symbol: l10n?.locale.languageCode == 'ru' ? '₽' : '\$',
      decimalDigits: 2,
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (showLabel)
          Text(
            label ?? l10n?.wallet ?? 'Wallet',
            style: TextStyle(
              color: AppTheme.textSecondary,
              fontSize: 14,
              fontWeight: FontWeight.w400,
            ),
          ),
        const SizedBox(height: 8),
        Container(
          decoration: BoxDecoration(
            border: Border.all(color: AppTheme.borderColor),
            borderRadius: BorderRadius.circular(AppTheme.borderRadiusMedium),
          ),
          child: DropdownButtonFormField<Wallet?>(
            value: selectedWallet,
            decoration: const InputDecoration(
              border: InputBorder.none,
              contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            ),
            hint: Text(l10n?.selectWallet ?? 'Select wallet'),
            items: [
              DropdownMenuItem<Wallet?>(
                value: null,
                child: Text(l10n?.withoutWallet ?? 'Without wallet'),
              ),
              ...wallets.map((wallet) {
                final balance = walletBalances[wallet.id];
                final balanceText = balance != null
                    ? currencyFormat.format(balance.balance)
                    : currencyFormat.format(0);

                return DropdownMenuItem<Wallet?>(
                  value: wallet,
                  child: Row(
                    children: [
                      Icon(
                        wallet.isPersonalWallet
                            ? Icons.account_balance_wallet
                            : Icons.trending_up,
                        size: 20,
                        color: wallet.isPersonalWallet
                            ? AppTheme.primaryColor
                            : AppTheme.successColor,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              wallet.name,
                              style: const TextStyle(fontWeight: FontWeight.w500),
                            ),
                            Text(
                              balanceText,
                              style: TextStyle(
                                fontSize: 12,
                                color: AppTheme.textSecondary,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                );
              }),
            ],
            onChanged: isLoading ? null : onWalletSelected,
            validator: (value) {
              // Optional validation - wallet selection is not required
              return null;
            },
          ),
        ),
        if (onCreateWallet != null)
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: SizedBox(
              width: double.infinity,
              child: TextButton.icon(
                onPressed: isLoading ? null : onCreateWallet,
                icon: const Icon(Icons.add, size: 16),
                label: Text(l10n?.createWallet ?? 'Create wallet'),
                style: TextButton.styleFrom(
                  foregroundColor: AppTheme.primaryColor,
                  padding: const EdgeInsets.symmetric(vertical: 12),
                ),
              ),
            ),
          ),
      ],
    );
  }
}
