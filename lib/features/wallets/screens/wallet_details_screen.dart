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
import '../domain/repositories/wallet_repository.dart';
import '../data/repositories/wallet_repository_impl.dart';
import '../data/datasources/wallet_remote_datasource_impl.dart';
import '../../../core/api/api_client.dart';
import '../../../core/api/cache_service.dart';
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
  late WalletRepository _walletRepository;

  @override
  void initState() {
    super.initState();
    _initializeRepository();
  }

  void _initializeRepository() {
    _walletRepository = WalletRepositoryImpl(
      WalletRemoteDataSourceImpl(),
    );
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
    if (!mounted) {
      print('❌ _loadData: Widget not mounted');
      return;
    }

    print('📥 _loadData: Starting data load for wallet ${widget.walletId}');
    setState(() => _isLoading = true);

    try {
      // Load wallet data from repository
      print('👛 _loadData: Loading wallet data...');
      final wallet = await _walletRepository.getWalletById(widget.walletId);
      print('📊 _loadData: Wallet loaded: ${wallet?.name ?? 'null'}');

      // Debug: Print detailed wallet information
      if (wallet != null) {
        print('🔍 Wallet details:');
        print('   - Name: ${wallet.name}');
        print('   - ID: ${wallet.id}');
        print('   - Type: ${wallet.type}');
        print('   - Type enum: ${wallet.type}');
        print('   - isPersonalWallet: ${wallet.isPersonalWallet}');
        print('   - isInvestorWallet: ${wallet.isInvestorWallet}');
        print('   - Investment Amount: ${wallet.investmentAmount}');
        print('   - Investor Percentage: ${wallet.investorPercentage}');
        print('   - User Percentage: ${wallet.userPercentage}');
        print('   - Return Date: ${wallet.investmentReturnDate}');
      }

      final balance = await _walletRepository.getWalletBalance(widget.walletId);
      print('💰 _loadData: Balance loaded: ${balance?.balance ?? 'null'}');

      final transactions = await _walletRepository.getWalletTransactions(widget.walletId, limit: 50);
      print('📋 _loadData: Transactions loaded: ${transactions.length}');

      InvestmentSummary? investmentSummary;

      // Infer investor wallet robustly: prefer presence of investor fields
      final isInvestor = wallet != null && (
        wallet.type == WalletType.investor ||
        wallet.investmentAmount != null ||
        wallet.investorPercentage != null ||
        wallet.userPercentage != null ||
        wallet.investmentReturnDate != null
      );
      if (isInvestor) {
        print('📈 _loadData: Loading investment summary...');
        investmentSummary = await _walletRepository.getInvestmentSummary(widget.walletId);
        print('📈 _loadData: Investment summary loaded');
      }

      if (!mounted) {
        print('❌ _loadData: Widget unmounted after data loading');
        return;
      }

      setState(() {
        _wallet = wallet;
        _balance = balance;
        _transactions = transactions;
        _investmentSummary = investmentSummary;
        _isLoading = false;
      });

      print('✅ _loadData: Data loaded successfully');
    } catch (e) {
      print('💥 _loadData: Error loading wallet ${widget.walletId}: $e');
      if (!mounted) return;

      setState(() => _isLoading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('${AppLocalizations.of(context)?.errorLoading ?? 'Error loading'}: $e'),
            backgroundColor: AppTheme.errorColor,
          ),
        );
      }
    }
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
        await _walletRepository.deleteWallet(_wallet!.id);
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

  Future<void> _handleAddMoney() async {
    final l10n = AppLocalizations.of(context);
    // TODO: Implement add money functionality
    // For now, show a placeholder message
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l10n?.addMoney ?? 'Add Money functionality - Coming Soon!')),
      );
    }
  }

  Future<void> _handleWithdrawMoney() async {
    final l10n = AppLocalizations.of(context);
    // TODO: Implement withdraw money functionality
    // For now, show a placeholder message
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l10n?.withdrawMoney ?? 'Withdraw Money functionality - Coming Soon!')),
      );
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

    // Debug: Print wallet information
    print('🔍 WalletDetailsScreen - Wallet: ${_wallet!.name}');
    print('🔍 WalletDetailsScreen - Type: ${_wallet!.type}');
    print('🔍 WalletDetailsScreen - isPersonalWallet: ${_wallet!.isPersonalWallet}');
    print('🔍 WalletDetailsScreen - isInvestorWallet: ${_wallet!.isInvestorWallet}');

    // Infer investor robustly for UI: consider presence of investor fields
    final bool isInvestor = _wallet!.type == WalletType.investor ||
        _wallet!.investmentAmount != null ||
        _wallet!.investorPercentage != null ||
        _wallet!.userPercentage != null ||
        _wallet!.investmentReturnDate != null;

    final dateFormat = DateFormat('dd.MM.yyyy');
    final currencyFormat = NumberFormat.currency(
      locale: l10n?.locale.languageCode == 'ru' ? 'ru_RU' : 'en_US',
      symbol: l10n?.locale.languageCode == 'ru' ? '₽' : '\$',
      decimalDigits: 2,
    );

    // For investor wallets, don't provide add/withdraw handlers
    final isPersonal = !isInvestor;
    final onAddMoney = isPersonal ? _handleAddMoney : null;
    final onWithdrawMoney = isPersonal ? _handleWithdrawMoney : null;

    return ResponsiveLayout(
      mobile: WalletDetailsScreenMobile(
        wallet: _wallet!,
        balance: _balance,
        transactions: _transactions,
        investmentSummary: _investmentSummary,
        dateFormat: dateFormat,
        currencyFormat: currencyFormat,
        onDelete: _handleDelete,
        onAddMoney: onAddMoney,
        onWithdrawMoney: onWithdrawMoney,
        isInvestor: isInvestor,
      ),
      desktop: WalletDetailsScreenDesktop(
        wallet: _wallet!,
        balance: _balance,
        transactions: _transactions,
        investmentSummary: _investmentSummary,
        dateFormat: dateFormat,
        currencyFormat: currencyFormat,
        onDelete: _handleDelete,
        onAddMoney: onAddMoney,
        onWithdrawMoney: onWithdrawMoney,
        isInvestor: isInvestor,
      ),
    );
  }
}
