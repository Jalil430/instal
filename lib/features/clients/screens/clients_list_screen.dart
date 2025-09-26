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

class ClientsListScreenState extends State<ClientsListScreen>
    with TickerProviderStateMixin {
  final searchController = TextEditingController();
  String searchQuery = '';
  String sortBy = 'creationDate';
  bool sortAscending = false;
  String guarantorFilter = 'all';
  String creationFilter = 'any';
  late ClientRepository clientRepository;
  List<Client> clients = [];
  bool isLoading = true;
  bool isInitialized = false;
  bool isSelectionMode = false;
  final Set<String> selectedClientIds = {};
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

  bool _matchesCreationFilter(Client client) {
    final now = DateTime.now();
    final created = client.createdAt;
    switch (creationFilter) {
      case 'last7':
        return created.isAfter(now.subtract(const Duration(days: 7)));
      case 'last30':
        return created.isAfter(now.subtract(const Duration(days: 30)));
      case 'thisMonth':
        final monthStart = DateTime(now.year, now.month);
        return !created.isBefore(monthStart);
      case 'thisYear':
        final yearStart = DateTime(now.year);
        return !created.isBefore(yearStart);
      default:
        return true;
    }
  }

  int _compareClients(Client a, Client b) {
    switch (sortBy) {
      case 'name':
        return a.fullName.toLowerCase().compareTo(b.fullName.toLowerCase());
      case 'contact':
        return a.contactNumber.compareTo(b.contactNumber);
      case 'recentlyUpdated':
        return a.updatedAt.compareTo(b.updatedAt);
      case 'creationDate':
      default:
        return a.createdAt.compareTo(b.createdAt);
    }
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
    searchController.dispose();
    fadeController.dispose();
    super.dispose();
  }

  void initializeRepository() {
    clientRepository = ClientRepositoryImpl(ClientRemoteDataSourceImpl());
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

      final loadedClients = await clientRepository.getAllClients(
        currentUser.id,
      );

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
          SnackBar(
            content: Text(
              '${AppLocalizations.of(context)?.errorLoadingData ?? 'Error loading data'}: $e',
            ),
          ),
        );
      }
    }
  }

  Map<String, String> getSortOptions() {
    final l10n = AppLocalizations.of(context);
    return {
      'creationDate': l10n?.creationDate ?? 'Дата создания',
      'recentlyUpdated': l10n?.recentlyUpdated ?? 'Недавно обновлен',
      'name': l10n?.sortByName ?? 'Имени',
      'contact': l10n?.sortByContact ?? 'Контакту',
    };
  }

  Map<String, String> getGuarantorFilterOptions() {
    final l10n = AppLocalizations.of(context);
    return {
      'all': l10n?.all ?? 'Все',
      'withGuarantor': l10n?.withGuarantor ?? 'С поручителем',
      'withoutGuarantor': l10n?.withoutGuarantor ?? 'Без поручителя',
    };
  }

  Map<String, String> getCreationFilterOptions() {
    final l10n = AppLocalizations.of(context);
    return {
      'any': l10n?.anyTime ?? 'За все время',
      'last7': l10n?.last7Days ?? 'Последние 7 дней',
      'last30': l10n?.last30Days ?? 'Последние 30 дней',
      'thisMonth': l10n?.thisMonth ?? 'Этот месяц',
      'thisYear': l10n?.thisYear ?? 'Этот год',
    };
  }

  bool get hasActiveFilters =>
      searchQuery.isNotEmpty ||
      guarantorFilter != 'all' ||
      creationFilter != 'any';

  void resetFilters() {
    setState(() {
      searchQuery = '';
      guarantorFilter = 'all';
      creationFilter = 'any';
      sortBy = 'creationDate';
      sortAscending = false;
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

  void setGuarantorFilter(String value) {
    setState(() {
      guarantorFilter = value;
    });
  }

  void setCreationFilter(String value) {
    setState(() {
      creationFilter = value;
    });
  }

  void setSortBy(String value) {
    setState(() {
      if (sortBy == value) {
        sortAscending = !sortAscending;
      } else {
        sortBy = value;
        sortAscending = value == 'name' || value == 'contact';
      }
    });
  }

  void setSortAscending(bool value) {
    if (sortAscending == value) return;
    setState(() {
      sortAscending = value;
    });
  }

  List<Client> get filteredAndSortedClients {
    final query = searchQuery.trim().toLowerCase();

    var filtered =
        clients.where((client) {
          if (query.isEmpty) return true;

          final fullName = client.fullName.toLowerCase();
          final contactNumber = client.contactNumber.toLowerCase();

          return fullName.contains(query) || contactNumber.contains(query);
        }).toList();

    if (guarantorFilter != 'all') {
      filtered =
          filtered.where((client) {
            final hasGuarantor =
                (client.guarantorFullName?.isNotEmpty ?? false) ||
                (client.guarantorContactNumber?.isNotEmpty ?? false);
            if (guarantorFilter == 'withGuarantor') {
              return hasGuarantor;
            }
            return !hasGuarantor;
          }).toList();
    }

    if (creationFilter != 'any') {
      filtered =
          filtered.where((client) => _matchesCreationFilter(client)).toList();
    }

    filtered.sort((a, b) {
      final comparison = _compareClients(a, b);
      return sortAscending ? comparison : -comparison;
    });

    return filtered;
  }

  ClientsListMetrics get metrics =>
      ClientsListMetrics.fromClients(filteredAndSortedClients);

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
      content:
          selectedClientIds.length == 1
              ? l10n?.deleteClientConfirmation(
                    filteredAndSortedClients
                        .firstWhere((c) => c.id == selectedClientIds.first)
                        .fullName,
                  ) ??
                  'Are you sure you want to delete this client?'
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

      // Show loading indicator (ensure any existing is hidden first)
      if (mounted) {
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
      }

      // Mark all as busy
      setState(() {
        loadingItemOperations.addAll(selectedClientIds);
      });

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
        loadingItemOperations.removeAll(selectedClientIds);
      });

      // Clear selection
      clearSelection();

      // Keep list persistent without full reload

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
        // Keep current list; show error only
      }
    } finally {
      if (mounted) {
        ScaffoldMessenger.of(context).hideCurrentSnackBar();
        setState(() {
          loadingItemOperations.removeAll(selectedClientIds);
        });
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
    } else if ([2, 3, 4].contains(count % 10) &&
        ![12, 13, 14].contains(count % 100)) {
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
      content: AppLocalizations.of(
        context,
      )!.deleteClientConfirmation(client.fullName),
    );

    if (!mounted) return;

    if (confirmed == true) {
      try {
        // Ensure any previous progress snackbar is hidden
        ScaffoldMessenger.of(context).hideCurrentSnackBar();
        setState(() {
          loadingItemOperations.add(client.id);
        });
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

        // Remove from local state without full reload
        setState(() {
          clients.removeWhere((c) => c.id == client.id);
          selectedClientIds.remove(client.id);
          if (selectedClientIds.isEmpty) {
            isSelectionMode = false;
          }
        });
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
          ScaffoldMessenger.of(context).hideCurrentSnackBar();
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(AppLocalizations.of(context)!.clientDeleteError(e)),
              backgroundColor: AppTheme.errorColor,
            ),
          );
        }
      } finally {
        if (mounted) {
          ScaffoldMessenger.of(context).hideCurrentSnackBar();
          setState(() {
            loadingItemOperations.remove(client.id);
          });
        }
      }
    }
  }

  void showCreateClientDialog() {
    showDialog(
      context: context,
      builder: (context) => CreateEditClientDialog(onSuccess: loadData),
    );
  }

  void showEditClientDialog(Client client) {
    showDialog(
      context: context,
      builder:
          (context) =>
              CreateEditClientDialog(client: client, onSuccess: loadData),
    );
  }

  void setStateWrapper(VoidCallback fn) {
    setState(fn);
  }
}

class ClientsListMetrics {
  final int total;
  final int withGuarantor;
  final int withoutContact;
  final int addedThisMonth;

  const ClientsListMetrics({
    required this.total,
    required this.withGuarantor,
    required this.withoutContact,
    required this.addedThisMonth,
  });

  factory ClientsListMetrics.fromClients(List<Client> clients) {
    var withGuarantor = 0;
    var withoutContact = 0;
    var addedThisMonth = 0;
    final now = DateTime.now();
    final monthStart = DateTime(now.year, now.month);

    for (final client in clients) {
      final hasGuarantor =
          (client.guarantorFullName?.isNotEmpty ?? false) ||
          (client.guarantorContactNumber?.isNotEmpty ?? false);
      if (hasGuarantor) {
        withGuarantor++;
      }

      if (client.contactNumber.isEmpty) {
        withoutContact++;
      }

      if (!client.createdAt.isBefore(monthStart)) {
        addedThisMonth++;
      }
    }

    return ClientsListMetrics(
      total: clients.length,
      withGuarantor: withGuarantor,
      withoutContact: withoutContact,
      addedThisMonth: addedThisMonth,
    );
  }
}
