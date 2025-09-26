import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/localization/app_localizations.dart';
import '../domain/entities/wallet.dart';
import '../domain/entities/wallet_balance.dart';
import '../domain/repositories/wallet_repository.dart';
import '../data/repositories/wallet_repository_impl.dart';
import '../data/datasources/wallet_remote_datasource_impl.dart';
import '../../../core/api/api_client.dart';
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

class WalletsListScreenState extends State<WalletsListScreen>
    with TickerProviderStateMixin {
  final searchController = TextEditingController();
  String searchQuery = '';
  String sortBy = 'creationDate';
  bool sortAscending = false;
  String statusFilter = 'active';
  String typeFilter = 'all';
  String balanceFilter = 'any';
  late WalletRepository walletRepository;
  List<Wallet> wallets = [];
  Map<String, WalletBalance> walletBalances = {};
  bool isLoading = true;
  bool isInitialized = false;
  bool isSelectionMode = false;
  final Set<String> selectedWalletIds = {};
  final Set<String> loadingItemOperations =
      {}; // Track per-item background operations (delete)

  late AnimationController fadeController;
  late Animation<double> fadeAnimation;

  @override
  void initState() {
    super.initState();
    fadeController = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );
    fadeAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(parent: fadeController, curve: Curves.easeInOut));

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
        final Map<String, dynamic> extra =
            goState.extra as Map<String, dynamic>;
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
    searchController.dispose();
    fadeController.dispose();
    super.dispose();
  }

  void initializeRepository() {
    walletRepository = WalletRepositoryImpl(WalletRemoteDataSourceImpl());
  }

  Future<void> loadData() async {
    if (!mounted) {
      print('❌ loadData: Widget not mounted');
      return;
    }

    print('📥 loadData: Starting data load');

    // Ensure loading state is set
    setStateWrapper(() => isLoading = true);

    try {
      // Get current user from authentication
      final authService = AuthServiceProvider.of(context);
      final currentUser = await authService.getCurrentUser();

      if (!mounted) {
        print('❌ loadData: Widget unmounted after getting user');
        return;
      }

      if (currentUser == null) {
        print('⚠️ loadData: No current user found');
        setStateWrapper(() => isLoading = false);
        if (mounted) {
          context.go('/auth/login');
        }
        return;
      }

      print('👤 loadData: Loading wallets for user: ${currentUser.id}');

      // Load wallets from repository (includes balances in the response)
      final loadedWallets = await walletRepository.getAllWallets(
        currentUser.id,
      );

      if (!mounted) {
        print('❌ loadData: Widget unmounted after loading wallets');
        return;
      }

      print('📦 loadData: Loaded ${loadedWallets.length} wallets');

      // Load wallet balances
      print('💰 loadData: Loading wallet balances for user: ${currentUser.id}');
      Map<String, WalletBalance> balanceMap = {};
      try {
        final loadedBalances = await walletRepository.getAllWalletBalances(
          currentUser.id,
        );

        if (!mounted) {
          print('❌ loadData: Widget unmounted after loading balances');
          return;
        }

        print('💰 loadData: Loaded ${loadedBalances.length} wallet balances');
        // Create a map of wallet ID to balance for easy lookup
        balanceMap = {
          for (var balance in loadedBalances) balance.walletId: balance,
        };
      } catch (balanceError) {
        print('⚠️ loadData: Error loading wallet balances: $balanceError');
        // Continue with empty balance map - wallets will still be displayed without balances
        balanceMap = {};
      }

      setStateWrapper(() {
        wallets = loadedWallets;
        walletBalances = balanceMap;
        isLoading = false;
      });

      if (mounted) {
        fadeController.forward();
        print('✅ loadData: Data loaded successfully, loading=false');
      }
    } catch (e) {
      print('❌ loadData: Error loading data: $e');
      if (!mounted) return;

      setStateWrapper(() => isLoading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              '${AppLocalizations.of(context)?.errorLoadingData ?? 'Error loading data'}: $e',
            ),
            backgroundColor: AppTheme.errorColor,
          ),
        );
      }
    }
  }

  Map<String, String> getSortOptions() {
    final l10n = AppLocalizations.of(context);
    return {
      'creationDate': l10n?.creationDate ?? 'Дата создания',
      'updatedAt': l10n?.recentlyUpdated ?? 'Недавно обновлен',
      'name': l10n?.sortByName ?? 'Имени',
      'balance': l10n?.walletBalance ?? 'Баланс кошелька',
      'type': l10n?.walletType ?? 'Тип',
    };
  }

  Map<String, String> getStatusFilterOptions() {
    final l10n = AppLocalizations.of(context);
    return {
      'active': l10n?.active ?? 'Активные',
      'archived': l10n?.archived ?? 'Архив',
      'all': l10n?.all ?? 'Все',
    };
  }

  Map<String, String> getTypeFilterOptions() {
    final l10n = AppLocalizations.of(context);
    return {
      'all': l10n?.all ?? 'Все',
      'personal': l10n?.personalWallet ?? 'Личный кошелек',
      'investor': l10n?.investorWallet ?? 'Инвестиционный кошелек',
    };
  }

  Map<String, String> getBalanceFilterOptions() {
    final l10n = AppLocalizations.of(context);
    return {
      'any': l10n?.all ?? 'Все',
      'positive': l10n?.positiveBalance ?? 'Положительный баланс',
      'zero': l10n?.zeroBalance ?? 'Нулевой баланс',
      'negative': l10n?.negativeBalance ?? 'Отрицательный баланс',
    };
  }

  bool get hasActiveFilters =>
      searchQuery.isNotEmpty ||
      statusFilter != 'active' ||
      typeFilter != 'all' ||
      balanceFilter != 'any';

  void resetFilters() {
    setState(() {
      searchQuery = '';
      sortBy = 'creationDate';
      sortAscending = false;
      statusFilter = 'active';
      typeFilter = 'all';
      balanceFilter = 'any';
    });
    searchController.text = '';
  }

  void setSearchQuery(String value) {
    if (searchQuery == value) {
      if (searchController.text != value) {
        searchController.text = value;
        searchController.selection = TextSelection.fromPosition(
          TextPosition(offset: value.length),
        );
      }
      return;
    }

    setState(() {
      searchQuery = value;
      if (searchController.text != value) {
        searchController.text = value;
        searchController.selection = TextSelection.fromPosition(
          TextPosition(offset: value.length),
        );
      }
    });
  }

  void setStatusFilter(String value) {
    setState(() {
      statusFilter = value;
    });
  }

  void setTypeFilter(String value) {
    setState(() {
      typeFilter = value;
    });
  }

  void setBalanceFilter(String value) {
    setState(() {
      balanceFilter = value;
    });
  }

  void setSortBy(String value) {
    setState(() {
      if (sortBy == value) {
        sortAscending = !sortAscending;
      } else {
        sortBy = value;
        sortAscending = value == 'name' || value == 'balance';
      }
    });
  }

  void setSortAscending(bool value) {
    if (sortAscending == value) return;
    setState(() {
      sortAscending = value;
    });
  }

  List<Wallet> get filteredAndSortedWallets {
    final query = searchQuery.trim().toLowerCase();

    var filtered =
        wallets.where((wallet) {
          if (query.isEmpty) return true;

          final name = wallet.name.toLowerCase();
          return name.contains(query);
        }).toList();

    filtered =
        filtered.where((wallet) {
          switch (statusFilter) {
            case 'archived':
              return wallet.status == WalletStatus.archived;
            case 'all':
              return true;
            case 'active':
            default:
              return wallet.status == WalletStatus.active;
          }
        }).toList();

    if (typeFilter != 'all') {
      filtered =
          filtered
              .where(
                (wallet) =>
                    typeFilter == 'personal'
                        ? wallet.isPersonalWallet
                        : wallet.isInvestorWallet,
              )
              .toList();
    }

    if (balanceFilter != 'any') {
      filtered =
          filtered.where((wallet) {
            final balance = walletBalances[wallet.id]?.balance ?? 0;
            switch (balanceFilter) {
              case 'positive':
                return balance > 0.0;
              case 'negative':
                return balance < 0.0;
              case 'zero':
                return balance == 0.0;
              default:
                return true;
            }
          }).toList();
    }

    filtered.sort((a, b) {
      final comparison = _compareWallets(a, b);
      return sortAscending ? comparison : -comparison;
    });

    return filtered;
  }

  int _compareWallets(Wallet a, Wallet b) {
    switch (sortBy) {
      case 'name':
        return a.name.toLowerCase().compareTo(b.name.toLowerCase());
      case 'type':
        return a.type.name.compareTo(b.type.name);
      case 'balance':
        final balanceA = walletBalances[a.id]?.balance ?? 0;
        final balanceB = walletBalances[b.id]?.balance ?? 0;
        return balanceA.compareTo(balanceB);
      case 'updatedAt':
        return a.updatedAt.compareTo(b.updatedAt);
      case 'creationDate':
      default:
        return a.createdAt.compareTo(b.createdAt);
    }
  }

  WalletsListMetrics get metrics =>
      WalletsListMetrics.fromWallets(filteredAndSortedWallets, walletBalances);

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
      content:
          selectedWalletIds.length == 1
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
        cache.remove(CacheService.walletBalancesKey(currentUser.id));
      }

      // Show loading indicator (ensure any existing is hidden first)
      ScaffoldMessenger.of(context).hideCurrentSnackBar();
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

      // Mark selected as busy
      setStateWrapper(() {
        loadingItemOperations.addAll(selectedWalletIds);
      });

      // Delete all selected wallets
      for (final id in selectedWalletIds) {
        cache.remove(CacheService.walletKey(id));
        await walletRepository.deleteWallet(id);
      }

      // Clear the current snackbar
      ScaffoldMessenger.of(context).hideCurrentSnackBar();

      // Immediately remove from local state to update UI
      setStateWrapper(() {
        wallets.removeWhere((w) => selectedWalletIds.contains(w.id));
        for (final id in selectedWalletIds) {
          walletBalances.remove(id);
        }
        loadingItemOperations.removeAll(selectedWalletIds);
      });

      // Clear selection
      clearSelection();

      // Keep list persistent without full reload

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
        // Keep list persistent without full reload
        setStateWrapper(() {
          loadingItemOperations.removeAll(selectedWalletIds);
        });
      }
    } finally {
      if (mounted) {
        ScaffoldMessenger.of(context).hideCurrentSnackBar();
      }
    }
  }

  void showCreateWalletDialog() {
    showDialog(
      context: context,
      builder:
          (context) => CreateEditWalletDialog(
            onSuccess: () async {
              // Clear cache to ensure fresh data after wallet creation
              final cache = CacheService();
              final authService = AuthServiceProvider.of(context);
              final currentUser = await authService.getCurrentUser();

              if (currentUser != null) {
                cache.remove(CacheService.walletsKey(currentUser.id));
                cache.remove(CacheService.walletBalancesKey(currentUser.id));
              }

              // Clear repository cache as well
              walletRepository.clearCache();

              // Reload data immediately after wallet creation
              await loadData();
            },
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
        return l10n.wallet_one; // Using investor localization as fallback
      } else if ([2, 3, 4].contains(count % 10) &&
          ![12, 13, 14].contains(count % 100)) {
        return l10n.wallet_few;
      } else {
        return l10n.wallet_many;
      }
    } catch (e) {
      return ''; // Return empty string if localization fails
    }
  }

  Future<void> forceRefresh() async {
    print('🔄 Force refresh started');

    // Clear cache to force fresh data
    final cache = CacheService();
    final authService = AuthServiceProvider.of(context);
    final currentUser = await authService.getCurrentUser();

    if (currentUser != null) {
      cache.remove(CacheService.walletsKey(currentUser.id));
      cache.remove(CacheService.walletBalancesKey(currentUser.id));
      print('🗑️ Global and balance cache cleared for user: ${currentUser.id}');
    } else {
      print('⚠️ No current user found');
    }

    // Clear repository cache as well
    walletRepository.clearCache();
    print('🗑️ Repository cache cleared');

    // Reset loading state and reload data
    if (mounted) {
      setStateWrapper(() {
        isLoading = true;
        // Clear current data to show loading state
        wallets.clear();
        walletBalances.clear();
      });
      print('📊 Loading state set, data cleared');
    }

    print('🔄 Calling loadData...');
    await loadData();
    print('✅ Force refresh completed');
  }

  String formatCurrency(double amount) {
    // Simple currency formatting - you can enhance this with proper localization
    return '${amount.toStringAsFixed(2).replaceAll('.', ',')} ₽';
  }

  Future<void> deleteWallet(Wallet wallet) async {
    final confirmed = await showCustomConfirmationDialog(
      context: context,
      title: AppLocalizations.of(context)!.deleteInvestorTitle,
      content: AppLocalizations.of(
        context,
      )!.deleteInvestorConfirmation(wallet.name),
    );

    if (confirmed == true) {
      try {
        ScaffoldMessenger.of(context).hideCurrentSnackBar();
        setStateWrapper(() {
          loadingItemOperations.add(wallet.id);
        });
        // Clear cache to ensure fresh data after deletion
        final cache = CacheService();
        final authService = AuthServiceProvider.of(context);
        final currentUser = await authService.getCurrentUser();

        if (currentUser != null) {
          cache.remove(CacheService.walletsKey(currentUser.id));
          cache.remove(CacheService.walletBalancesKey(currentUser.id));
        }
        cache.remove(CacheService.walletKey(wallet.id));

        await walletRepository.deleteWallet(wallet.id);
        // Remove from local state without full reload
        setStateWrapper(() {
          wallets.removeWhere((w) => w.id == wallet.id);
          walletBalances.remove(wallet.id);
          selectedWalletIds.remove(wallet.id);
          if (selectedWalletIds.isEmpty) {
            isSelectionMode = false;
          }
        });

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
          ScaffoldMessenger.of(context).hideCurrentSnackBar();
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                AppLocalizations.of(context)!.investorDeleteError(e),
              ),
              backgroundColor: AppTheme.errorColor,
            ),
          );
        }
      } finally {
        if (mounted) {
          ScaffoldMessenger.of(context).hideCurrentSnackBar();
          setStateWrapper(() {
            loadingItemOperations.remove(wallet.id);
          });
        }
      }
    }
  }

  void setStateWrapper(VoidCallback fn) {
    setState(fn);
  }
}

