import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/localization/app_localizations.dart';
import '../../../shared/widgets/custom_contextual_dialog.dart';
import '../../../shared/widgets/custom_button.dart';
import '../domain/entities/wallet.dart';

class AddMoneyDialog {
  static Future<void> show({
    required BuildContext context,
    required Wallet wallet,
    required NumberFormat currencyFormat,
    required Function(double) onConfirm,
    Offset? position,
  }) async {
    // Calculate top-right position with margin from corner if none provided
    final screenSize = MediaQuery.of(context).size;
    final topRightPosition = position ?? Offset(
      screenSize.width - 450, // Leave space for dialog width + margin
      80, // Big space from top
    );

    await CustomContextualDialog.show(
      context: context,
      position: topRightPosition,
      child: _AddMoneyContent(
        wallet: wallet,
        currencyFormat: currencyFormat,
        onConfirm: onConfirm,
      ),
      width: 400,
      estimatedHeight: 300,
    );
  }
}

class _AddMoneyContent extends ContextualDialogContent {
  final Wallet wallet;
  final NumberFormat currencyFormat;
  final Function(double) onConfirm;

  const _AddMoneyContent({
    super.key,
    required this.wallet,
    required this.currencyFormat,
    required this.onConfirm,
  });

  @override
  Widget buildContent(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final TextEditingController amountController = TextEditingController();
    final FocusNode amountFocusNode = FocusNode();

    return Container(
      width: 400,
      padding: const EdgeInsets.all(20),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Row(
            children: [
              Icon(
                Icons.add_circle,
                color: AppTheme.successColor,
                size: 24,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  l10n?.addMoney ?? 'Add Money to Wallet',
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                    color: AppTheme.textPrimary,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),

          // Wallet Info
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppTheme.surfaceColor,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: AppTheme.borderColor),
            ),
            child: Row(
              children: [
                Icon(
                  wallet.isPersonalWallet ? Icons.account_balance_wallet : Icons.trending_up,
                  color: wallet.isPersonalWallet ? AppTheme.primaryColor : AppTheme.successColor,
                  size: 20,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        wallet.name,
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                          color: AppTheme.textPrimary,
                        ),
                      ),
                      Text(
                        wallet.isPersonalWallet
                            ? (l10n?.personalWallet ?? 'Personal Wallet')
                            : (l10n?.investorWallet ?? 'Investor Wallet'),
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
          ),
          const SizedBox(height: 20),

          // Amount Input
          Text(
            l10n?.amount ?? 'Amount',
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w500,
              color: AppTheme.textPrimary,
            ),
          ),
          const SizedBox(height: 8),
          TextField(
            controller: amountController,
            focusNode: amountFocusNode,
            keyboardType: TextInputType.numberWithOptions(decimal: true),
            inputFormatters: [
              FilteringTextInputFormatter.allow(RegExp(r'^\d+\.?\d{0,2}')),
            ],
            decoration: InputDecoration(
              hintText: l10n?.enterAmount ?? 'Enter amount',
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: BorderSide(color: AppTheme.borderColor),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: BorderSide(color: AppTheme.primaryColor),
              ),
              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            ),
            onSubmitted: (value) {
              if (value.isNotEmpty) {
                final amount = double.tryParse(value);
                if (amount != null && amount > 0) {
                  onConfirm(amount);
                  Navigator.of(context).pop();
                }
              }
            },
          ),
          const SizedBox(height: 24),

          // Buttons
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              CustomButton(
                text: l10n?.cancel ?? 'Cancel',
                onPressed: () => Navigator.of(context).pop(),
                color: AppTheme.surfaceColor,
                textColor: AppTheme.textSecondary,
                showIcon: false,
                width: 120,
              ),
              const SizedBox(width: 12),
              CustomButton(
                text: l10n?.add ?? 'Add',
                onPressed: () {
                  final amount = double.tryParse(amountController.text);
                  if (amount != null && amount > 0) {
                    onConfirm(amount);
                    Navigator.of(context).pop();
                  }
                },
                icon: Icons.add_circle,
                color: AppTheme.successColor,
                width: 140,
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class WithdrawMoneyDialog {
  static Future<void> show({
    required BuildContext context,
    required Wallet wallet,
    required double currentBalance,
    required NumberFormat currencyFormat,
    required Function(double) onConfirm,
    Offset? position,
  }) async {
    // Calculate top-right position with margin from corner if none provided
    final screenSize = MediaQuery.of(context).size;
    final topRightPosition = position ?? Offset(
      screenSize.width - 450, // Leave space for dialog width + margin
      80, // Big space from top
    );

    await CustomContextualDialog.show(
      context: context,
      position: topRightPosition,
      child: _WithdrawMoneyContent(
        wallet: wallet,
        currentBalance: currentBalance,
        currencyFormat: currencyFormat,
        onConfirm: onConfirm,
      ),
      width: 400,
      estimatedHeight: 320,
    );
  }
}

class _WithdrawMoneyContent extends ContextualDialogContent {
  final Wallet wallet;
  final double currentBalance;
  final NumberFormat currencyFormat;
  final Function(double) onConfirm;

  const _WithdrawMoneyContent({
    super.key,
    required this.wallet,
    required this.currentBalance,
    required this.currencyFormat,
    required this.onConfirm,
  });

  @override
  Widget buildContent(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final TextEditingController amountController = TextEditingController();
    final FocusNode amountFocusNode = FocusNode();

    return Container(
      width: 400,
      padding: const EdgeInsets.all(20),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Row(
            children: [
              Icon(
                Icons.remove_circle,
                color: AppTheme.warningColor,
                size: 24,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  l10n?.withdrawMoney ?? 'Withdraw Money from Wallet',
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                    color: AppTheme.textPrimary,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),

          // Wallet Info with Balance
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppTheme.surfaceColor,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: AppTheme.borderColor),
            ),
            child: Row(
              children: [
                Icon(
                  wallet.isPersonalWallet ? Icons.account_balance_wallet : Icons.trending_up,
                  color: wallet.isPersonalWallet ? AppTheme.primaryColor : AppTheme.successColor,
                  size: 20,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        wallet.name,
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                          color: AppTheme.textPrimary,
                        ),
                      ),
                      Text(
                        wallet.isPersonalWallet
                            ? (l10n?.personalWallet ?? 'Personal Wallet')
                            : (l10n?.investorWallet ?? 'Investor Wallet'),
                        style: TextStyle(
                          fontSize: 12,
                          color: AppTheme.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
                Text(
                  currencyFormat.format(currentBalance),
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: AppTheme.textPrimary,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),

          // Amount Input
          Text(
            l10n?.amount ?? 'Amount',
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w500,
              color: AppTheme.textPrimary,
            ),
          ),
          const SizedBox(height: 8),
          TextField(
            controller: amountController,
            focusNode: amountFocusNode,
            keyboardType: TextInputType.numberWithOptions(decimal: true),
            inputFormatters: [
              FilteringTextInputFormatter.allow(RegExp(r'^\d+\.?\d{0,2}')),
            ],
            decoration: InputDecoration(
              hintText: l10n?.enterAmount ?? 'Enter amount',
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: BorderSide(color: AppTheme.borderColor),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: BorderSide(color: AppTheme.primaryColor),
              ),
              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            ),
            onSubmitted: (value) {
              if (value.isNotEmpty) {
                final amount = double.tryParse(value);
                if (amount != null && amount > 0 && amount <= currentBalance) {
                  onConfirm(amount);
                  Navigator.of(context).pop();
                }
              }
            },
          ),
          const SizedBox(height: 8),
          Text(
            '${l10n?.available ?? 'Available'}: ${currencyFormat.format(currentBalance)}',
            style: TextStyle(
              fontSize: 12,
              color: AppTheme.textSecondary,
            ),
          ),
          const SizedBox(height: 24),

          // Buttons
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              CustomButton(
                text: l10n?.cancel ?? 'Cancel',
                onPressed: () => Navigator.of(context).pop(),
                color: AppTheme.surfaceColor,
                textColor: AppTheme.textSecondary,
                showIcon: false,
                width: 100,
              ),
              const SizedBox(width: 12),
              CustomButton(
                text: l10n?.withdraw ?? 'Withdraw',
                onPressed: () {
                  final amount = double.tryParse(amountController.text);
                  if (amount != null && amount > 0 && amount <= currentBalance) {
                    onConfirm(amount);
                    Navigator.of(context).pop();
                  }
                },
                icon: Icons.remove_circle,
                color: AppTheme.warningColor,
                width: 120,
              ),
            ],
          ),
        ],
      ),
    );
  }
}
