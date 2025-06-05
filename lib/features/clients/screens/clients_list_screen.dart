import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/localization/app_localizations.dart';
import '../domain/entities/client.dart';
import '../domain/repositories/client_repository.dart';
import '../data/repositories/client_repository_impl.dart';
import '../data/datasources/client_local_datasource.dart';
import '../../../shared/database/database_helper.dart';

class ClientsListScreen extends StatefulWidget {
  const ClientsListScreen({super.key});

  @override
  State<ClientsListScreen> createState() => _ClientsListScreenState();
}

class _ClientsListScreenState extends State<ClientsListScreen> {
  String _searchQuery = '';
  String _sortBy = 'creationDate';
  late ClientRepository _clientRepository;
  List<Client> _clients = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _initializeRepository();
    _loadData();
  }

  void _initializeRepository() {
    final db = DatabaseHelper.instance;
    _clientRepository = ClientRepositoryImpl(
      ClientLocalDataSourceImpl(db),
    );
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    try {
      // TODO: Replace with actual user ID from auth
      const userId = 'user123';
      
      final clients = await _clientRepository.getAllClients(userId);
      
      setState(() {
        _clients = clients;
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
      print('Error loading data: $e');
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
    
    return filtered;
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);

    return Scaffold(
      backgroundColor: AppTheme.backgroundColor,
      body: Column(
        children: [
          // Header with search and sort
          Container(
            padding: const EdgeInsets.all(24),
            decoration: const BoxDecoration(
              color: AppTheme.surfaceColor,
              border: Border(
                bottom: BorderSide(
                  color: AppTheme.borderColor,
                  width: 1,
                ),
              ),
            ),
            child: Column(
              children: [
                Row(
                  children: [
                    Text(
                      l10n?.clients ?? 'Клиенты',
                      style: Theme.of(context).textTheme.headlineMedium,
                    ),
                    const Spacer(),
                    // Search field
                    SizedBox(
                      width: 300,
                      height: 40,
                      child: TextField(
                        onChanged: (value) => setState(() => _searchQuery = value),
                        decoration: InputDecoration(
                          hintText: '${l10n?.search ?? 'Поиск'} ${(l10n?.clients ?? 'клиенты').toLowerCase()}...',
                          prefixIcon: const Icon(Icons.search, size: 20),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                            borderSide: const BorderSide(color: AppTheme.borderColor),
                          ),
                          contentPadding: const EdgeInsets.symmetric(horizontal: 16),
                        ),
                      ),
                    ),
                    const SizedBox(width: 16),
                    // Sort dropdown
                    Container(
                      height: 40,
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      decoration: BoxDecoration(
                        border: Border.all(color: AppTheme.borderColor),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: DropdownButton<String>(
                        value: _sortBy,
                        underline: const SizedBox(),
                        icon: const Icon(Icons.arrow_drop_down),
                        items: {
                          'creationDate': l10n?.creationDate ?? 'Дате создания',
                          'name': 'Имени',
                          'contact': 'Контакту',
                        }.entries.map((entry) {
                          return DropdownMenuItem(
                            value: entry.key,
                            child: Text(entry.value),
                          );
                        }).toList(),
                        onChanged: (value) => setState(() => _sortBy = value!),
                      ),
                    ),
                    const SizedBox(width: 16),
                    ElevatedButton.icon(
                      onPressed: () => context.go('/clients/add'),
                      icon: const Icon(Icons.add),
                      label: Text(l10n?.addClient ?? 'Добавить клиента'),
                    ),
                  ],
                ),
              ],
            ),
          ),
          // Table Header
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
            decoration: const BoxDecoration(
              color: AppTheme.surfaceColor,
              border: Border(
                bottom: BorderSide(
                  color: AppTheme.borderColor,
                  width: 1,
                ),
              ),
            ),
            child: Row(
              children: [
                Expanded(
                  flex: 3,
                  child: Text(
                    'Полное имя',
                    style: Theme.of(context).textTheme.labelLarge?.copyWith(
                          color: AppTheme.textSecondary,
                        ),
                  ),
                ),
                Expanded(
                  flex: 2,
                  child: Text(
                    'Контактный номер',
                    style: Theme.of(context).textTheme.labelLarge?.copyWith(
                          color: AppTheme.textSecondary,
                        ),
                  ),
                ),
                Expanded(
                  flex: 2,
                  child: Text(
                    'Номер паспорта',
                    style: Theme.of(context).textTheme.labelLarge?.copyWith(
                          color: AppTheme.textSecondary,
                        ),
                  ),
                ),
                Expanded(
                  flex: 2,
                  child: Text(
                    'Адрес',
                    style: Theme.of(context).textTheme.labelLarge?.copyWith(
                          color: AppTheme.textSecondary,
                        ),
                  ),
                ),
                Expanded(
                  child: Text(
                    'Дата создания',
                    style: Theme.of(context).textTheme.labelLarge?.copyWith(
                          color: AppTheme.textSecondary,
                        ),
                  ),
                ),
                const SizedBox(width: 100), // Space for actions
              ],
            ),
          ),
          // List
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _filteredAndSortedClients.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.people_outline,
                              size: 64,
                              color: AppTheme.textSecondary.withOpacity(0.5),
                            ),
                            const SizedBox(height: 16),
                            Text(
                              'Нет клиентов',
                              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                                    color: AppTheme.textSecondary,
                                  ),
                            ),
                            const SizedBox(height: 8),
                            ElevatedButton.icon(
                              onPressed: () => context.go('/clients/add'),
                              icon: const Icon(Icons.add),
                              label: const Text('Добавить первого клиента'),
                            ),
                          ],
                        ),
                      )
                    : ListView.builder(
                        padding: const EdgeInsets.only(bottom: 24),
                        itemCount: _filteredAndSortedClients.length,
                        itemBuilder: (context, index) {
                          final client = _filteredAndSortedClients[index];
                          final dateFormat = DateFormat('dd.MM.yyyy');
                          
                          return _ClientListItem(
                            client: client,
                            dateFormat: dateFormat,
                            onTap: () => context.go('/clients/${client.id}'),
                            onEdit: () => context.go('/clients/${client.id}/edit'),
                            onDelete: () => _deleteClient(client),
                          );
                        },
                      ),
          ),
        ],
      ),
    );
  }

  Future<void> _deleteClient(Client client) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Удалить клиента'),
        content: Text('Вы уверены, что хотите удалить клиента "${client.fullName}"?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Отмена'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.errorColor,
            ),
            child: const Text('Удалить'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      try {
        await _clientRepository.deleteClient(client.id);
        _loadData();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Клиент удален')),
        );
      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Ошибка удаления: $e')),
        );
      }
    }
  }
}

