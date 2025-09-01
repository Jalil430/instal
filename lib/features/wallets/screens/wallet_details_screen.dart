import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/num_format.dart';
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
import '../widgets/wallet_dialogs.dart';
import '../../../shared/widgets/responsive_layout.dart';
import 'desktop/wallet_details_screen_desktop.dart';
import 'mobile/wallet_details_screen_mobile.dart';
import '../../installments/domain/entities/installment.dart';
import '../../installments/domain/repositories/installment_repository.dart';
import '../../installments/data/repositories/installment_repository_impl.dart';
import '../../installments/data/datasources/installment_remote_datasource.dart';
import '../../auth/presentation/widgets/auth_service_provider.dart';

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
  List<Installment> _installments = [];
  bool _installmentsLoading = false;
  bool _isLoading = true;
  bool _isInitialized = false;
  late WalletRepository _walletRepository;
  late InstallmentRepository _installmentRepository;

  @override
  void initState() {
    super.initState();
    _initializeRepository();
  }

  void _initializeRepository() {
    _walletRepository = WalletRepositoryImpl(
      WalletRemoteDataSourceImpl(),
    );
    _installmentRepository = InstallmentRepositoryImpl(
      InstallmentRemoteDataSourceImpl(),
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

      // Hide transactions history: do not load transactions list
      final transactions = <LedgerTransaction>[];
      print('📋 _loadData: Transactions loading skipped (hidden)');

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

      // Defer installments loading to after first frame
      Future.microtask(_loadInstallments);

      if (!mounted) {
        print('❌ _loadData: Widget unmounted after data loading');
        return;
      }

      setState(() {
        _wallet = wallet;
        _balance = balance;
        _transactions = transactions;
        _investmentSummary = investmentSummary;
        // Ensure state update for installments as well
        // _installments already set above
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

  Future<void> _loadInstallments() async {
    if (!mounted) return;
    setState(() => _installmentsLoading = true);
    try {
      // Prefer direct query by wallet_id, then defensively filter on client-side
      final fetched = await _installmentRepository.getInstallmentsByWalletId(widget.walletId);
      List<Installment> linked = fetched.where((i) => (i.walletId ?? '').trim() == widget.walletId).toList();
      print('🧾 _loadInstallments: fetched=${fetched.length}, linked after filter=${linked.length} for wallet ${widget.walletId}');

      // Fallback: derive from wallet ledger transactions (reference_type == installment)
      if (linked.isEmpty && _transactions.isNotEmpty) {
        try {
          final ids = _transactions
              .where((t) => t.referenceType.name == 'installment' && (t.referenceId ?? '').isNotEmpty)
              .map((t) => t.referenceId!)
              .toSet()
              .toList();
          final List<Installment> viaLedger = [];
          for (final id in ids) {
            try {
              final inst = await _installmentRepository.getInstallmentById(id);
              if (inst != null) viaLedger.add(inst);
            } catch (e) {
              print('⚠️ _loadInstallments: failed to load installment $id from ledger ref: $e');
            }
          }
          // Filter again by wallet id if present; otherwise keep all from ledger
          final viaLedgerFiltered = viaLedger.where((i) => (i.walletId ?? '').isEmpty || (i.walletId ?? '').trim() == widget.walletId).toList();
          linked = viaLedgerFiltered;
          print('🧾 _loadInstallments: derived ${linked.length} installments via ledger references');
        } catch (e) {
          print('⚠️ _loadInstallments ledger fallback error: $e');
        }
      }

      if (mounted) setState(() => _installments = linked);
    } catch (e) {
      print('⚠️ _loadInstallments: $e');
    } finally {
      if (mounted) setState(() => _installmentsLoading = false);
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
    if (_wallet == null) return;
    final wallet = _wallet!;
    final l10n = AppLocalizations.of(context);
    final currencyFormat = NumberFormat.currency(
      locale: l10n?.locale.languageCode == 'ru' ? 'ru_RU' : 'en_US',
      symbol: l10n?.locale.languageCode == 'ru' ? '₽' : '\$',
      decimalDigits: 2,
    );
    await AddMoneyDialog.show(
      context: context,
      wallet: wallet,
      currencyFormat: currencyFormat,
      onConfirm: (amount) async {
        try {
          final mu = (amount * 100).round();
          await _walletRepository.topUpWallet(wallet.id, mu, 'Manual top-up');
          await _loadData();
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(l10n?.walletUpdatedSuccess ?? 'Wallet updated successfully')));
          }
        } catch (e) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('${l10n?.error ?? 'Error'}: $e'), backgroundColor: AppTheme.errorColor));
          }
        }
      },
    );
  }

  Future<void> _handleWithdrawMoney() async {
    if (_wallet == null) return;
    final wallet = _wallet!;
    final l10n = AppLocalizations.of(context);
    final balance = _balance?.balance ?? 0;
    final currencyFormat = NumberFormat.currency(
      locale: l10n?.locale.languageCode == 'ru' ? 'ru_RU' : 'en_US',
      symbol: l10n?.locale.languageCode == 'ru' ? '₽' : '\$',
      decimalDigits: 2,
    );
    await WithdrawMoneyDialog.show(
      context: context,
      wallet: wallet,
      currentBalance: balance,
      currencyFormat: currencyFormat,
      onConfirm: (amount) async {
        try {
          final mu = (amount * 100).round();
          await _walletRepository.withdrawWallet(wallet.id, mu, 'Manual withdraw');
          await _loadData();
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(l10n?.walletUpdatedSuccess ?? 'Wallet updated successfully')));
          }
        } catch (e) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('${l10n?.error ?? 'Error'}: $e'), backgroundColor: AppTheme.errorColor));
          }
        }
      },
    );
  }

  Future<void> _handleArchiveToggle() async {
    if (_wallet == null) return;
    final w = _wallet!;
    final isArchived = w.status == WalletStatus.archived;
    try {
      if (isArchived) {
        await _walletRepository.unarchiveWallet(w.id);
      } else {
        await _walletRepository.archiveWallet(w.id);
      }
      await _loadData();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(isArchived
                ? (AppLocalizations.of(context)?.unarchived ?? 'Unarchived')
                : (AppLocalizations.of(context)?.archived ?? 'Archived')),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('${AppLocalizations.of(context)?.error ?? 'Error'}: $e'),
            backgroundColor: AppTheme.errorColor,
          ),
        );
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
    final isActive = _wallet!.status == WalletStatus.active;
    final onAddMoney = (isPersonal && isActive) ? _handleAddMoney : null;
    final onWithdrawMoney = (isPersonal && isActive) ? _handleWithdrawMoney : null;

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
        installments: _installments,
        onArchiveToggle: _handleArchiveToggle,
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
        installments: _installments,
        installmentsLoading: _installmentsLoading,
        onArchiveToggle: _handleArchiveToggle,
      ),
    );
  }
}
