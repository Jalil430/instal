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

class ClientsListScreen extends StatefulWidget {
  const ClientsListScreen({super.key});

  @override
  State<ClientsListScreen> createState() => _ClientsListScreenState();
}

class _ClientsListScreenState extends State<ClientsListScreen> with TickerProviderStateMixin {
  final _searchController = TextEditingController();
  String _searchQuery = '';
  String? _sortBy = 'creationDate';
  late ClientRepository _clientRepository;
  List<Client> _clients = [];
  bool _isLoading = true;
  bool _isInitialized = false;
  
  late AnimationController _fadeController;
  late Animation<double> _fadeAnimation;

  @override
  void initState() {
    super.initState();
    _fadeController = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );
    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _fadeController, curve: Curves.easeInOut),
    );
    
    _initializeRepository();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_isInitialized) {
      _loadData();
      _isInitialized = true;
    }
  }

  @override
  void dispose() {
    _fadeController.dispose();
    super.dispose();
  }

  void _initializeRepository() {
    _clientRepository = ClientRepositoryImpl(
      ClientRemoteDataSourceImpl(),
    );
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    try {
      // Get current user from authentication
      final authService = AuthServiceProvider.of(context);
      final currentUser = await authService.getCurrentUser();
      
      if (currentUser == null) {
        // Redirect to login if not authenticated
        if (mounted) {
          context.go('/auth/login');
        }
        return;
      }
      
      final clients = await _clientRepository.getAllClients(currentUser.id);
      
      setState(() {
        _clients = clients;
        _isLoading = false;
      });
      
      _fadeController.forward();
    } catch (e) {
      setState(() => _isLoading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('${AppLocalizations.of(context)?.errorLoadingData ?? 'Error loading data'}: $e')),
        );
      }
    }
  }

  List<Client> get _filteredAndSortedClients {
    var filtered = _clients.where((client) {
      if (_searchQuery.isEmpty) return true;
      
      final fullName = client.fullName.toLowerCase();
      final contactNumber = client.contactNumber.toLowerCase();
      final query = _searchQuery.toLowerCase();
      
      return fullName.contains(query) || contactNumber.contains(query);
    }).toList();
    
    // Sort
    if (_sortBy != null) {
      switch (_sortBy) {
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

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);

    return Scaffold(
      backgroundColor: AppTheme.backgroundColor,
      body: Column(
        children: [
          // Enhanced Header with search and sort
          Container(
            padding: const EdgeInsets.fromLTRB(32, 28, 32, 20),
            decoration: const BoxDecoration(
              color: AppTheme.surfaceColor,
            ),
            child: Column(
              children: [
                // Title and Actions Row
                Row(
                  children: [
                    // Title without Icon
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          l10n?.clients ?? 'Клиенты',
                          style: const TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.w600,
                            letterSpacing: -0.5,
                          ),
                        ),
                        Text(
                          '${_filteredAndSortedClients.length} ${_getClientsCountText(_filteredAndSortedClients.length)}',
                          style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w400,
                            color: AppTheme.textSecondary,
                          ),
                        ),
                      ],
                    ),
                    const Spacer(),
                    // Enhanced Search field
                    CustomSearchBar(
                      value: _searchQuery,
                      onChanged: (value) => setState(() => _searchQuery = value),
                      hintText: '${l10n?.search ?? 'Поиск'} ${(l10n?.clients ?? 'клиенты').toLowerCase()}...',
                      width: 320,
                    ),
                    const SizedBox(width: 16),
                    // Enhanced Sort dropdown
                    CustomDropdown<String>(
                      value: _sortBy,
                      width: 200,
                      items: {
                        'creationDate': l10n?.creationDate ?? 'Дата создания',
                        'name': l10n?.sortByName ?? 'Имени',
                        'contact': l10n?.sortByContact ?? 'Контакту',
                      },
                      onChanged: (value) => setState(() => _sortBy = value),
                    ),
                    const SizedBox(width: 16),
                    // Custom Add button
                    CustomButton(
                      text: l10n?.addClient ?? 'Добавить клиента',
                      onPressed: () => context.go('/clients/add'),
                    ),
                  ],
                ),
              ],
            ),
          ),
          
          // Continuous Table Section
          Expanded(
            child: Container(
              color: AppTheme.surfaceColor,
              child: _isLoading
                  ? Center(
                      child: Container(
                        padding: const EdgeInsets.all(20),
                        child: CircularProgressIndicator(
                          strokeWidth: 3,
                          valueColor: AlwaysStoppedAnimation<Color>(AppTheme.brightPrimaryColor),
                        ),
                      ),
                    )
                  : Container(
                      margin: const EdgeInsets.symmetric(horizontal: 16),
                      decoration: BoxDecoration(
                        color: AppTheme.surfaceColor,
                        borderRadius: BorderRadius.circular(12),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.02),
                            offset: const Offset(0, 1),
                            blurRadius: 3,
                            spreadRadius: 0,
                          ),
                        ],
                      ),
                      child: Column(
                        children: [
                          // Table Header
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
                            decoration: BoxDecoration(
                              color: AppTheme.subtleBackgroundColor,
                              borderRadius: const BorderRadius.only(
                                topLeft: Radius.circular(12),
                                topRight: Radius.circular(12),
                              ),
                              border: Border(
                                bottom: BorderSide(
                                  color: AppTheme.subtleBorderColor,
                                  width: 1,
                                ),
                              ),
                            ),
                            child: Row(
                              children: [
                                Expanded(
                                  flex: 3,
                                  child: Text(
                                    l10n?.fullNameHeader ?? 'ПОЛНОЕ ИМЯ',
                                    style: Theme.of(context).textTheme.labelMedium?.copyWith(
                                          color: AppTheme.textSecondary,
                                          fontWeight: FontWeight.w400,
                                          fontSize: 12,
                                          letterSpacing: 0.5,
                                        ),
                                  ),
                                ),
                                Expanded(
                                  flex: 2,
                                  child: Text(
                                    l10n?.contactNumberHeader ?? 'КОНТАКТНЫЙ НОМЕР',
                                    style: Theme.of(context).textTheme.labelMedium?.copyWith(
                                          color: AppTheme.textSecondary,
                                          fontWeight: FontWeight.w400,
                                          fontSize: 12,
                                          letterSpacing: 0.5,
                                        ),
                                  ),
                                ),
                                Expanded(
                                  flex: 2,
                                  child: Text(
                                    l10n?.passportNumberHeader ?? 'НОМЕР ПАСПОРТА',
                                    style: Theme.of(context).textTheme.labelMedium?.copyWith(
                                          color: AppTheme.textSecondary,
                                          fontWeight: FontWeight.w400,
                                          fontSize: 12,
                                          letterSpacing: 0.5,
                                        ),
                                  ),
                                ),
                                Expanded(
                                  flex: 2,
                                  child: Text(
                                    l10n?.addressHeader ?? 'АДРЕС',
                                    style: Theme.of(context).textTheme.labelMedium?.copyWith(
                                          color: AppTheme.textSecondary,
                                          fontWeight: FontWeight.w400,
                                          fontSize: 12,
                                          letterSpacing: 0.5,
                                        ),
                                  ),
                                ),
                                Expanded(
                                  child: Text(
                                    l10n?.creationDateHeader ?? 'ДАТА СОЗДАНИЯ',
                                    style: Theme.of(context).textTheme.labelMedium?.copyWith(
                                          color: AppTheme.textSecondary,
                                          fontWeight: FontWeight.w400,
                                          fontSize: 12,
                                          letterSpacing: 0.5,
                                        ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          
                          // Table Content
                          Expanded(
                            child: _filteredAndSortedClients.isEmpty
                                ? Center(
                                    child: Text(
                                      l10n?.notFound ?? 'Ничего не найдено',
                                      style: TextStyle(
                                        color: AppTheme.textSecondary,
                                        fontSize: 16,
                                        fontWeight: FontWeight.w400,
                                      ),
                                    ),
                                  )
                                : ListView.builder(
                                    padding: EdgeInsets.zero,
                                    itemCount: _filteredAndSortedClients.length,
                                    itemBuilder: (context, index) {
                                      final client = _filteredAndSortedClients[index];
                                      return ClientListItem(
                                        client: client,
                                        onTap: () => context.go('/clients/${client.id}'),
                                        onEdit: () => context.go('/clients/${client.id}/edit'),
                                        onDelete: () => _deleteClient(client),
                                        onSelect: () {
                                          print('Selected client: \'${client.fullName}\'');
                                        },
                                      );
                                    },
                                  ),
                          ),
                        ],
                      ),
                    ),
            ),
          ),
        ],
      ),
    );
  }

  String _getClientsCountText(int count) {
    final l10n = AppLocalizations.of(context)!;
    if (count % 10 == 1 && count % 100 != 11) {
      return l10n.client_one;
    } else if ([2, 3, 4].contains(count % 10) && ![12, 13, 14].contains(count % 100)) {
      return l10n.client_few;
    } else {
      return l10n.client_many;
    }
  }

  Future<void> _deleteClient(Client client) async {
    final confirmed = await showCustomConfirmationDialog(
      context: context,
      title: AppLocalizations.of(context)!.deleteClientTitle,
      content: AppLocalizations.of(context)!.deleteClientConfirmation(client.fullName),
    );

    if (confirmed == true) {
      try {
        // Clear cache to ensure fresh data after deletion
        final cache = CacheService();
        final authService = AuthServiceProvider.of(context);
        final currentUser = await authService.getCurrentUser();
        
        if (currentUser != null) {
          cache.remove(CacheService.clientsKey(currentUser.id));
          cache.remove(CacheService.analyticsKey(currentUser.id));
        }
        cache.remove(CacheService.clientKey(client.id));
        
        await _clientRepository.deleteClient(client.id);
        // Immediately refresh the list after deletion
        await _loadData();
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
} 