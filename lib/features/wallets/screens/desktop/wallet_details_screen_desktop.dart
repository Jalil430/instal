import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/utils/num_format.dart';
import '../../../../core/localization/app_localizations.dart';
import '../../../../shared/widgets/custom_icon_button.dart';
import '../../domain/entities/wallet.dart';
import '../../domain/entities/wallet_balance.dart';
import '../../domain/entities/ledger_transaction.dart';
import '../../domain/entities/investment_summary.dart';
import '../../../installments/domain/entities/installment.dart';
import '../../../../shared/widgets/custom_button.dart';
import '../../../../shared/widgets/custom_contextual_dialog.dart';
import '../../widgets/wallet_dialogs.dart';

class WalletDetailsScreenDesktop extends StatelessWidget {
  final Wallet wallet;
  final WalletBalance? balance;
  final List<LedgerTransaction> transactions;
  final InvestmentSummary? investmentSummary;
  final DateFormat dateFormat;
  final NumberFormat currencyFormat;
  final VoidCallback onDelete;
  final VoidCallback? onAddMoney;
  final VoidCallback? onWithdrawMoney;
  final bool isInvestor;
  final VoidCallback onArchiveToggle;
  final List<Installment> installments;
  final bool installmentsLoading;

  const WalletDetailsScreenDesktop({
    super.key,
    required this.wallet,
    this.balance,
    required this.transactions,
    this.investmentSummary,
    required this.dateFormat,
    required this.currencyFormat,
    required this.onDelete,
    this.onAddMoney,
    this.onWithdrawMoney,
    required this.isInvestor,
    required this.onArchiveToggle,
    required this.installments,
    required this.installmentsLoading,
  });

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);

    // Use inferred flag from parent to ensure correct UI
    final walletTypeName = isInvestor ? 'investor' : 'personal';
    final isPersonal = !isInvestor;

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
                if (isPersonal) ...[
                  // Personal Wallet: Add Money + Withdraw + Archive + Delete
                  Row(
                    children: [
                      if (onAddMoney != null) ...[
                        CustomButton(
                          text: l10n?.add ?? 'Добавить',
                          onPressed: onAddMoney,
                          icon: Icons.add_circle,
                          color: AppTheme.successColor,
                          textColor: Colors.white,
                          fontSize: 13,
                          height: 32,
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                        ),
                        const SizedBox(width: 8),
                      ],
                      if (onWithdrawMoney != null) ...[
                        CustomButton(
                          text: l10n?.withdraw ?? 'Снять',
                          onPressed: onWithdrawMoney,
                          icon: Icons.remove_circle,
                          color: AppTheme.warningColor,
                          textColor: Colors.white,
                          fontSize: 13,
                          height: 32,
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                        ),
                        const SizedBox(width: 8),
                      ],
                      CustomIconButton(
                        icon: wallet.status == WalletStatus.archived ? Icons.unarchive : Icons.archive,
                        onPressed: () => _showArchiveConfirmationDialog(context),
                        hoverBackgroundColor: AppTheme.warningColor.withOpacity(0.1),
                        hoverIconColor: AppTheme.warningColor,
                        hoverBorderColor: AppTheme.warningColor.withOpacity(0.3),
                      ),
                      const SizedBox(width: 8),
                      CustomIconButton(
                        icon: Icons.delete_outline,
                        onPressed: onDelete,
                        hoverBackgroundColor: AppTheme.errorColor.withOpacity(0.1),
                        hoverIconColor: AppTheme.errorColor,
                        hoverBorderColor: AppTheme.errorColor.withOpacity(0.3),
                      ),
                    ],
                  ),
                ] else if (!isPersonal && wallet.isActive) ...[
                  // Active Investor Wallet: Archive + Delete
                  Row(
                    children: [
                      CustomIconButton(
                        icon: wallet.status == WalletStatus.archived ? Icons.unarchive : Icons.archive,
                        onPressed: () => _showArchiveConfirmationDialog(context),
                        hoverBackgroundColor: AppTheme.warningColor.withOpacity(0.1),
                        hoverIconColor: AppTheme.warningColor,
                        hoverBorderColor: AppTheme.warningColor.withOpacity(0.3),
                      ),
                      const SizedBox(width: 8),
                      CustomIconButton(
                        icon: Icons.delete_outline,
                        onPressed: onDelete,
                        hoverBackgroundColor: AppTheme.errorColor.withOpacity(0.1),
                        hoverIconColor: AppTheme.errorColor,
                        hoverBorderColor: AppTheme.errorColor.withOpacity(0.3),
                      ),
                    ],
                  ),
                ] else if (!isPersonal && !wallet.isActive) ...[
                  // Stopped Investor Wallet: Archive + Delete
                  Row(
                    children: [
                      CustomIconButton(
                        icon: wallet.status == WalletStatus.archived ? Icons.unarchive : Icons.archive,
                        onPressed: () => _showArchiveConfirmationDialog(context),
                        hoverBackgroundColor: AppTheme.warningColor.withOpacity(0.1),
                        hoverIconColor: AppTheme.warningColor,
                        hoverBorderColor: AppTheme.warningColor.withOpacity(0.3),
                      ),
                      const SizedBox(width: 8),
                      CustomIconButton(
                        icon: Icons.delete_outline,
                        onPressed: onDelete,
                        hoverBackgroundColor: AppTheme.errorColor.withOpacity(0.1),
                        hoverIconColor: AppTheme.errorColor,
                        hoverBorderColor: AppTheme.errorColor.withOpacity(0.3),
                      ),
                    ],
                  ),
                ],
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

                  // Wallet information card for both wallet types
                  _buildInvestmentDetails(context),
                  const SizedBox(height: 20),

                  // Transactions
                  if (transactions.isNotEmpty) _buildTransactionsList(context),

                  const SizedBox(height: 20),

                  // Linked Installments (moved under transactions)
                  _buildInstallmentsSection(context),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInstallmentsSection(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(
              '${l10n?.installments ?? 'Рассрочки'} (${installments.length})',
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
            ),
            const SizedBox(width: 8),
            if (installmentsLoading)
              const SizedBox(
                height: 16,
                width: 16,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
          ],
        ),
        const SizedBox(height: 12),
        Container(
          decoration: BoxDecoration(
            color: AppTheme.surfaceColor,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: AppTheme.borderColor),
          ),
          child: Column(
            children: [
              _buildInstallmentsTableHeader(context),
              if (installments.isEmpty)
                Padding(
                  padding: const EdgeInsets.all(24),
                  child: Center(child: Text(l10n?.noInstallments ?? 'Нет рассрочек')),
                )
              else
                SizedBox(
                  height: 300,
                  child: ListView.builder(
                    itemCount: installments.length,
                    itemBuilder: (context, index) => _buildInstallmentRow(context, installments[index]),
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildInstallmentsTableHeader(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final headerStyle = Theme.of(context).textTheme.labelMedium?.copyWith(
          color: AppTheme.textSecondary,
          fontWeight: FontWeight.w400,
          fontSize: 12,
          letterSpacing: 0.5,
        );
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      decoration: BoxDecoration(
        color: AppTheme.subtleBackgroundColor,
        borderRadius: const BorderRadius.only(topLeft: Radius.circular(11), topRight: Radius.circular(11)),
        border: Border(bottom: BorderSide(color: AppTheme.subtleBorderColor, width: 1)),
      ),
      child: Row(
        children: [
          Expanded(flex: 3, child: Text(l10n?.productNameHeader ?? 'ТОВАР', style: headerStyle)),
          Expanded(flex: 2, child: Text(l10n?.amountHeader ?? 'СУММА', style: headerStyle)),
          Expanded(flex: 2, child: Text(l10n?.term ?? 'СРОК', style: headerStyle)),
          Expanded(flex: 2, child: Text(l10n?.buyingDateHeader ?? 'ДАТА ПОКУПКИ', style: headerStyle)),
        ],
      ),
    );
  }

  Widget _buildInstallmentRow(BuildContext context, Installment installment) {
    return InkWell(
      onTap: () => context.go('/installments/${installment.id}'),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        decoration: BoxDecoration(
          border: Border(bottom: BorderSide(color: AppTheme.borderColor.withOpacity(0.3), width: 1)),
        ),
        child: Row(
          children: [
            Expanded(
              flex: 3,
              child: Text(installment.productName, style: Theme.of(context).textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w500)),
            ),
            Expanded(
              flex: 2,
              child: Text(currencyFormat.format(installment.installmentPrice), style: Theme.of(context).textTheme.bodyMedium),
            ),
            Expanded(
              flex: 2,
              child: Text('${installment.termMonths} ${AppLocalizations.of(context)?.months ?? 'месяцев'}', style: Theme.of(context).textTheme.bodyMedium),
            ),
            Expanded(
              flex: 2,
              child: Text(dateFormat.format(installment.downPaymentDate), style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: AppTheme.textSecondary)),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFinancialSummaryTable(BuildContext context) {
    final l10n = AppLocalizations.of(context);

    // Calculate key metrics
    final currentBalance = balance?.balance ?? 0;
    final initialInvestment = investmentSummary?.totalInvested ??
        (wallet.isPersonalWallet ? wallet.startingAmount : wallet.investmentAmount) ?? 0;
    // Use persisted aggregates
    final totalAllocated = balance?.totalAllocated ?? (investmentSummary?.totalAllocated ?? 0);
    final expectedReturns = balance?.expectedRevenue ?? (investmentSummary?.expectedReturns ?? 0);
    final paidAmount = balance?.paidAmount ?? 0;
    final dueAmount = balance?.dueToGet ?? (investmentSummary?.dueAmount ?? 0);

    final totalWalletValue = currentBalance + totalAllocated;
    final totalProfit = expectedReturns;
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
          // Table Content (header removed to match mobile version)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Column(
              children: [
                // Row 1: Initial Investment vs Current Balance
                Row(
                  children: [
                    Expanded(
                      child: _buildSummaryCell(
                        wallet.isPersonalWallet
                            ? (l10n?.startingAmount ?? 'Starting Amount')
                            : (l10n?.initialInvestment ?? 'Initial Investment'),
                        initialInvestment > 0 ? stripTrailingZeroMoney(currencyFormat.format(initialInvestment)) : '—',
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
                        l10n?.currentBalance ?? 'Current Balance',
                        stripTrailingZeroMoney(currencyFormat.format(currentBalance)),
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

                // Row 2: Allocated vs Expected Returns (Expected Returns shown only for investor)
                Row(
                  children: [
                    Expanded(
                      child: _buildSummaryCell(
                        l10n?.givenForInstallmentDetail ?? 'Given for Installment',
                        stripTrailingZeroMoney(currencyFormat.format(totalAllocated)),
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
                        l10n?.paidAmount ?? 'Оплачено',
                        stripTrailingZeroMoney(currencyFormat.format(paidAmount)),
                        Icons.payments,
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
                        l10n?.dueToGetDetail ?? 'Due to Get',
                        stripTrailingZeroMoney(currencyFormat.format(dueAmount)),
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
                        l10n?.totalValue ?? 'Total Value',
                        stripTrailingZeroMoney(currencyFormat.format(totalWalletValue)),
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

                // Row 4: Profit vs ROI (only for investor and if there's investment data)
                if (isInvestor && initialInvestment > 0) ...[
                  Row(
                    children: [
                      Expanded(
                        child: _buildSummaryCell(
                          l10n?.expectedProfit ?? 'Expected Profit',
                          stripTrailingZeroMoney(currencyFormat.format(totalProfit)),
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
                    fontWeight: FontWeight.w600,
                    color: AppTheme.textPrimary,
                    letterSpacing: 0,
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
                  isInvestor ? (l10n?.investorWallet ?? 'Investor wallet') : (l10n?.personalWallet ?? 'Personal wallet'),
                ),
                const SizedBox(height: AppTheme.spacingMd),
                _buildInvestmentMetric(
                  l10n?.status ?? 'Status',
                  wallet.isActive ? (l10n?.statusActive ?? 'Active') : (l10n?.statusArchived ?? 'Archived'),
                ),
                if (wallet.isPersonalWallet) ...[
                  const SizedBox(height: AppTheme.spacingMd),
                  _buildInvestmentMetric(
                    l10n?.startingAmount ?? 'Starting Amount',
                    stripTrailingZeroMoney(currencyFormat.format(wallet.startingAmount ?? 0)),
                  ),
                ] else if (wallet.investmentAmount != null) ...[
                  const SizedBox(height: AppTheme.spacingMd),
                  _buildInvestmentMetric(
                    l10n?.investmentAmount ?? 'Investment Amount',
                    wallet.investmentAmount != null ? stripTrailingZeroMoney(currencyFormat.format(wallet.investmentAmount!)) : null,
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

    Widget _buildTransactionsList(BuildContext context) {
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
                  l10n?.transactionHistory ?? 'Transaction History',
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
                        l10n?.noOperations ?? 'No operations',
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
                      itemBuilder: (context, index) => _buildTransactionItem(context, transactions[index]),
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTransactionItem(BuildContext context, LedgerTransaction transaction) {
    final l10n = AppLocalizations.of(context);
    return Container(
      margin: const EdgeInsets.only(bottom: AppTheme.spacingSm),
      padding: const EdgeInsets.all(AppTheme.spacingMd),
      decoration: BoxDecoration(
        color: AppTheme.subtleBackgroundColor,
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
                  transaction.getDisplayName(l10n!),
                  style: TextStyle(
                    fontWeight: FontWeight.w500,
                    color: AppTheme.textPrimary,
                  ),
                ),
                const SizedBox(height: 2),
                // Description with date right after it
                Text(
                  '${transaction.getDescriptionLocalized(l10n!)} • ${dateFormat.format(transaction.createdAt)}',
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 12,
                    color: AppTheme.textSecondary,
                  ),
                ),
              ],
            ),
          ),
          Text(
            '${transaction.isCredit ? '+' : '-'}${stripTrailingZeroMoney(currencyFormat.format(transaction.amount))}',
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
    final walletTypeName = wallet.type.name;
    final isPersonal = walletTypeName == 'personal';
    if (isPersonal) {
      return AppTheme.primaryColor;
    } else {
      return AppTheme.successColor;
    }
  }

  IconData _getWalletIcon() {
    final walletTypeName = wallet.type.name;
    final isPersonal = walletTypeName == 'personal';
    if (isPersonal) {
      return Icons.account_balance_wallet;
    } else {
      return Icons.trending_up;
    }
  }

  String _getWalletTypeText(AppLocalizations? l10n) {
    final walletTypeName = wallet.type.name;
    final isPersonal = walletTypeName == 'personal';
    if (isPersonal) {
      return l10n?.personalWallet ?? 'Личный кошелек';
    } else {
      return l10n?.investorWallet ?? 'Инвестиционный кошелек';
    }
  }

  Future<void> _showAddMoneyDialog(BuildContext context) async {
    final currentBalance = balance?.balance ?? 0;

    await AddMoneyDialog.show(
      context: context,
      wallet: wallet,
      currencyFormat: currencyFormat,
      onConfirm: (amount) {
        // TODO: Implement add money functionality
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Added ${currencyFormat.format(amount)} to ${wallet.name}'),
            backgroundColor: AppTheme.successColor,
          ),
        );
      },
    );
  }

  Future<void> _showWithdrawMoneyDialog(BuildContext context) async {
    final currentBalance = balance?.balance ?? 0;

    await WithdrawMoneyDialog.show(
      context: context,
      wallet: wallet,
      currentBalance: currentBalance,
      currencyFormat: currencyFormat,
      onConfirm: (amount) {
        // TODO: Implement withdraw money functionality
        if (amount <= currentBalance) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Withdrew ${currencyFormat.format(amount)} from ${wallet.name}'),
              backgroundColor: AppTheme.warningColor,
            ),
          );
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: const Text('Insufficient balance'),
              backgroundColor: AppTheme.errorColor,
            ),
          );
        }
      },
    );
  }

  Widget _buildInvestmentSummaryCard(BuildContext context) {
    final currentBalance = balance?.balance ?? 0;
    final investorPercentage = wallet.investorPercentage ?? 0.0;
    final userPercentage = wallet.userPercentage ?? 0.0;
    final investorAmount = currentBalance * (investorPercentage / 100);
    final userAmount = currentBalance * (userPercentage / 100);
    // Expected distribution when remaining (due_to_get) is collected
    final dueToGet = balance?.dueToGet ?? 0.0;
    final expectedTotalBalance = currentBalance + dueToGet;
    final expectedInvestorAmount = expectedTotalBalance * (investorPercentage / 100);
    final expectedUserAmount = expectedTotalBalance * (userPercentage / 100);

    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: AppTheme.surfaceColor,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppTheme.borderColor),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header - matching wallet info section style
          Container(
            width: double.infinity,
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
                  'Investment Distribution',
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
              children: [
                // Horizontal layout for desktop
                Row(
                  children: [
                    // Current Distribution
                    Expanded(
                      child: Container(
                        margin: const EdgeInsets.only(right: 12),
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: AppTheme.subtleBackgroundColor,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Current Balance',
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w500,
                                color: AppTheme.textSecondary,
                              ),
                            ),
                            const SizedBox(height: 12),
                            _buildSimpleAmountRow(
                              'Investor Share',
                              currencyFormat.format(investorAmount),
                              '${investorPercentage.toStringAsFixed(0)}%',
                              AppTheme.primaryColor,
                            ),
                            const SizedBox(height: 8),
                            _buildSimpleAmountRow(
                              'Your Share',
                              currencyFormat.format(userAmount),
                              '${userPercentage.toStringAsFixed(0)}%',
                              AppTheme.successColor,
                            ),
                          ],
                        ),
                      ),
                    ),

                    // Expected Distribution
                    Expanded(
                      child: Container(
                        margin: const EdgeInsets.only(left: 12),
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: AppTheme.subtleBackgroundColor,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'When All Installments Collected',
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w500,
                                color: AppTheme.textSecondary,
                              ),
                            ),
                            const SizedBox(height: 12),
                            _buildSimpleAmountRow(
                              'Investor Share',
                              currencyFormat.format(expectedInvestorAmount),
                              '${investorPercentage.toStringAsFixed(0)}%',
                              AppTheme.primaryColor.withOpacity(0.7),
                            ),
                            const SizedBox(height: 8),
                            _buildSimpleAmountRow(
                              'Your Share',
                              currencyFormat.format(expectedUserAmount),
                              '${userPercentage.toStringAsFixed(0)}%',
                              AppTheme.successColor.withOpacity(0.7),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSimpleAmountRow(String label, String amount, String percentage, Color color) {
    return Row(
      children: [
        Container(
          width: 10,
          height: 10,
          decoration: BoxDecoration(
            color: color,
            shape: BoxShape.circle,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Text(
            label,
            style: TextStyle(
              fontSize: 14,
              color: AppTheme.textPrimary,
              fontWeight: FontWeight.w400,
            ),
          ),
        ),
        Text(
          amount,
          style: TextStyle(
            fontSize: 16,
            color: AppTheme.textPrimary,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(width: 12),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          decoration: BoxDecoration(
            color: color.withOpacity(0.1),
            borderRadius: BorderRadius.circular(6),
          ),
          child: Text(
            percentage,
            style: TextStyle(
              fontSize: 12,
              color: color,
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
      ],
    );
  }





  Future<void> _showArchiveConfirmationDialog(BuildContext context) async {
    final l10n = AppLocalizations.of(context);

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppTheme.surfaceColor,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
        title: Row(
          children: [
            Icon(
              Icons.archive,
              color: AppTheme.warningColor,
              size: 24,
            ),
            const SizedBox(width: 12),
            Text(
              wallet.status == WalletStatus.archived
                  ? (l10n?.unarchiveWalletTitle ?? 'Unarchive Wallet')
                  : (l10n?.archiveWalletTitle ?? 'Archive Wallet'),
              style: TextStyle(
                color: AppTheme.textPrimary,
                fontSize: 18,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
        content: Text(
          wallet.status == WalletStatus.archived
              ? (l10n?.unarchiveWalletConfirmation(wallet.name) ?? 'Unarchive this wallet?')
              : (l10n?.archiveWalletConfirmation(wallet.name) ?? 'Are you sure you want to archive this wallet? This action can be undone later.'),
          style: TextStyle(
            color: AppTheme.textSecondary,
            fontSize: 14,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            style: TextButton.styleFrom(
              foregroundColor: AppTheme.textSecondary,
            ),
            child: Text(l10n?.cancel ?? 'Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.warningColor,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            child: Text(wallet.status == WalletStatus.archived ? (l10n?.unarchive ?? 'Unarchive') : (l10n?.archive ?? 'Archive')),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      onArchiveToggle();
    }
  }
}
