import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/localization/app_localizations.dart';
import '../domain/entities/client.dart';
import '../domain/repositories/client_repository.dart';
import '../data/repositories/client_repository_impl.dart';
import '../data/datasources/client_remote_datasource.dart';
import '../../../shared/widgets/custom_search_bar.dart';
import '../../../shared/widgets/custom_dropdown.dart';
import '../../../shared/widgets/custom_button.dart';
import '../widgets/client_list_item.dart';
import '../../../shared/widgets/custom_confirmation_dialog.dart';
import '../../auth/presentation/widgets/auth_service_provider.dart';
import '../../../core/api/cache_service.dart';
import '../../../shared/widgets/create_edit_client_dialog.dart';
import '../../../shared/widgets/responsive_layout.dart';
import 'desktop/clients_list_screen_desktop.dart';
import 'mobile/clients_list_screen_mobile.dart';

class ClientsListScreen extends StatefulWidget {
  const ClientsListScreen({super.key});

  @override
  State<ClientsListScreen> createState() => ClientsListScreenState();
}

class ClientsListScreenState extends State<ClientsListScreen> with TickerProviderStateMixin {
  final searchController = TextEditingController();
  String searchQuery = '';
  String? sortBy = 'creationDate';
  late ClientRepository clientRepository;
  List<Client> clients = [];
  bool isLoading = true;
  bool isInitialized = false;
  bool isSelectionMode = false;
  final Set<String> selectedClientIds = {};
  
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
          print('Refreshing clients list because refresh parameter was true');
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
    clientRepository = ClientRepositoryImpl(
      ClientRemoteDataSourceImpl(),
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
      
      final loadedClients = await clientRepository.getAllClients(currentUser.id);
      
      if (!mounted) return;
      
      setState(() {
        clients = loadedClients;
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

  List<Client> get filteredAndSortedClients {
    var filtered = clients.where((client) {
      if (searchQuery.isEmpty) return true;
      
      final fullName = client.fullName.toLowerCase();
      final contactNumber = client.contactNumber.toLowerCase();
      final query = searchQuery.toLowerCase();
      
      return fullName.contains(query) || contactNumber.contains(query);
    }).toList();
    
    // Sort
    if (sortBy != null) {
      switch (sortBy) {
        case 'name':
          filtered.sort((a, b) => a.fullName.compareTo(b.fullName));
          break;
        case 'contact':
          filtered.sort((a, b) => a.contactNumber.compareTo(b.contactNumber));
          break;
        case 'creationDate':
        default:
          filtered.sort((a, b) => b.createdAt.compareTo(a.createdAt));
      }
    }
    
    return filtered;
  }
  
  // Selection methods
  void toggleSelection(String clientId) {
    setState(() {
      if (selectedClientIds.contains(clientId)) {
        selectedClientIds.remove(clientId);
        if (selectedClientIds.isEmpty) {
          isSelectionMode = false;
        }
      } else {
        selectedClientIds.add(clientId);
        isSelectionMode = true;
      }
    });
  }

  void selectAll() {
    setState(() {
      selectedClientIds.clear();
      selectedClientIds.addAll(filteredAndSortedClients.map((c) => c.id));
      isSelectionMode = true;
    });
  }

  void clearSelection() {
    setState(() {
      selectedClientIds.clear();
      isSelectionMode = false;
    });
  }
  
  Future<void> deleteBulkClients() async {
    if (selectedClientIds.isEmpty || !mounted) return;
    
    final l10n = AppLocalizations.of(context);
    
    // Show confirmation dialog
    final confirmed = await showCustomConfirmationDialog(
      context: context,
      title: l10n?.deleteClientTitle ?? 'Delete Client',
      content: selectedClientIds.length == 1
          ? l10n?.deleteClientConfirmation(filteredAndSortedClients.firstWhere((c) => c.id == selectedClientIds.first).fullName) ?? 'Are you sure you want to delete this client?'
          : '${l10n?.deleteClientsConfirmation ?? 'Are you sure you want to delete these clients?'} (${selectedClientIds.length})',
    );
    
    if (!mounted || confirmed != true) return;
    
    try {
      // Clear cache to ensure fresh data after deletion
      final cache = CacheService();
      final authService = AuthServiceProvider.of(context);
      final currentUser = await authService.getCurrentUser();
      
      if (!mounted) return;
      
      if (currentUser != null) {
        cache.remove(CacheService.clientsKey(currentUser.id));
        cache.remove(CacheService.analyticsKey(currentUser.id));
      }
      
      // Show loading indicator
      if (mounted) {
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
      }
      
      // Delete all selected clients
      for (final id in selectedClientIds) {
        if (!mounted) return;
        cache.remove(CacheService.clientKey(id));
        await clientRepository.deleteClient(id);
      }
      
      if (!mounted) return;
      
      // Clear the current snackbar
      ScaffoldMessenger.of(context).hideCurrentSnackBar();
      
      // Immediately remove from local state to update UI
      setState(() {
        clients.removeWhere((c) => selectedClientIds.contains(c.id));
      });
      
      // Clear selection
      clearSelection();
      
      // Also reload data from server to ensure consistency
      await loadData();
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              selectedClientIds.length == 1
                  ? l10n?.clientDeleted ?? 'Client deleted'
                  : l10n?.clientsDeleted ?? 'Clients deleted',
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
            content: Text(l10n?.clientDeleteError(e) ?? 'Error deleting: $e'),
            backgroundColor: AppTheme.errorColor,
          ),
        );
        // Reload data on error to ensure UI consistency
        await loadData();
      }
    }
  }

