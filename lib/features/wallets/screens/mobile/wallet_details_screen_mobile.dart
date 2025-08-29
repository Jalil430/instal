import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/localization/app_localizations.dart';
import '../../../../shared/widgets/custom_icon_button.dart';
import '../../../../shared/widgets/custom_button.dart';
import '../../../../shared/widgets/custom_contextual_dialog.dart';
import '../../widgets/wallet_dialogs.dart';
import '../../domain/entities/wallet.dart';
import '../../domain/entities/wallet_balance.dart';
import '../../domain/entities/ledger_transaction.dart';
import '../../domain/entities/investment_summary.dart';

class WalletDetailsScreenMobile extends StatelessWidget {
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

  const WalletDetailsScreenMobile({
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
  });

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final mediaQuery = MediaQuery.of(context);
    final statusBarHeight = mediaQuery.padding.top;

    // FORCE DEBUG: Check wallet type directly - SIMPLIFIED
    print('🔍 WALLET DEBUG: ${wallet.name}');
    print('🔍 WALLET TYPE ENUM: ${wallet.type}');
    print('🔍 WALLET TYPE INDEX: ${wallet.type.index}');
    print('🔍 WALLET TYPE NAME: ${wallet.type.name}');
    print('🔍 WALLET TYPE TOSTRING: ${wallet.type.toString()}');

    // Use inferred type passed from parent to ensure correct UI
    final walletTypeName = isInvestor ? 'investor' : 'personal';
    final shouldShowPersonalButtons = !isInvestor;

    print('🔍 WALLET TYPE NAME: ${walletTypeName}');
    print('🔍 SHOULD SHOW PERSONAL BUTTONS: ${shouldShowPersonalButtons}');