class _ClientListItem extends StatefulWidget {
  final Client client;
  final DateFormat dateFormat;
  final VoidCallback onTap;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  const _ClientListItem({
    required this.client,
    required this.dateFormat,
    required this.onTap,
    required this.onEdit,
    required this.onDelete,
  });

  @override
  State<_ClientListItem> createState() => _ClientListItemState();
}

class _ClientListItemState extends State<_ClientListItem> {
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      child: GestureDetector(
        onTap: widget.onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          margin: const EdgeInsets.symmetric(horizontal: 24, vertical: 1),
          decoration: BoxDecoration(
            color: _isHovered ? AppTheme.backgroundColor : AppTheme.surfaceColor,
            border: const Border(
              bottom: BorderSide(
                color: AppTheme.borderColor,
                width: 1,
              ),
            ),
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 0, vertical: 16),
            child: Row(
              children: [
                // Full Name
                Expanded(
                  flex: 3,
                  child: Text(
                    widget.client.fullName,
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          fontWeight: FontWeight.w500,
                        ),
                  ),
                ),
                // Contact Number
                Expanded(
                  flex: 2,
                  child: Text(
                    widget.client.contactNumber,
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                ),
                // Passport Number
                Expanded(
                  flex: 2,
                  child: Text(
                    widget.client.passportNumber,
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                ),
                // Address
                Expanded(
                  flex: 2,
                  child: Text(
                    widget.client.address,
                    style: Theme.of(context).textTheme.bodyMedium,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                // Created Date
                Expanded(
                  child: Text(
                    widget.dateFormat.format(widget.client.createdAt),
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: AppTheme.textSecondary,
                        ),
                  ),
                ),
                // Actions
                SizedBox(
                  width: 100,
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      IconButton(
                        onPressed: widget.onEdit,
                        icon: const Icon(Icons.edit, size: 20),
                        tooltip: 'Редактировать',
                      ),
                      IconButton(
                        onPressed: widget.onDelete,
                        icon: const Icon(Icons.delete, size: 20),
                        tooltip: 'Удалить',
                        color: AppTheme.errorColor,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
} 