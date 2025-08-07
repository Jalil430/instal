import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/localization/app_localizations.dart';
import '../domain/entities/investor.dart';
import '../domain/repositories/investor_repository.dart';
import '../data/repositories/investor_repository_impl.dart';
import '../data/datasources/investor_remote_datasource.dart';
import '../../../shared/widgets/custom_search_bar.dart';
import '../../../shared/widgets/custom_dropdown.dart';
import '../../../shared/widgets/custom_button.dart';
import '../widgets/investor_list_item.dart';
import '../../../shared/widgets/custom_confirmation_dialog.dart';
import '../../auth/presentation/widgets/auth_service_provider.dart';
import '../../../core/api/cache_service.dart';
import '../../../shared/widgets/create_edit_investor_dialog.dart';
import '../../../shared/widgets/responsive_layout.dart';
import 'desktop/investors_list_screen_desktop.dart';
import 'mobile/investors_list_screen_mobile.dart';

class InvestorsListScreen extends StatefulWidget {
  const InvestorsListScreen({super.key});

  @override
  State<InvestorsListScreen> createState() => InvestorsListScreenState();
}

class InvestorsListScreenState extends State<InvestorsListScreen> with TickerProviderStateMixin {
  final searchController = TextEditingController();
  String searchQuery = '';
  String? sortBy = 'creationDate';
  late InvestorRepository investorRepository;
  List<Investor> investors = [];
  bool isLoading = true;
  bool isInitialized = false;
  bool isSelectionMode = false;
  final Set<String> selectedInvestorIds = {};
  
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
        print('Got navigation extra: $extra');
        if (extra['refresh'] == true) {
          print('Refreshing investors list because refresh parameter was true');
          // Add a small delay to ensure the widget tree is built
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
    investorRepository = InvestorRepositoryImpl(
      InvestorRemoteDataSourceImpl(),
    );
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
        // Redirect to login if not authenticated
        if (mounted) {
          context.go('/auth/login');
        }
        return;
      }
      
      final loadedInvestors = await investorRepository.getAllInvestors(currentUser.id);
      
      if (!mounted) return;
      