class WalletsListMetrics {
  final int total;
  final int activeCount;
  final int archivedCount;
  final double totalBalance;
  final double totalAllocated;
  final double totalDue;

  const WalletsListMetrics({
    required this.total,
    required this.activeCount,
    required this.archivedCount,
    required this.totalBalance,
    required this.totalAllocated,
    required this.totalDue,
  });

  factory WalletsListMetrics.fromWallets(
    List<Wallet> wallets,
    Map<String, WalletBalance> balances,
  ) {
    var activeCount = 0;
    var archivedCount = 0;
    var totalBalance = 0.0;
    var totalAllocated = 0.0;
    var totalDue = 0.0;

    for (final wallet in wallets) {
      if (wallet.status == WalletStatus.archived) {
        archivedCount++;
      } else if (wallet.status == WalletStatus.active) {
        activeCount++;
      }

      final balance = balances[wallet.id];
      if (balance != null) {
        totalBalance += balance.balance;
        totalAllocated += balance.totalAllocated;
        totalDue += balance.dueToGet;
      }
    }

    return WalletsListMetrics(
      total: wallets.length,
      activeCount: activeCount,
      archivedCount: archivedCount,
      totalBalance: totalBalance,
      totalAllocated: totalAllocated,
      totalDue: totalDue,
    );
  }
}
