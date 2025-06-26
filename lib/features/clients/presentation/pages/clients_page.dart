import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../../core/themes/app_theme.dart';
import '../providers/client_provider.dart';
import '../screens/add_client_screen.dart';
import '../screens/client_details_screen.dart';
import '../widgets/client_list_item.dart';

class ClientsPage extends StatefulWidget {
  const ClientsPage({super.key});

  @override
  State<ClientsPage> createState() => _ClientsPageState();
}

class _ClientsPageState extends State<ClientsPage> {
  final TextEditingController _searchController = TextEditingController();
  ClientSortOption _currentSortOption = ClientSortOption.createdDateNewest;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadClients();
    });
    _searchController.addListener(_onSearchChanged);
  }

  @override
  void dispose() {
    _searchController.removeListener(_onSearchChanged);
    _searchController.dispose();
    super.dispose();
  }

  void _loadClients() {
    final clientProvider = Provider.of<ClientProvider>(context, listen: false);
    clientProvider.loadClients('user_1'); // TODO: Replace with actual user ID
  }

  void _onSearchChanged() {
    final clientProvider = Provider.of<ClientProvider>(context, listen: false);
    clientProvider.searchClients('user_1', _searchController.text);
  }

  void _onSortChanged(ClientSortOption? option) {
    if (option != null) {
      setState(() {
        _currentSortOption = option;
      });
      final clientProvider = Provider.of<ClientProvider>(context, listen: false);
      clientProvider.sortClients(option);
    }
  }

  void _navigateToAddClient() {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => const AddClientScreen(),
      ),
    ).then((_) {
      // Refresh clients list when returning from add client screen
      _loadClients();
    });
  }
  
  void _navigateToClientDetails(String clientId) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => ClientDetailsScreen(
          clientId: clientId,
        ),
      ),
    ).then((_) {
      // Refresh clients list when returning from details screen
      _loadClients();
    });
  }
  
  void _navigateToEditClient(String clientId) {
    final client = Provider.of<ClientProvider>(context, listen: false)
        .clients
        .firstWhere((client) => client.id == clientId);
        
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => AddClientScreen(
          initialClient: client,
        ),
      ),
    ).then((_) {
      // Refresh clients list when returning from edit screen
      _loadClients();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.backgroundColor,
      body: Column(
        children: [
          // Top Bar
          Container(
            height: 72,
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
            decoration: const BoxDecoration(
              color: AppTheme.surfaceColor,
              border: Border(
                bottom: BorderSide(
                  color: AppTheme.dividerColor,
                  width: 1,
                ),
              ),
            ),
            child: Row(
              children: [
                Text(
                  'Клиенты',
                  style: Theme.of(context).textTheme.headlineLarge,
                ),
                const Spacer(),
                SizedBox(
                  width: 400,
                  child: TextField(
                    controller: _searchController,
                    decoration: const InputDecoration(
                      hintText: 'Поиск клиентов...',
                      prefixIcon: Icon(Icons.search),
                    ),
                  ),
                ),
                const SizedBox(width: 16),
                // Sort Dropdown
                DropdownButton<ClientSortOption>(
                  value: _currentSortOption,
                  onChanged: _onSortChanged,
                  items: const [
                    DropdownMenuItem(
                      value: ClientSortOption.nameAZ,
                      child: Text('Имя А-Я'),
                    ),
                    DropdownMenuItem(
                      value: ClientSortOption.nameZA,
                      child: Text('Имя Я-А'),
                    ),
                    DropdownMenuItem(
                      value: ClientSortOption.createdDateNewest,
                      child: Text('Новые'),
                    ),
                    DropdownMenuItem(
                      value: ClientSortOption.createdDateOldest,
                      child: Text('Старые'),
                    ),
                  ],
                ),
                const SizedBox(width: 16),
                ElevatedButton.icon(
                  onPressed: _navigateToAddClient,
                  icon: const Icon(Icons.add, size: 20),
                  label: const Text('Добавить клиента'),
                ),
              ],
            ),
          ),
          
          // Content Area
          Expanded(
            child: Container(
              color: AppTheme.backgroundColor,
              child: Consumer<ClientProvider>(
                builder: (context, clientProvider, child) {
                  if (clientProvider.isLoading) {
                    return const Center(
                      child: CircularProgressIndicator(),
                    );
                  }

                  if (clientProvider.error != null) {
                    return Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.error_outline,
                            size: 64,
                            color: AppTheme.textTertiary,
                          ),
                          const SizedBox(height: 16),
                          Text(
                            'Ошибка загрузки',
                            style: Theme.of(context).textTheme.titleLarge?.copyWith(
                              color: AppTheme.textSecondary,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            clientProvider.error!,
                            style: Theme.of(context).textTheme.bodyMedium,
                            textAlign: TextAlign.center,
                          ),
                          const SizedBox(height: 16),
                          ElevatedButton(
                            onPressed: _loadClients,
                            child: const Text('Повторить'),
                          ),
                        ],
                      ),
                    );
                  }

                  if (!clientProvider.hasClients) {
                    return Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.people_outline,
                            size: 64,
                            color: AppTheme.textTertiary,
                          ),
                          const SizedBox(height: 16),
                          Text(
                            'Клиенты не найдены',
                            style: Theme.of(context).textTheme.titleLarge?.copyWith(
                              color: AppTheme.textSecondary,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'Добавьте первого клиента для создания рассрочек',
                            style: Theme.of(context).textTheme.bodyMedium,
                          ),
                          const SizedBox(height: 24),
                          ElevatedButton.icon(
                            onPressed: _navigateToAddClient,
                            icon: const Icon(Icons.add),
                            label: const Text('Добавить клиента'),
                          ),
                        ],
                      ),
                    );
                  }

                  return ListView.builder(
                    padding: const EdgeInsets.all(24),
                    itemCount: clientProvider.clients.length,
                    itemBuilder: (context, index) {
                      final client = clientProvider.clients[index];
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 12),
                        child: ClientListItem(
                          client: client,
                          onTap: () {
                            _navigateToClientDetails(client.id);
                          },
                          onEdit: () {
                            _navigateToEditClient(client.id);
                          },
                          onDelete: () {
                            _showDeleteConfirmation(client.id);
                          },
                        ),
                      );
                    },
                  );
                },
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _showDeleteConfirmation(String clientId) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Удалить клиента'),
        content: const Text('Вы уверены, что хотите удалить этого клиента?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Отмена'),
          ),
          TextButton(
            onPressed: () {
              Navigator.of(context).pop();
              final clientProvider = Provider.of<ClientProvider>(context, listen: false);
              clientProvider.deleteClient(clientId, 'user_1');
            },
            child: const Text('Удалить'),
          ),
        ],
      ),
    );
  }
} 