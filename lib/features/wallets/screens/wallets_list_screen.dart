import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/localization/app_localizations.dart';
import '../domain/entities/wallet.dart';
import '../domain/entities/wallet_balance.dart';
import '../domain/repositories/wallet_repository.dart';
import '../../../shared/widgets/custom_search_bar.dart';
import '../../../shared/widgets/custom_dropdown.dart';
import '../../../shared/widgets/custom_button.dart';
import '../widgets/wallet_list_item.dart';
import '../../../shared/widgets/custom_confirmation_dialog.dart';
import '../../auth/presentation/widgets/auth_service_provider.dart';
import '../../../core/api/cache_service.dart';
import '../widgets/create_edit_wallet_dialog.dart';
import '../../../shared/widgets/responsive_layout.dart';
import 'desktop/wallets_list_screen_desktop.dart';
import 'mobile/wallets_list_screen_mobile.dart';

class WalletsListScreen extends StatefulWidget {
  const WalletsListScreen({super.key});

  @override
  State<WalletsListScreen> createState() => WalletsListScreenState();
}

class WalletsListScreenState extends State<WalletsListScreen> with TickerProviderStateMixin {
  final searchController = TextEditingController();
  String searchQuery = '';
  String? sortBy = 'creationDate';
  late WalletRepository walletRepository;
  List<Wallet> wallets = [];
  Map<String, WalletBalance> walletBalances = {};
  bool isLoading = true;
  bool isInitialized = false;
  bool isSelectionMode = false;
  final Set<String> selectedWalletIds = {};

  late AnimationController fadeController;
  late Animation<double> fadeAnimation;