  // Force a complete refresh by reinitializing all data
  void forceRefresh() {
    if (!mounted) return;
    
    // Clear data and show loading
    setState(() {
      isLoading = true;
      clients = [];
      selectedClientIds.clear();
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
            print('🔄 Force-refreshing clients data from API');
            loadData();
          }
        });
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return ResponsiveLayout(
      mobile: ClientsListScreenMobile(state: this),
      desktop: ClientsListScreenDesktop(state: this),
    );
  }

  String getClientsCountText(int count) {
    final l10n = AppLocalizations.of(context)!;
    if (count % 10 == 1 && count % 100 != 11) {
      return l10n.client_one;
    } else if ([2, 3, 4].contains(count % 10) && ![12, 13, 14].contains(count % 100)) {
      return l10n.client_few;
    } else {
      return l10n.client_many;
    }
  }

  Future<void> deleteClient(Client client) async {
    if (!mounted) return;
    
    final confirmed = await showCustomConfirmationDialog(
      context: context,
      title: AppLocalizations.of(context)!.deleteClientTitle,
      content: AppLocalizations.of(context)!.deleteClientConfirmation(client.fullName),
    );

    if (!mounted) return;

    if (confirmed == true) {
      try {
        // Clear cache to ensure fresh data after deletion
        final cache = CacheService();
        final authService = AuthServiceProvider.of(context);
        final currentUser = await authService.getCurrentUser();
        
        if (!mounted) return;
        
        if (currentUser != null) {
          cache.remove(CacheService.clientsKey(currentUser.id));
          cache.remove(CacheService.analyticsKey(currentUser.id));
        }
        cache.remove(CacheService.clientKey(client.id));
        
        await clientRepository.deleteClient(client.id);
        
        if (!mounted) return;
        
        // Immediately refresh the list after deletion
        await loadData();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(AppLocalizations.of(context)!.clientDeleted),
              backgroundColor: AppTheme.successColor,
            ),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(AppLocalizations.of(context)!.clientDeleteError(e)),
              backgroundColor: AppTheme.errorColor,
            ),
          );
        }
      }
    }
  }

  void showCreateClientDialog() {
    showDialog(
      context: context,
      builder: (context) => CreateEditClientDialog(
        onSuccess: loadData,
      ),
    );
  }

  void showEditClientDialog(Client client) {
    showDialog(
      context: context,
      builder: (context) => CreateEditClientDialog(
        client: client,
        onSuccess: loadData,
      ),
    );
  }
  
  void setStateWrapper(VoidCallback fn) {
    setState(fn);
  }
} 