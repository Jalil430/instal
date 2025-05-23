import 'package:fluent_ui/fluent_ui.dart';
import '../../models/client.dart';
import '../../services/database_service.dart';
import '../../utils/theme.dart';
import 'client_details_screen.dart';
import 'add_edit_client_screen.dart';

class ClientsScreen extends StatefulWidget {
  const ClientsScreen({super.key});

  @override
  State<ClientsScreen> createState() => _ClientsScreenState();
}

class _ClientsScreenState extends State<ClientsScreen> {
  final TextEditingController _searchController = TextEditingController();
  List<Client> _clients = [];
  List<Client> _filteredClients = [];
  String _sortBy = 'creationDate';
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadClients();
    _searchController.addListener(_filterClients);
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadClients() async {
    setState(() => _isLoading = true);

    try {
      final clients = await DatabaseService.getClients();
      setState(() {
        _clients = clients;
        _filteredClients = clients;
        _isLoading = false;
      });
      _sortClients();
    } catch (e) {
      setState(() => _isLoading = false);
      if (mounted) {
        showDialog(
          context: context,
          builder: (context) => ContentDialog(
            title: const Text('Error'),
            content: Text('Failed to load clients: $e'),
            actions: [
              Button(
                child: const Text('OK'),
                onPressed: () => Navigator.of(context).pop(),
              ),
            ],
          ),
        );
      }
    }
  }

  void _filterClients() {
    final query = _searchController.text.toLowerCase();
    setState(() {
      _filteredClients = _clients.where((client) {
        return client.fullName.toLowerCase().contains(query) ||
               client.contactNumber.contains(query) ||
               client.passportNumber.toLowerCase().contains(query);
      }).toList();
      _sortClients();
    });
  }

  void _sortClients() {
    setState(() {
      switch (_sortBy) {
        case 'creationDate':
          _filteredClients.sort((a, b) => b.createdAt.compareTo(a.createdAt));
          break;
        case 'name':
          _filteredClients.sort((a, b) => a.fullName.compareTo(b.fullName));
          break;
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return ScaffoldPage(
      header: Container(
        height: 60,
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
        decoration: BoxDecoration(
          color: AppTheme.surfaceColor,
          border: Border(
            bottom: BorderSide(color: AppTheme.borderColor, width: 1),
          ),
        ),
        child: Row(
          children: [
            Expanded(
              child: TextBox(
                controller: _searchController,
                placeholder: 'Search clients...',
                prefix: const Padding(
                  padding: EdgeInsets.only(left: 8),
                  child: Icon(FluentIcons.search),
                ),
              ),
            ),
            const SizedBox(width: 12),
            ComboBox<String>(
              value: _sortBy,
              items: const [
                ComboBoxItem(value: 'creationDate', child: Text('Creation Date')),
                ComboBoxItem(value: 'name', child: Text('A-Z')),
              ],
              onChanged: (value) {
                if (value != null) {
                  setState(() => _sortBy = value);
                  _sortClients();
                }
              },
            ),
            const SizedBox(width: 12),
            FilledButton(
              child: const Text('Add Client'),
              onPressed: () async {
                await Navigator.push(
                  context,
                  FluentPageRoute(
                    builder: (context) => const AddEditClientScreen(),
                  ),
                );
                _loadClients();
              },
            ),
          ],
        ),
      ),
      content: _isLoading
          ? const Center(child: ProgressRing())
          : _filteredClients.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        FluentIcons.people,
                        size: 64,
                        color: AppTheme.textSecondaryColor,
                      ),
                      const SizedBox(height: 16),
                      Text(
                        'No clients found',
                        style: AppTheme.subtitleStyle,
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Add your first client to get started',
                        style: AppTheme.captionStyle,
                      ),
                    ],
                  ),
                )
              : ListView.builder(
                  padding: const EdgeInsets.all(20),
                  itemCount: _filteredClients.length,
                  itemBuilder: (context, index) {
                    final client = _filteredClients[index];
                    return _ClientListItem(
                      client: client,
                      onTap: () async {
                        await Navigator.push(
                          context,
                          FluentPageRoute(
                            builder: (context) => ClientDetailsScreen(
                              clientId: client.id,
                            ),
                          ),
                        );
                        _loadClients();
                      },
                      onEdit: () async {
                        await Navigator.push(
                          context,
                          FluentPageRoute(
                            builder: (context) => AddEditClientScreen(
                              client: client,
                            ),
                          ),
                        );
                        _loadClients();
                      },
                      onDelete: () async {
                        final result = await showDialog<bool>(
                          context: context,
                          builder: (context) => ContentDialog(
                            title: const Text('Delete Client'),
                            content: const Text(
                              'Are you sure you want to delete this client? This action cannot be undone.',
                            ),
                            actions: [
                              Button(
                                child: const Text('Cancel'),
                                onPressed: () => Navigator.of(context).pop(false),
                              ),
                              FilledButton(
                                child: const Text('Delete'),
                                onPressed: () => Navigator.of(context).pop(true),
                              ),
                            ],
                          ),
                        );

                        if (result == true) {
                          await DatabaseService.deleteClient(client.id);
                          _loadClients();
                        }
                      },
                    );
                  },
                ),
    );
  }
}

class _ClientListItem extends StatelessWidget {
  final Client client;
  final VoidCallback onTap;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  const _ClientListItem({
    required this.client,
    required this.onTap,
    required this.onEdit,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: AppTheme.cardDecoration,
      child: GestureDetector(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: AppTheme.primaryColor.withOpacity(0.1),
                  shape: BoxShape.circle,
                ),
                child: Center(
                  child: Text(
                    client.fullName.isNotEmpty 
                        ? client.fullName[0].toUpperCase()
                        : '?',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w600,
                      color: AppTheme.primaryColor,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      client.fullName,
                      style: AppTheme.subtitleStyle,
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        Icon(
                          FluentIcons.phone,
                          size: 12,
                          color: AppTheme.textSecondaryColor,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          client.contactNumber,
                          style: AppTheme.captionStyle,
                        ),
                        const SizedBox(width: 16),
                        Icon(
                          FluentIcons.contact_card,
                          size: 12,
                          color: AppTheme.textSecondaryColor,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          client.passportNumber,
                          style: AppTheme.captionStyle,
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              IconButton(
                icon: const Icon(FluentIcons.edit),
                onPressed: onEdit,
              ),
              IconButton(
                icon: const Icon(FluentIcons.delete),
                onPressed: onDelete,
              ),
            ],
          ),
        ),
      ),
    );
  }
} 