      setState(() {
        investors = loadedInvestors;
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

  List<Investor> get filteredAndSortedInvestors {
    var filtered = investors.where((investor) {
      if (searchQuery.isEmpty) return true;
      
      final fullName = investor.fullName.toLowerCase();
      final query = searchQuery.toLowerCase();
      
      return fullName.contains(query);
    }).toList();
    
    // Sort
    if (sortBy != null) {
      switch (sortBy) {
        case 'name':
          filtered.sort((a, b) => a.fullName.compareTo(b.fullName));
          break;
        case 'investment':
          filtered.sort((a, b) => b.investmentAmount.compareTo(a.investmentAmount));
          break;
        case 'creationDate':
        default:
          filtered.sort((a, b) => b.createdAt.compareTo(a.createdAt));
      }
    }
    
    return filtered;
  }
  
  // Selection methods
  void toggleSelection(String investorId) {
    setState(() {
      if (selectedInvestorIds.contains(investorId)) {
        selectedInvestorIds.remove(investorId);
        if (selectedInvestorIds.isEmpty) {
          isSelectionMode = false;
        }
      } else {
        selectedInvestorIds.add(investorId);
        isSelectionMode = true;
      }
    });
  }

  void selectAll() {
    setState(() {
      selectedInvestorIds.clear();
      selectedInvestorIds.addAll(filteredAndSortedInvestors.map((i) => i.id));
      isSelectionMode = true;
    });
  }

  void clearSelection() {
    setState(() {
      selectedInvestorIds.clear();
      isSelectionMode = false;
    });
  }
  
  Future<void> deleteBulkInvestors() async {
    if (selectedInvestorIds.isEmpty) return;
    
    final l10n = AppLocalizations.of(context);
    
    // Show confirmation dialog
    final confirmed = await showCustomConfirmationDialog(
      context: context,
      title: l10n?.deleteInvestorTitle ?? 'Delete Investor',
      content: selectedInvestorIds.length == 1
          ? l10n?.deleteInvestorConfirmation(filteredAndSortedInvestors.firstWhere((i) => i.id == selectedInvestorIds.first).fullName) ?? 'Are you sure you want to delete this investor?'
          : '${l10n?.deleteInvestorsConfirmation ?? 'Are you sure you want to delete these investors?'} (${selectedInvestorIds.length})',
    );
    
    if (confirmed != true) return;
    
    try {
      // Clear cache to ensure fresh data after deletion
      final cache = CacheService();
      final authService = AuthServiceProvider.of(context);
      final currentUser = await authService.getCurrentUser();
      
      if (currentUser != null) {
        cache.remove(CacheService.investorsKey(currentUser.id));
        cache.remove(CacheService.analyticsKey(currentUser.id));
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
      
      // Delete all selected investors
      for (final id in selectedInvestorIds) {
        cache.remove(CacheService.investorKey(id));
        await investorRepository.deleteInvestor(id);
      }
      
      // Clear the current snackbar
      ScaffoldMessenger.of(context).hideCurrentSnackBar();
      
      // Immediately remove from local state to update UI
      setState(() {
        investors.removeWhere((i) => selectedInvestorIds.contains(i.id));
      });
      
      // Clear selection
      clearSelection();
      
      // Also reload data from server to ensure consistency
      loadData();
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              selectedInvestorIds.length == 1
                  ? l10n?.investorDeleted ?? 'Investor deleted'
                  : l10n?.investorsDeleted ?? 'Investors deleted',
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

  // Force a complete refresh by reinitializing all data
  void forceRefresh() {
    if (!mounted) return;
    
    // Clear data and show loading
    setState(() {
      isLoading = true;
      investors = [];
      selectedInvestorIds.clear();
    });
    
    // First clear the cache to ensure fresh data from API
    final cacheService = CacheService();
    // Get current user to build cache key
    AuthServiceProvider.of(context).getCurrentUser().then((user) {
      if (user != null) {
        // Clear all related caches
        cacheService.clear(); // Clear entire cache to be safe
        print('🔄 Cache cleared for full refresh');
        
        // Wait a moment before reloading to ensure UI shows loading state
        Future.delayed(Duration(milliseconds: 300), () {
          if (mounted) {
            print('🔄 Force-refreshing investors data from API');
            loadData();
          }
        });
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return ResponsiveLayout(
      mobile: InvestorsListScreenMobile(state: this),
      desktop: InvestorsListScreenDesktop(state: this),
    );
  }

  String getInvestorsCountText(int count) {
    final l10n = AppLocalizations.of(context)!;
    if (count % 10 == 1 && count % 100 != 11) {
      return l10n.investor_one;
    } else if ([2, 3, 4].contains(count % 10) && ![12, 13, 14].contains(count % 100)) {
      return l10n.investor_few;
    } else {
      return l10n.investor_many;
    }
  }

  Future<void> deleteInvestor(Investor investor) async {
    final confirmed = await showCustomConfirmationDialog(
      context: context,
      title: AppLocalizations.of(context)!.deleteInvestorTitle,
      content: AppLocalizations.of(context)!.deleteInvestorConfirmation(investor.fullName),
    );

    if (confirmed == true) {
      try {
        // Clear cache to ensure fresh data after deletion
        final cache = CacheService();
        final authService = AuthServiceProvider.of(context);
        final currentUser = await authService.getCurrentUser();
        
        if (currentUser != null) {
          cache.remove(CacheService.investorsKey(currentUser.id));
          cache.remove(CacheService.analyticsKey(currentUser.id));
        }
        cache.remove(CacheService.investorKey(investor.id));
        
        await investorRepository.deleteInvestor(investor.id);
        // Immediately refresh the list after deletion
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

  void showCreateInvestorDialog() {
    showDialog(
      context: context,
      builder: (context) => CreateEditInvestorDialog(
        onSuccess: loadData,
      ),
    );
  }

  void showEditInvestorDialog(Investor investor) {
    showDialog(
      context: context,
      builder: (context) => CreateEditInvestorDialog(
        investor: investor,
        onSuccess: loadData,
      ),
    );
  }
  
  void setStateWrapper(VoidCallback fn) {
    setState(fn);
  }
} 