    return Scaffold(
      backgroundColor: Colors.white,
      body: Column(
        children: [
          // Header with safe area for status bar - matching client details pattern
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
                          fontSize: 18,
                          fontWeight: FontWeight.w600,
                          letterSpacing: -0.5,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        walletTypeName == 'personal'
                            ? (l10n?.personalWallet ?? 'Личный кошелек')
                            : (l10n?.investorWallet ?? 'Инвестиционный кошелек'),
                        style: TextStyle(
                          fontSize: 12,
                          color: AppTheme.textSecondary,
                          fontWeight: FontWeight.w400,
                        ),
                      ),
                    ],
                  ),
                ),

                    // Show different buttons based on wallet type
                    if (shouldShowPersonalButtons) ...[
                      // Personal wallet: Show ADD and WITHDRAW buttons (larger to fit labels)
                      CustomButton(
                        text: l10n?.addMoney ?? 'Add Money',
                        onPressed: onAddMoney ?? () {},
                        icon: Icons.add_circle,
                        color: AppTheme.successColor,
                        textColor: Colors.white,
                        fontSize: 12,
                        height: 36,
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      ),
                      const SizedBox(width: 8),
                      CustomButton(
                        text: l10n?.withdrawMoney ?? 'Withdraw Money',
                        onPressed: onWithdrawMoney ?? () {},
                        icon: Icons.remove_circle,
                        color: AppTheme.warningColor,
                        textColor: Colors.white,
                        fontSize: 12,
                        height: 36,
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      ),
                      const SizedBox(width: 8),
                      CustomIconButton(
                        icon: Icons.archive,
                        onPressed: () => _showArchiveConfirmationDialog(context),
                        hoverBackgroundColor: AppTheme.warningColor.withOpacity(0.1),
                        hoverIconColor: AppTheme.warningColor,
                        hoverBorderColor: AppTheme.warningColor.withOpacity(0.3),
                      ),
                      const SizedBox(width: 8),
                    ] else ...[
                      // Investor wallet: NO ADD/WITHDRAW buttons, only archive
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: AppTheme.primaryColor.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          'INVESTOR WALLET',
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w600,
                            color: AppTheme.primaryColor,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      CustomIconButton(
                        icon: Icons.archive,
                        onPressed: () => _showArchiveConfirmationDialog(context),
                        hoverBackgroundColor: AppTheme.warningColor.withOpacity(0.1),
                        hoverIconColor: AppTheme.warningColor,
                        hoverBorderColor: AppTheme.warningColor.withOpacity(0.3),
                      ),
                      const SizedBox(width: 8),
                    ],
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
            ),
          ),

          // Main content
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [




                  // Financial Summary Table
                  _buildFinancialSummaryTable(context),

                  const SizedBox(height: 16),

                  // Wallet information card for both types
                  _buildInvestmentDetails(context),
                  const SizedBox(height: 16),

                  // Recent transactions
                  Container(
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
                          padding: const EdgeInsets.all(16),
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
                                l10n?.walletTransactions ?? 'Операции кошелька',
                                style: TextStyle(
                                  fontSize: 14,
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
                          padding: const EdgeInsets.all(16),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const SizedBox(height: 16),
                              if (transactions.isEmpty)
                                Center(
                                  child: Padding(
                                    padding: const EdgeInsets.all(24),
                                    child: Text(
                                      l10n?.noOperations ?? 'Нет операций',
                                      style: TextStyle(
                                        color: AppTheme.textSecondary,
                                      ),
                                    ),
                                  ),
                                )
                              else
                                ...transactions
                                    .take(5)
                                    .map((transaction) => _buildTransactionItem(context, transaction)),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
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
    final initialInvestment = investmentSummary?.totalInvested ??
        (wallet.isPersonalWallet ? wallet.startingAmount : wallet.investmentAmount) ?? 0;
    final totalAllocated = investmentSummary?.totalAllocated ?? 0;
    final expectedReturns = investmentSummary?.expectedReturns ?? 0;
    final dueAmount = investmentSummary?.dueAmount ?? 0;

    final totalWalletValue = currentBalance + expectedReturns;
    final totalProfit = totalWalletValue - initialInvestment;
    final roi = initialInvestment > 0 ? (totalProfit / initialInvestment) * 100 : 0;

    return Column(
      children: [
        // Financial Metrics Grid - 2x2 layout
        Container(
          decoration: BoxDecoration(
            color: AppTheme.surfaceColor,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: AppTheme.borderColor),
          ),
          child: Column(
            children: [
              // Row 1: Initial Investment | Current Balance
              Row(
                children: [
                  Expanded(
                    child: _buildMobileSummaryCell(
                      wallet.isPersonalWallet
                          ? (l10n?.startingAmount ?? 'Начальная сумма')
                          : (l10n?.initialInvestment ?? 'Первоначальная инвестиция'),
                      initialInvestment > 0 ? currencyFormat.format(initialInvestment) : '—',
                      Icons.account_balance,
                      AppTheme.primaryColor,
                    ),
                  ),
                  Container(
                    width: 1,
                    height: 80,
                    color: AppTheme.borderColor,
                  ),
                  Expanded(
                    child: _buildMobileSummaryCell(
                      l10n?.currentBalance ?? 'Текущий баланс',
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

              // Row 2: Allocated | Expected Returns (Expected Returns shown only for investor)
              Row(
                children: [
                  Expanded(
                    child: _buildMobileSummaryCell(
                      l10n?.givenForInstallmentDetail ?? 'Выдано в рассрочку',
                      currencyFormat.format(totalAllocated),
                      Icons.money_off,
                      AppTheme.warningColor,
                    ),
                  ),
                  Container(
                    width: 1,
                    height: 80,
                    color: AppTheme.borderColor,
                  ),
                  Expanded(
                    child: _buildMobileSummaryCell(
                      l10n?.expectedReturns ?? 'Ожидаемые возвраты',
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

              // Row 3: Due Amount | Total Value
              Row(
                children: [
                  Expanded(
                    child: _buildMobileSummaryCell(
                      l10n?.dueToGetDetail ?? 'Скоро к получению',
                      currencyFormat.format(dueAmount),
                      Icons.schedule,
                      AppTheme.warningColor,
                    ),
                  ),
                  Container(
                    width: 1,
                    height: 80,
                    color: AppTheme.borderColor,
                  ),
                  Expanded(
                    child: _buildMobileSummaryCell(
                      l10n?.totalValue ?? 'Общая стоимость',
                      currencyFormat.format(totalWalletValue),
                      Icons.calculate,
                      AppTheme.primaryColor,
                      isHighlight: true,
                    ),
                  ),
                ],
              ),

              // Row 4: Profit | ROI (only for investor and if there's investment data)
              if (isInvestor && initialInvestment > 0) ...[
                Container(
                  height: 1,
                  color: AppTheme.borderColor,
                ),
                Row(
                  children: [
                    Expanded(
                      child: _buildMobileSummaryCell(
                        l10n?.profit ?? 'Прибыль',
                        currencyFormat.format(totalProfit),
                        totalProfit >= 0 ? Icons.trending_up : Icons.trending_down,
                        totalProfit >= 0 ? AppTheme.successColor : AppTheme.errorColor,
                      ),
                    ),
                    Container(
                      width: 1,
                      height: 80,
                      color: AppTheme.borderColor,
                    ),
                    Expanded(
                      child: _buildMobileSummaryCell(
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
    );
  }

  Widget _buildMobileSummaryCell(String label, String value, IconData icon, Color color, {bool isHighlight = false}) {
    return Container(
      padding: const EdgeInsets.all(12),
      child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 28,
                height: 28,
                decoration: BoxDecoration(
                  color: color.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Icon(
                  icon,
                  size: 14,
                  color: color,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  label,
                  style: TextStyle(
                    fontSize: 10,
                    color: AppTheme.textSecondary,
                    fontWeight: FontWeight.w400,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            value,
            style: TextStyle(
              fontSize: 14,
              fontWeight: isHighlight ? FontWeight.w700 : FontWeight.w600,
              color: AppTheme.textPrimary,
              letterSpacing: isHighlight ? -0.3 : 0,
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
            padding: const EdgeInsets.all(16),
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
                    fontSize: 14,
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
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildInvestmentMetric(
                  l10n?.walletName ?? 'Wallet Name',
                  wallet.name,
                ),
                _buildInvestmentMetric(
                  l10n?.walletType ?? 'Wallet Type',
                  isInvestor ? (l10n?.investorWallet ?? 'Investor wallet') : (l10n?.personalWallet ?? 'Personal wallet'),
                ),
                _buildInvestmentMetric(
                  l10n?.status ?? 'Status',
                  wallet.isActive ? (l10n?.statusActive ?? 'Active') : (l10n?.statusArchived ?? 'Archived'),
                ),
                if (wallet.isPersonalWallet) ...[
                  // For personal wallets, show starting amount instead of investment amount
                  _buildInvestmentMetric(
                    l10n?.startingAmount ?? 'Starting Amount',
                    currencyFormat.format(wallet.startingAmount ?? 0),
                  ),
                ] else if (wallet.investmentAmount != null) ...[
                  _buildInvestmentMetric(
                    l10n?.investmentAmount ?? 'Investment Amount',
                    wallet.investmentAmount != null ? currencyFormat.format(wallet.investmentAmount!) : null,
                  ),
                ],
                if (wallet.investorPercentage != null)
                  _buildInvestmentMetric(
                    l10n?.investorPercentage ?? 'Investor Percentage',
                    wallet.investorPercentage != null ? '${wallet.investorPercentage}%' : null,
                  ),
                if (wallet.userPercentage != null)
                  _buildInvestmentMetric(
                    l10n?.userPercentage ?? 'User Percentage',
                    wallet.userPercentage != null ? '${wallet.userPercentage}%' : null,
                  ),
                if (wallet.investmentReturnDate != null)
                  _buildInvestmentMetric(
                    l10n?.investmentReturnDate ?? 'Investment Return Date',
                    wallet.investmentReturnDate != null ? dateFormat.format(wallet.investmentReturnDate!) : null,
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInvestmentMetric(String label, String? value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w400,
              color: Colors.grey,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            value ?? '',
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w500,
              color: AppTheme.textPrimary,
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
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              color: transaction.isCredit
                  ? AppTheme.successColor.withOpacity(0.1)
                  : AppTheme.errorColor.withOpacity(0.1),
              borderRadius: BorderRadius.circular(AppTheme.borderRadiusSmall),
            ),
            child: Icon(
              transaction.isCredit ? Icons.add : Icons.remove,
              size: 16,
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
                Text(
                  '${transaction.getDisplayName(l10n!)} • ${dateFormat.format(transaction.createdAt)}',
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
    final investorPercentage = wallet.investorPercentage ?? 70.0;
    final userPercentage = wallet.userPercentage ?? 30.0;

    // Calculate amounts from current balance
    final investorAmount = currentBalance * (investorPercentage / 100);
    final userAmount = currentBalance * (userPercentage / 100);

    // Mock full expected amounts (when all installments are collected)
    final expectedTotalBalance = currentBalance * 2.5; // Mock multiplier
    final expectedInvestorAmount = expectedTotalBalance * (investorPercentage / 100);
    final expectedUserAmount = expectedTotalBalance * (userPercentage / 100);

    return Container(
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
            padding: const EdgeInsets.all(16),
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
                    fontSize: 14,
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
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Current Distribution
                Container(
                  padding: const EdgeInsets.all(12),
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
                      const SizedBox(height: 8),
                      _buildSimpleAmountRow(
                        'Investor Share',
                        currencyFormat.format(investorAmount),
                        '${investorPercentage.toStringAsFixed(0)}%',
                        AppTheme.primaryColor,
                      ),
                      const SizedBox(height: 6),
                      _buildSimpleAmountRow(
                        'Your Share',
                        currencyFormat.format(userAmount),
                        '${userPercentage.toStringAsFixed(0)}%',
                        AppTheme.successColor,
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 12),

                // Expected Distribution
                Container(
                  padding: const EdgeInsets.all(12),
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
                      const SizedBox(height: 8),
                      _buildSimpleAmountRow(
                        'Investor Share',
                        currencyFormat.format(expectedInvestorAmount),
                        '${investorPercentage.toStringAsFixed(0)}%',
                        AppTheme.primaryColor.withOpacity(0.7),
                      ),
                      const SizedBox(height: 6),
                      _buildSimpleAmountRow(
                        'Your Share',
                        currencyFormat.format(expectedUserAmount),
                        '${userPercentage.toStringAsFixed(0)}%',
                        AppTheme.successColor.withOpacity(0.7),
                      ),
                    ],
                  ),
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
          width: 8,
          height: 8,
          decoration: BoxDecoration(
            color: color,
            shape: BoxShape.circle,
          ),
        ),
        const SizedBox(width: 8),
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
            fontSize: 14,
            color: AppTheme.textPrimary,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(width: 8),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
          decoration: BoxDecoration(
            color: color.withOpacity(0.1),
            borderRadius: BorderRadius.circular(4),
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
              l10n?.archiveWalletTitle ?? 'Archive Wallet',
              style: TextStyle(
                color: AppTheme.textPrimary,
                fontSize: 18,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
        content: Text(
          l10n?.archiveWalletConfirmation(wallet.name) ?? 'Are you sure you want to archive this wallet? This action can be undone later.',
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
            child: Text(l10n?.archive ?? 'Archive'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      // TODO: Implement archive wallet functionality
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Wallet "${wallet.name}" has been archived'),
          backgroundColor: AppTheme.warningColor,
        ),
      );
    }
  }
}
