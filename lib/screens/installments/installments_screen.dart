import 'package:fluent_ui/fluent_ui.dart';
import '../../models/installment.dart';
import '../../models/client.dart';
import '../../models/investor.dart';
import '../../services/database_service.dart';
import '../../utils/theme.dart';
import 'installment_details_screen.dart';
import 'add_installment_screen.dart';
import 'package:intl/intl.dart';

class InstallmentsScreen extends StatefulWidget {
  const InstallmentsScreen({super.key});

  @override
  State<InstallmentsScreen> createState() => _InstallmentsScreenState();
}

class _InstallmentsScreenState extends State<InstallmentsScreen> {
  final TextEditingController _searchController = TextEditingController();
  List<Installment> _installments = [];
  List<Installment> _filteredInstallments = [];
  Map<String, Client> _clientsMap = {};
  Map<String, Investor> _investorsMap = {};
  String _sortBy = 'creationDate';
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadData();
    _searchController.addListener(_filterInstallments);
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    
    try {
      final installments = await DatabaseService.getInstallments();
      final clients = await DatabaseService.getClients();
      final investors = await DatabaseService.getInvestors();
      
      setState(() {
        _installments = installments;
        _filteredInstallments = installments;
        _clientsMap = {for (var client in clients) client.id: client};
        _investorsMap = {for (var investor in investors) investor.id: investor};
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
      if (mounted) {
        showDialog(
          context: context,
          builder: (context) => ContentDialog(
            title: const Text('Error'),
            content: Text('Failed to load data: $e'),
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

  void _filterInstallments() {
    final query = _searchController.text.toLowerCase();
    setState(() {
      _filteredInstallments = _installments.where((installment) {
        final client = _clientsMap[installment.clientId];
        final clientName = client?.fullName.toLowerCase() ?? '';
        final productName = installment.productName.toLowerCase();
        return clientName.contains(query) || productName.contains(query);
      }).toList();
      _sortInstallments();
    });
  }

  void _sortInstallments() {
    setState(() {
      switch (_sortBy) {
        case 'creationDate':
          _filteredInstallments.sort((a, b) => b.createdAt.compareTo(a.createdAt));
          break;
        case 'amount':
          _filteredInstallments.sort((a, b) => b.installmentPrice.compareTo(a.installmentPrice));
          break;
        case 'client':
          _filteredInstallments.sort((a, b) {
            final clientA = _clientsMap[a.clientId]?.fullName ?? '';
            final clientB = _clientsMap[b.clientId]?.fullName ?? '';
            return clientA.compareTo(clientB);
          });
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
                placeholder: 'Search installments...',
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
                ComboBoxItem(value: 'amount', child: Text('Amount')),
                ComboBoxItem(value: 'client', child: Text('Client')),
              ],
              onChanged: (value) {
                if (value != null) {
                  setState(() => _sortBy = value);
                  _sortInstallments();
                }
              },
            ),
            const SizedBox(width: 12),
            FilledButton(
              child: const Text('Add Installment'),
              onPressed: () async {
                await Navigator.push(
                  context,
                  FluentPageRoute(builder: (context) => const AddInstallmentScreen()),
                );
                _loadData();
              },
            ),
          ],
        ),
      ),
      content: _isLoading
          ? const Center(child: ProgressRing())
          : _filteredInstallments.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        FluentIcons.document,
                        size: 64,
                        color: AppTheme.textSecondaryColor,
                      ),
                      const SizedBox(height: 16),
                      Text(
                        'No installments found',
                        style: AppTheme.subtitleStyle,
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Add your first installment to get started',
                        style: AppTheme.captionStyle,
                      ),
                    ],
                  ),
                )
              : ListView.builder(
                  padding: const EdgeInsets.all(20),
                  itemCount: _filteredInstallments.length,
                  itemBuilder: (context, index) {
                    final installment = _filteredInstallments[index];
                    final client = _clientsMap[installment.clientId];
                    
                    return _InstallmentListItem(
                      installment: installment,
                      client: client,
                      onTap: () async {
                        await Navigator.push(
                          context,
                          FluentPageRoute(
                            builder: (context) => InstallmentDetailsScreen(
                              installmentId: installment.id,
                            ),
                          ),
                        );
                        _loadData();
                      },
                      onDelete: () async {
                        final result = await showDialog<bool>(
                          context: context,
                          builder: (context) => ContentDialog(
                            title: const Text('Delete Installment'),
                            content: const Text('Are you sure you want to delete this installment?'),
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
                          await DatabaseService.deleteInstallment(installment.id);
                          _loadData();
                        }
                      },
                    );
                  },
                ),
    );
  }
}

class _InstallmentListItem extends StatelessWidget {
  final Installment installment;
  final Client? client;
  final VoidCallback onTap;
  final VoidCallback onDelete;

  const _InstallmentListItem({
    required this.installment,
    required this.client,
    required this.onTap,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final currencyFormat = NumberFormat.currency(symbol: '\$', decimalDigits: 2);
    final totalPaid = installment.downPayment; // TODO: Calculate from payments
    final totalLeft = installment.installmentPrice - totalPaid;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: AppTheme.cardDecoration,
      child: GestureDetector(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      client?.fullName ?? 'Unknown Client',
                      style: AppTheme.subtitleStyle,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      installment.productName,
                      style: AppTheme.bodyStyle.copyWith(
                        color: AppTheme.textSecondaryColor,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        _InfoChip(
                          label: 'Paid',
                          value: currencyFormat.format(totalPaid),
                          color: AppTheme.successColor,
                        ),
                        const SizedBox(width: 12),
                        _InfoChip(
                          label: 'Left',
                          value: currencyFormat.format(totalLeft),
                          color: AppTheme.warningColor,
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 16),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppTheme.backgroundColor,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      'Next Payment',
                      style: AppTheme.captionStyle,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Month 1', // TODO: Get from actual payments
                      style: AppTheme.bodyStyle.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      DateFormat('MMM d, yyyy').format(installment.installmentStartDate),
                      style: AppTheme.captionStyle,
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              IconButton(
                icon: const Icon(FluentIcons.chevron_down),
                onPressed: () {
                  // TODO: Show payment dropdown
                },
              ),
              IconButton(
                icon: const Icon(FluentIcons.more_vertical),
                onPressed: () {
                  showDialog(
                    context: context,
                    barrierDismissible: true,
                    builder: (context) => Align(
                      alignment: Alignment.topRight,
                      child: Container(
                        margin: const EdgeInsets.only(top: 48, right: 20),
                        constraints: const BoxConstraints(maxWidth: 200),
                        decoration: AppTheme.elevatedCardDecoration,
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            ListTile(
                              leading: const Icon(FluentIcons.delete),
                              title: const Text('Delete'),
                              onPressed: () {
                                Navigator.of(context).pop();
                                onDelete();
                              },
                            ),
                          ],
                        ),
                      ),
                    ),
                  );
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _InfoChip extends StatelessWidget {
  final String label;
  final String value;
  final Color color;

  const _InfoChip({
    required this.label,
    required this.value,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            label,
            style: AppTheme.captionStyle.copyWith(color: color),
          ),
          const SizedBox(width: 4),
          Text(
            value,
            style: AppTheme.bodyStyle.copyWith(
              color: color,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
} 