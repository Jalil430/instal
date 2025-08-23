import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/localization/app_localizations.dart';
import '../../../shared/widgets/custom_icon_button.dart';
import '../domain/entities/wallet.dart';
import '../domain/entities/wallet_balance.dart';
import '../domain/entities/ledger_transaction.dart';
import '../domain/entities/investment_summary.dart';
import '../../../shared/widgets/custom_confirmation_dialog.dart';
import '../../../shared/widgets/custom_button.dart';
import '../widgets/create_edit_wallet_dialog.dart';
import '../../../shared/widgets/responsive_layout.dart';
import 'desktop/wallet_details_screen_desktop.dart';
import 'mobile/wallet_details_screen_mobile.dart';

class WalletDetailsScreen extends StatefulWidget {
  final String walletId;

  const WalletDetailsScreen({
    super.key,
    required this.walletId,
  });

  @override
  State<WalletDetailsScreen> createState() => _WalletDetailsScreenState();
}

class _WalletDetailsScreenState extends State<WalletDetailsScreen> {
  Wallet? _wallet;
  WalletBalance? _balance;
  List<LedgerTransaction> _transactions = [];
  InvestmentSummary? _investmentSummary;
  bool _isLoading = true;
  bool _isInitialized = false;

  @override
  void initState() {
    super.initState();
    // TODO: Initialize repositories
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_isInitialized) {
      _loadData();
      _isInitialized = true;
    }
  }

  Future<void> _loadData() async {
    if (!mounted) return;
    setState(() => _isLoading = true);

    try {
      // TODO: Load wallet data from repository
      // For now, create mock data
      await Future.delayed(const Duration(seconds: 1));

      final mockWallet = Wallet(
        id: widget.walletId,
        userId: 'user123', // Mock user ID
        name: widget.walletId == '1' ? 'My Wallet' : 'Investor A',
        type: widget.walletId == '1' ? WalletType.personal : WalletType.investor,
        investmentAmount: widget.walletId == '1' ? null : 1000000,
        investorPercentage: widget.walletId == '1' ? null : 70,
        userPercentage: widget.walletId == '1' ? null : 30,
        investmentReturnDate: widget.walletId == '1' ? null : DateTime.now().add(const Duration(days: 365)),
        createdAt: DateTime.now().subtract(const Duration(days: 30)),
        updatedAt: DateTime.now(),
      );

      final mockBalance = WalletBalance(
        walletId: widget.walletId,
        userId: 'user123',
        balanceMinorUnits: widget.walletId == '1' ? 50000000 : 345000000, // 500K or 3.45M RUB
        version: 1,
        updatedAt: DateTime.now(),
      );

      final mockTransactions = [
        LedgerTransaction(
          id: 'tx1',
          walletId: widget.walletId,
          userId: 'user123',
          direction: TransactionDirection.credit,
          amountMinorUnits: 10000000, // 100K RUB
          currency: 'RUB',
          referenceType: TransactionType.adjustment,
          description: 'Initial funding',
          createdBy: 'user123',
          createdAt: DateTime.now().subtract(const Duration(days: 5)),
        ),
        LedgerTransaction(
          id: 'tx2',
          walletId: widget.walletId,
          userId: 'user123',
          direction: TransactionDirection.debit,
          amountMinorUnits: 5000000, // 50K RUB
          currency: 'RUB',
          referenceType: TransactionType.installment,
          referenceId: 'installment1',
          description: 'Installment funding',
          createdBy: 'user123',
          createdAt: DateTime.now().subtract(const Duration(days: 3)),
        ),
      ];

      InvestmentSummary? mockInvestmentSummary;
      if (mockWallet.isInvestorWallet) {
        mockInvestmentSummary = InvestmentSummary(
          walletId: widget.walletId,
          totalInvestedMinorUnits: 100000000, // 1M RUB
          currentBalanceMinorUnits: 345000000, // 3.45M RUB
          totalAllocatedMinorUnits: 50000000, // 500K RUB
          expectedReturnsMinorUnits: 245000000, // 2.45M RUB expected profit
          dueAmountMinorUnits: 134500000, // 1.345M RUB due
          returnDueDate: DateTime.now().add(const Duration(days: 365)),
          profitPercentage: 70,
        );
      }

      if (!mounted) return;

      setState(() {
        _wallet = mockWallet;
        _balance = mockBalance;
        _transactions = mockTransactions;
        _investmentSummary = mockInvestmentSummary;
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;

      setState(() => _isLoading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('${AppLocalizations.of(context)?.errorLoading ?? 'Error loading'}: $e')),
        );
      }
    }
  }

  Future<void> _showEditDialog() async {
    if (_wallet == null) return;

    await showDialog(
      context: context,
      builder: (context) => CreateEditWalletDialog(
        wallet: _wallet,
        onSuccess: _loadData,
      ),
    );
  }

  Future<void> _handleDelete() async {
    final l10n = AppLocalizations.of(context);
    String confirmationMessage = 'Вы уверены, что хотите удалить кошелек ${_wallet!.name}?';
    if (l10n != null) {
      confirmationMessage = l10n.deleteInvestorConfirmation(_wallet!.name);
    }

    final confirmed = await showCustomConfirmationDialog(
      context: context,
      title: l10n?.deleteInvestorTitle ?? 'Удалить кошелек',
      content: confirmationMessage,
    );

    if (confirmed == true) {
      try {
        // TODO: Delete wallet via repository
        if (mounted) {
          context.go('/wallets', extra: {'refresh': true});
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(l10n?.investorDeleted ?? 'Кошелек удален')),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(l10n?.investorDeleteError != null
                ? l10n?.investorDeleteError(e.toString()) ?? 'Ошибка при удалении: $e'
                : 'Ошибка при удалении: $e')),
          );
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);

    if (_isLoading) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    if (_wallet == null) {
      return Scaffold(
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.error_outline, size: 64, color: Colors.grey),
              const SizedBox(height: 16),
              Text(AppLocalizations.of(context)?.investorNotFound ?? 'Кошелек не найден'),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: () => context.go('/wallets'),
                child: Text(AppLocalizations.of(context)?.backToList ?? 'Вернуться к списку'),
              ),
            ],
          ),
        ),
      );
    }

    final dateFormat = DateFormat('dd.MM.yyyy');
    final currencyFormat = NumberFormat.currency(
      locale: l10n?.locale.languageCode == 'ru' ? 'ru_RU' : 'en_US',
      symbol: l10n?.locale.languageCode == 'ru' ? '₽' : '\$',
      decimalDigits: 2,
    );

    return ResponsiveLayout(
      mobile: WalletDetailsScreenMobile(
        wallet: _wallet!,
        balance: _balance,
        transactions: _transactions,
        investmentSummary: _investmentSummary,
        dateFormat: dateFormat,
        currencyFormat: currencyFormat,
        onDelete: _handleDelete,
        onEdit: _showEditDialog,
      ),
      desktop: WalletDetailsScreenDesktop(
        wallet: _wallet!,
        balance: _balance,
        transactions: _transactions,
        investmentSummary: _investmentSummary,
        dateFormat: dateFormat,
        currencyFormat: currencyFormat,
        onDelete: _handleDelete,
        onEdit: _showEditDialog,
      ),
    );
  }
}
