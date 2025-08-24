import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/localization/app_localizations.dart';
import '../../../../shared/widgets/custom_icon_button.dart';
import '../../domain/entities/wallet.dart';
import '../../domain/entities/wallet_balance.dart';
import '../../domain/entities/ledger_transaction.dart';
import '../../domain/entities/investment_summary.dart';
import '../../../../shared/widgets/custom_button.dart';

class WalletDetailsScreenDesktop extends StatelessWidget {
  final Wallet wallet;
  final WalletBalance? balance;
  final List<LedgerTransaction> transactions;
  final InvestmentSummary? investmentSummary;
  final DateFormat dateFormat;
  final NumberFormat currencyFormat;
  final VoidCallback onDelete;

  const WalletDetailsScreenDesktop({
    super.key,
    required this.wallet,
    this.balance,
    required this.transactions,
    this.investmentSummary,
    required this.dateFormat,
    required this.currencyFormat,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);

    return Scaffold(
      backgroundColor: Colors.white,
      body: Column(
        children: [
          // Enhanced Header - matching desktop client details pattern
          Container(
            padding: const EdgeInsets.fromLTRB(32, 28, 32, 20),
            decoration: const BoxDecoration(
              color: AppTheme.surfaceColor,
            ),
            child: Row(
              children: [
                // Back button
                CustomIconButton(
                  routePath: '/wallets',
                ),
                const SizedBox(width: 16),


                Expanded(
                  child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        wallet.name,
                        style: const TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.w600,
                          letterSpacing: -0.5,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        _getWalletTypeText(l10n),
                        style: TextStyle(
                          fontSize: 12,
                          color: AppTheme.textSecondary,
                          fontWeight: FontWeight.w400,
                        ),
                      ),
                    ],
                  ),
                ),



                // Action buttons
                CustomIconButton(
                  icon: Icons.delete_outline,
                  onPressed: onDelete,
                  hoverBackgroundColor: AppTheme.errorColor.withOpacity(0.1),
                  hoverIconColor: AppTheme.errorColor,
                  hoverBorderColor: AppTheme.errorColor.withOpacity(0.3),
                ),
              ],
            ),
          ),

          // Main content
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Financial Summary Table
                  _buildFinancialSummaryTable(context),

                  const SizedBox(height: 20),

                  // Investment details (for investor wallets)
                  if (wallet.isInvestorWallet && investmentSummary != null) ...[
                    _buildInvestmentDetails(context),
                    const SizedBox(height: 20),
                  ],

                  // Transactions
                  _buildTransactionsList(),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFinancialSummaryTable(BuildContext context) {
    final l10n = AppLocalizations.of(context);

    // Calculate key metrics
    final currentBalance = balance?.balance ?? 0;
    final initialInvestment = investmentSummary?.totalInvested ?? wallet.investmentAmount ?? 0;
    final totalAllocated = investmentSummary?.totalAllocated ?? 0;
    final expectedReturns = investmentSummary?.expectedReturns ?? 0;
    final dueAmount = investmentSummary?.dueAmount ?? 0;

    final totalWalletValue = currentBalance + expectedReturns;
    final totalProfit = totalWalletValue - initialInvestment;
    final roi = initialInvestment > 0 ? (totalProfit / initialInvestment) * 100 : 0;

    return Container(
      decoration: BoxDecoration(
        color: AppTheme.surfaceColor,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppTheme.borderColor),
      ),
      child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: AppTheme.subtleBackgroundColor,
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(11),
                topRight: Radius.circular(11),
              ),
              border: Border(
                bottom: BorderSide(color: AppTheme.subtleBorderColor),
              ),
            ),
            child: Row(
              children: [
                Text(
                  l10n?.walletDetails ?? 'Детали кошелька',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: AppTheme.textPrimary,
                  ),
                ),
                const Spacer(),
              ],
            ),
          ),

          // Table Content
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Column(
              children: [
                // Row 1: Initial Investment vs Current Balance
                Row(
                  children: [
                    Expanded(
                      child: _buildSummaryCell(
                        'Первоначальная инвестиция',
                        initialInvestment > 0 ? currencyFormat.format(initialInvestment) : '—',
                        Icons.account_balance,
                        AppTheme.primaryColor,
                      ),
                    ),
                    Container(
                      width: 1,
                      height: 60,
                      color: AppTheme.borderColor,
                    ),
                    Expanded(
                      child: _buildSummaryCell(
                        'Текущий баланс',
                        currencyFormat.format(currentBalance),
                        Icons.account_balance_wallet,
                        AppTheme.successColor,
                        isHighlight: true,
                      ),
                    ),
                  ],
                ),

                Container(
                  height: 1,
                  color: AppTheme.borderColor,
                ),

                // Row 2: Allocated vs Expected Returns
                Row(
                  children: [
                    Expanded(
                      child: _buildSummaryCell(
                        'Выдано в рассрочку',
                        currencyFormat.format(totalAllocated),
                        Icons.money_off,
                        AppTheme.warningColor,
                      ),
                    ),
                    Container(
                      width: 1,
                      height: 60,
                      color: AppTheme.borderColor,
                    ),
                    Expanded(
                      child: _buildSummaryCell(
                        'Ожидаемые возвраты',
                        currencyFormat.format(expectedReturns),
                        Icons.call_received,
                        AppTheme.successColor,
                      ),
                    ),
                  ],
                ),

                Container(
                  height: 1,
                  color: AppTheme.borderColor,
                ),

                // Row 3: Due Amount vs Total Value
                Row(
                  children: [
                    Expanded(
                      child: _buildSummaryCell(
                        'Скоро к получению',
                        currencyFormat.format(dueAmount),
                        Icons.schedule,
                        AppTheme.warningColor,
                      ),
                    ),
                    Container(
                      width: 1,
                      height: 60,
                      color: AppTheme.borderColor,
                    ),
                    Expanded(
                      child: _buildSummaryCell(
                        'Общая стоимость',
                        currencyFormat.format(totalWalletValue),
                        Icons.calculate,
                        AppTheme.primaryColor,
                        isHighlight: true,
                      ),
                    ),
                  ],
                ),

                Container(
                  height: 1,
                  color: AppTheme.borderColor,
                ),

                // Row 4: Profit vs ROI (only if there's investment data)
                if (initialInvestment > 0) ...[
                  Row(
                    children: [
                      Expanded(
                        child: _buildSummaryCell(
                          'Прибыль',
                          currencyFormat.format(totalProfit),
                          totalProfit >= 0 ? Icons.trending_up : Icons.trending_down,
                          totalProfit >= 0 ? AppTheme.successColor : AppTheme.errorColor,
                        ),
                      ),
                      Container(
                        width: 1,
                        height: 60,
                        color: AppTheme.borderColor,
                      ),
                      Expanded(
                        child: _buildSummaryCell(
                          l10n?.locale.languageCode == 'ru' ? 'Доходность инвестиций' : 'Return on Investment',
                          '${roi.toStringAsFixed(1)}%',
                          Icons.percent,
                          totalProfit >= 0 ? AppTheme.successColor : AppTheme.errorColor,
                        ),
                      ),
                    ],
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSummaryCell(String label, String value, IconData icon, Color color, {bool isHighlight = false}) {
    return Container(
      padding: const EdgeInsets.all(16),
      child: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: color.withOpacity(0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(
              icon,
              size: 18,
              color: color,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 12,
                    color: AppTheme.textSecondary,
                    fontWeight: FontWeight.w400,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  value,
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: isHighlight ? FontWeight.w700 : FontWeight.w600,
                    color: AppTheme.textPrimary,
                    letterSpacing: isHighlight ? -0.5 : 0,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInvestmentDetails(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Container(
      decoration: BoxDecoration(
        color: AppTheme.surfaceColor,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppTheme.borderColor),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header - matching the financial summary table design
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: AppTheme.subtleBackgroundColor,
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(11),
                topRight: Radius.circular(11),
              ),
              border: Border(
                bottom: BorderSide(color: AppTheme.subtleBorderColor),
              ),
            ),
            child: Row(
              children: [
                Text(
                  l10n?.walletInfo ?? 'Wallet Info',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: AppTheme.textPrimary,
                  ),
                ),
                const Spacer(),
              ],
            ),
          ),

          // Content
          Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildInvestmentMetric(
                  l10n?.walletName ?? 'Wallet Name',
                  wallet.name,
                ),
                const SizedBox(height: AppTheme.spacingMd),
                _buildInvestmentMetric(
                  l10n?.walletType ?? 'Wallet Type',
                  wallet.type.toString().split('.').last,
                ),
                const SizedBox(height: AppTheme.spacingMd),
                _buildInvestmentMetric(
                  l10n?.status ?? 'Status',
                  wallet.status.toString().split('.').last,
                ),
                if (wallet.investmentAmount != null) ...[
                  const SizedBox(height: AppTheme.spacingMd),
                  _buildInvestmentMetric(
                    l10n?.investmentAmount ?? 'Investment Amount',
                    wallet.investmentAmount != null ? currencyFormat.format(wallet.investmentAmount!) : null,
                  ),
                ],
                if (wallet.investorPercentage != null) ...[
                  const SizedBox(height: AppTheme.spacingMd),
                  _buildInvestmentMetric(
                    l10n?.investorPercentage ?? 'Investor Percentage',
                    wallet.investorPercentage != null ? '${wallet.investorPercentage}%' : null,
                  ),
                ],
                if (wallet.userPercentage != null) ...[
                  const SizedBox(height: AppTheme.spacingMd),
                  _buildInvestmentMetric(
                    l10n?.userPercentage ?? 'User Percentage',
                    wallet.userPercentage != null ? '${wallet.userPercentage}%' : null,
                  ),
                ],
                if (wallet.investmentReturnDate != null) ...[
                  const SizedBox(height: AppTheme.spacingMd),
                  _buildInvestmentMetric(
                    l10n?.investmentReturnDate ?? 'Investment Return Date',
                    wallet.investmentReturnDate != null ? dateFormat.format(wallet.investmentReturnDate!) : null,
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInvestmentMetric(String label, String? value, {bool? isPositive}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 200,
            child: Text(
              label,
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w400,
                color: Colors.grey,
              ),
            ),
          ),
          const SizedBox(width: 32),
          Expanded(
            child: Text(
              value ?? '',
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w500,
                color: AppTheme.textPrimary,
              ),
            ),
          ),
        ],
      ),
    );
  }

    Widget _buildTransactionsList() {
    return Container(
      decoration: BoxDecoration(
        color: AppTheme.surfaceColor,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppTheme.borderColor),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header - matching the financial summary table design
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: AppTheme.subtleBackgroundColor,
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(11),
                topRight: Radius.circular(11),
              ),
              border: Border(
                bottom: BorderSide(color: AppTheme.subtleBorderColor),
              ),
            ),
            child: Row(
              children: [
                Text(
                  'История операций',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: AppTheme.textPrimary,
                  ),
                ),
                const Spacer(),
              ],
            ),
          ),

          // Content
          Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (transactions.isEmpty)
                  Center(
                    child: Padding(
                      padding: const EdgeInsets.all(AppTheme.spacingLg),
                      child: Text(
                        'Нет операций',
                        style: TextStyle(
                          color: AppTheme.textSecondary,
                        ),
                      ),
                    ),
                  )
                else
                  SizedBox(
                    height: 300, // Fixed height for the transaction list
                    child: ListView.builder(
                      itemCount: transactions.length,
                      itemBuilder: (context, index) => _buildTransactionItem(transactions[index]),
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTransactionItem(LedgerTransaction transaction) {
    return Container(
      margin: const EdgeInsets.only(bottom: AppTheme.spacingSm),
      padding: const EdgeInsets.all(AppTheme.spacingMd),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(AppTheme.borderRadiusMedium),
        border: Border.all(color: AppTheme.subtleBorderColor),
      ),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: transaction.isCredit
                  ? AppTheme.successColor.withOpacity(0.1)
                  : AppTheme.errorColor.withOpacity(0.1),
              borderRadius: BorderRadius.circular(AppTheme.borderRadiusSmall),
            ),
            child: Icon(
              transaction.isCredit ? Icons.add : Icons.remove,
              size: 20,
              color: transaction.isCredit ? AppTheme.successColor : AppTheme.errorColor,
            ),
          ),
          const SizedBox(width: AppTheme.spacingMd),
          Expanded(
            child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  transaction.description,
                  style: TextStyle(
                    fontWeight: FontWeight.w500,
                    color: AppTheme.textPrimary,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  '${transaction.referenceType.name} • ${dateFormat.format(transaction.createdAt)}',
                  style: TextStyle(
                    fontSize: 12,
                    color: AppTheme.textSecondary,
                  ),
                ),
              ],
            ),
          ),
          Text(
            '${transaction.isCredit ? '+' : '-'}${currencyFormat.format(transaction.amount)}',
            style: TextStyle(
              fontWeight: FontWeight.w600,
              color: transaction.isCredit ? AppTheme.successColor : AppTheme.errorColor,
              fontSize: 16,
            ),
          ),
        ],
      ),
    );
  }

  Color _getWalletColor() {
    if (wallet.isPersonalWallet) {
      return AppTheme.primaryColor;
    } else {
      return AppTheme.successColor;
    }
  }

  IconData _getWalletIcon() {
    if (wallet.isPersonalWallet) {
      return Icons.account_balance_wallet;
    } else {
      return Icons.trending_up;
    }
  }

  String _getWalletTypeText(AppLocalizations? l10n) {
    if (wallet.isPersonalWallet) {
      return l10n?.personalWallet ?? 'Личный кошелек';
    } else {
      return l10n?.investorWallet ?? 'Инвестиционный кошелек';
    }
  }
}