  @override
  void initState() {
    super.initState();
    fadeController = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );
    fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: fadeController, curve: Curves.easeInOut),
    );

    initializeRepository();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!isInitialized) {
      loadData();
      isInitialized = true;
    }

    // Check if we need to refresh the data (e.g., coming back from details page)
    try {
      final GoRouterState goState = GoRouterState.of(context);
      if (goState.extra != null && goState.extra is Map<String, dynamic>) {
        final Map<String, dynamic> extra = goState.extra as Map<String, dynamic>;
        if (extra['refresh'] == true) {
          Future.delayed(Duration.zero, () {
            if (mounted) {
              loadData();
            }
          });
        }
      }
    } catch (e) {
      print('Error checking navigation extras: $e');
    }
  }

  @override
  void dispose() {
    fadeController.dispose();
    super.dispose();
  }

  void initializeRepository() {
    // TODO: Initialize with actual repository implementation
    // walletRepository = WalletRepositoryImpl(WalletRemoteDataSourceImpl());
  }

  Future<void> loadData() async {
    if (!mounted) return;
    setState(() => isLoading = true);

    try {
      // Get current user from authentication
      final authService = AuthServiceProvider.of(context);
      final currentUser = await authService.getCurrentUser();

      if (!mounted) return;

      if (currentUser == null) {
        if (mounted) {
          context.go('/auth/login');
        }
        return;
      }

      // TODO: Load wallets and balances from repository
      // final loadedWallets = await walletRepository.getAllWallets(currentUser.id);
      // final balances = await walletRepository.getAllWalletBalances(currentUser.id);

      // Mock data for now
      final mockWallets = [
        Wallet(
          id: '1',
          userId: currentUser.id,
          name: 'My Wallet',
          type: WalletType.personal,
          createdAt: DateTime.now().subtract(const Duration(days: 30)),
          updatedAt: DateTime.now(),
        ),
        Wallet(
          id: '2',
          userId: currentUser.id,
          name: 'Investor A',
          type: WalletType.investor,
          investmentAmount: 1000000,
          investorPercentage: 70,
          userPercentage: 30,
          investmentReturnDate: DateTime.now().add(const Duration(days: 365)),
          createdAt: DateTime.now().subtract(const Duration(days: 15)),
          updatedAt: DateTime.now(),
        ),
      ];

      final mockBalances = {
        '1': WalletBalance(
          walletId: '1',
          userId: currentUser.id,
          balanceMinorUnits: 50000000, // 500,000 RUB
          version: 1,
          updatedAt: DateTime.now(),
        ),
        '2': WalletBalance(
          walletId: '2',
          userId: currentUser.id,
          balanceMinorUnits: 345000000, // 3,450,000 RUB
          version: 1,
          updatedAt: DateTime.now(),
        ),
      };

      if (!mounted) return;

      setState(() {
        wallets = mockWallets;
        walletBalances = mockBalances;
        isLoading = false;
      });

      if (mounted) {
        fadeController.forward();
      }
    } catch (e) {
      if (!mounted) return;

      setState(() => isLoading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('${AppLocalizations.of(context)?.errorLoadingData ?? 'Error loading data'}: $e')),
        );
      }
    }
  }

  List<Wallet> get filteredAndSortedWallets {
    var filtered = wallets.where((wallet) {
      if (searchQuery.isEmpty) return true;

      final name = wallet.name.toLowerCase();
      final query = searchQuery.toLowerCase();

      return name.contains(query);
    }).toList();

    // Sort
    if (sortBy != null) {
      switch (sortBy) {
        case 'name':
          filtered.sort((a, b) => a.name.compareTo(b.name));
          break;
        case 'balance':
          filtered.sort((a, b) {
            final balanceA = walletBalances[a.id]?.balance ?? 0;
            final balanceB = walletBalances[b.id]?.balance ?? 0;
            return balanceB.compareTo(balanceA);
          });
          break;
        case 'type':
          filtered.sort((a, b) => a.type.name.compareTo(b.type.name));
          break;
        case 'creationDate':
        default:
          filtered.sort((a, b) => b.createdAt.compareTo(a.createdAt));
      }
    }

    return filtered;
  }

  // Selection methods
  void toggleSelection(String walletId) {
    setState(() {
      if (selectedWalletIds.contains(walletId)) {
        selectedWalletIds.remove(walletId);
        if (selectedWalletIds.isEmpty) {
          isSelectionMode = false;
        }
      } else {
        selectedWalletIds.add(walletId);
        isSelectionMode = true;
      }
    });
  }

  void selectAll() {
    setState(() {
      selectedWalletIds.clear();
      selectedWalletIds.addAll(filteredAndSortedWallets.map((w) => w.id));
      isSelectionMode = true;
    });
  }

  void clearSelection() {
    setState(() {
      selectedWalletIds.clear();
      isSelectionMode = false;
    });
  }

  Future<void> deleteBulkWallets() async {
    if (selectedWalletIds.isEmpty) return;

    final l10n = AppLocalizations.of(context);

    // Show confirmation dialog
    final confirmed = await showCustomConfirmationDialog(
      context: context,
      title: l10n?.deleteInvestorTitle ?? 'Delete Wallet',
      content: selectedWalletIds.length == 1
          ? '${l10n?.deleteInvestorConfirmation ?? 'Are you sure you want to delete this wallet?'}'
          : '${l10n?.deleteInvestorsConfirmation ?? 'Are you sure you want to delete these wallets?'} (${selectedWalletIds.length})',
    );

    if (confirmed != true) return;

    try {
      // Clear cache to ensure fresh data after deletion
      final cache = CacheService();
      final authService = AuthServiceProvider.of(context);
      final currentUser = await authService.getCurrentUser();

      if (currentUser != null) {
        cache.remove(CacheService.walletsKey(currentUser.id));
      }

      // Show loading indicator
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                ),
              ),
              const SizedBox(width: 16),
              Text(l10n?.deleting ?? 'Deleting...'),
            ],
          ),
          duration: const Duration(seconds: 60),
        ),
      );

      // Delete all selected wallets
      for (final id in selectedWalletIds) {
        cache.remove(CacheService.walletKey(id));
        // TODO: await walletRepository.deleteWallet(id);
      }

      // Clear the current snackbar
      ScaffoldMessenger.of(context).hideCurrentSnackBar();

      // Immediately remove from local state to update UI
      setState(() {
        wallets.removeWhere((w) => selectedWalletIds.contains(w.id));
      });

      // Clear selection
      clearSelection();

      // Also reload data from server to ensure consistency
      loadData();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              selectedWalletIds.length == 1
                  ? l10n?.investorDeleted ?? 'Wallet deleted'
                  : l10n?.investorsDeleted ?? 'Wallets deleted',
            ),
            backgroundColor: AppTheme.successColor,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).hideCurrentSnackBar();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(l10n?.investorDeleteError(e) ?? 'Error deleting: $e'),
            backgroundColor: AppTheme.errorColor,
          ),
        );
        // Reload data on error to ensure UI consistency
        loadData();
      }
    }
  }

  void showCreateWalletDialog() {
    showDialog(
      context: context,
      builder: (context) => CreateEditWalletDialog(
        onSuccess: loadData,
      ),
    );
  }

  void showEditWalletDialog(Wallet wallet) {
    showDialog(
      context: context,
      builder: (context) => CreateEditWalletDialog(
        wallet: wallet,
        onSuccess: loadData,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return ResponsiveLayout(
      mobile: WalletsListScreenMobile(state: this),
      desktop: WalletsListScreenDesktop(state: this),
    );
  }

  String getWalletsCountText(int count) {
    final l10n = AppLocalizations.of(context);
    if (l10n == null) return '';

    // Use wallet count text or fallback to generic
    try {
      if (count % 10 == 1 && count % 100 != 11) {
        return l10n.investor_one; // Using investor localization as fallback
      } else if ([2, 3, 4].contains(count % 10) && ![12, 13, 14].contains(count % 100)) {
        return l10n.investor_few;
      } else {
        return l10n.investor_many;
      }
    } catch (e) {
      return ''; // Return empty string if localization fails
    }
  }

  void forceRefresh() {
    setStateWrapper(() {
      isLoading = true;
    });
    loadData();
  }

  String formatCurrency(double amount) {
    // Simple currency formatting - you can enhance this with proper localization
    return '${amount.toStringAsFixed(2).replaceAll('.', ',')} ₽';
  }

  Future<void> deleteWallet(Wallet wallet) async {
    final confirmed = await showCustomConfirmationDialog(
      context: context,
      title: AppLocalizations.of(context)!.deleteInvestorTitle,
      content: AppLocalizations.of(context)!.deleteInvestorConfirmation(wallet.name),
    );

    if (confirmed == true) {
      try {
        // Clear cache to ensure fresh data after deletion
        final cache = CacheService();
        final authService = AuthServiceProvider.of(context);
        final currentUser = await authService.getCurrentUser();

        if (currentUser != null) {
          cache.remove(CacheService.walletsKey(currentUser.id));
        }
        cache.remove(CacheService.walletKey(wallet.id));

        // TODO: await walletRepository.deleteWallet(wallet.id);
        await loadData();

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(AppLocalizations.of(context)!.investorDeleted),
              backgroundColor: AppTheme.successColor,
            ),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(AppLocalizations.of(context)!.investorDeleteError(e)),
              backgroundColor: AppTheme.errorColor,
            ),
          );
        }
      }
    }
  }

  void setStateWrapper(VoidCallback fn) {
    setState(fn);
  }
}
