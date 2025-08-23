import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/localization/app_localizations.dart';
import '../domain/entities/wallet.dart';
import '../domain/entities/wallet_balance.dart';
import '../../../shared/widgets/keyboard_navigable_dropdown.dart';

class WalletSelector extends StatelessWidget {
  final List<Wallet> wallets;
  final Map<String, WalletBalance> walletBalances;
  final Wallet? selectedWallet;
  final bool isLoading;
  final Function(Wallet?) onWalletSelected;
  final VoidCallback? onCreateWallet;
  final GlobalKey<KeyboardNavigableDropdownState<Wallet?>>? dropdownKey;
  final FocusNode? nextFocusNode;

  const WalletSelector({
    super.key,
    required this.wallets,
    required this.walletBalances,
    this.selectedWallet,
    this.isLoading = false,
    required this.onWalletSelected,
    this.onCreateWallet,
    this.dropdownKey,
    this.nextFocusNode,
  });

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final currencyFormat = NumberFormat.currency(
      locale: l10n?.locale.languageCode == 'ru' ? 'ru_RU' : 'en_US',
      symbol: l10n?.locale.languageCode == 'ru' ? '₽' : '\$',
      decimalDigits: 2,
    );

    // Create wallet options with "Without Wallet" option
    final walletOptions = <Wallet?>[
      null, // Represents "Without Wallet"
      ...wallets,
    ];

    if (isLoading) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            l10n?.wallet ?? 'Wallet',
            style: TextStyle(
              color: AppTheme.textSecondary,
              fontSize: 14,
              fontWeight: FontWeight.w400,
            ),
          ),
          const SizedBox(height: 8),
          Container(
            width: double.infinity,
            height: 44,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            decoration: BoxDecoration(
              color: AppTheme.subtleBackgroundColor,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: AppTheme.borderColor),
            ),
            child: Row(
              children: [
                SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    valueColor: AlwaysStoppedAnimation<Color>(AppTheme.primaryColor),
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  'Loading wallets...',
                  style: TextStyle(
                    color: AppTheme.textSecondary,
                    fontSize: 14,
                    fontWeight: FontWeight.w400,
                  ),
                ),
              ],
            ),
          ),
        ],
      );
    }

    return KeyboardNavigableDropdown<Wallet?>(
      key: dropdownKey,
      value: selectedWallet,
      items: walletOptions,
      getDisplayText: (wallet) {
        if (wallet == null) {
          return l10n?.withoutWallet ?? 'Without Wallet';
        }

        final balance = walletBalances[wallet.id];
        final balanceText = balance != null
            ? currencyFormat.format(balance.balance)
            : currencyFormat.format(0);

        return '${wallet.name} ($balanceText)';
      },
      getSearchText: (wallet) => wallet?.name ?? (l10n?.withoutWallet ?? 'Without Wallet'),
      onChanged: onWalletSelected,
      onNext: () {
        nextFocusNode?.requestFocus();
      },
      label: l10n?.wallet ?? 'Wallet',
      hint: '${l10n?.search ?? 'Search'}...',
      noItemsMessage: 'No wallets found',
      onCreateNew: onCreateWallet,
    );
  }
}
