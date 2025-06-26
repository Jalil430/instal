import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../../core/themes/app_theme.dart';
import '../../../installments/domain/entities/installment.dart';
import '../../../installments/presentation/providers/installment_provider.dart';
import '../../../installments/presentation/screens/installment_details_screen.dart';
import '../../../installments/presentation/widgets/installment_list_item.dart';
import '../../domain/entities/client.dart';
import '../providers/client_provider.dart';
import 'add_client_screen.dart';

class ClientDetailsScreen extends StatefulWidget {
  final String clientId;

  const ClientDetailsScreen({
    super.key,
    required this.clientId,
  });

  @override
  State<ClientDetailsScreen> createState() => _ClientDetailsScreenState();
}

class _ClientDetailsScreenState extends State<ClientDetailsScreen> {
  bool _isLoading = true;
  String? _errorMessage;
  Client? _client;
  List<Installment> _clientInstallments = [];

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final clientProvider = Provider.of<ClientProvider>(context, listen: false);
      final installmentProvider = Provider.of<InstallmentProvider>(context, listen: false);
      
      // Load client
      final client = await clientProvider.getClientById(widget.clientId);
      
      if (client == null) {
        setState(() {
          _errorMessage = 'Клиент не найден';
          _isLoading = false;
        });
        return;
      }
      
      // Load client's installments
      final installments = await installmentProvider.getInstallmentsByClientId(client.id);
      
      if (mounted) {
        setState(() {
          _client = client;
          _clientInstallments = installments;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = 'Ошибка загрузки данных: ${e.toString()}';
          _isLoading = false;
        });
      }
    }
  }

  void _navigateToEditClient() {
    if (_client == null) return;
    
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => AddClientScreen(
          initialClient: _client,
        ),
      ),
    ).then((_) {
      // Refresh data when returning from edit screen
      _loadData();
    });
  }

  void _navigateToInstallmentDetails(String installmentId) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => InstallmentDetailsScreen(
          installmentId: installmentId,
        ),
      ),
    ).then((_) {
      // Refresh data when returning from details screen
      _loadData();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Детали клиента'),
        elevation: 0,
        backgroundColor: AppTheme.surfaceColor,
        actions: [
          IconButton(
            icon: const Icon(Icons.edit),
            onPressed: _client != null ? _navigateToEditClient : null,
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _errorMessage != null
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.error_outline, size: 64, color: AppTheme.textTertiary),
                      const SizedBox(height: 16),
                      Text(
                        'Ошибка',
                        style: Theme.of(context).textTheme.titleLarge?.copyWith(
                              color: AppTheme.textSecondary,
                            ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        _errorMessage!,
                        style: Theme.of(context).textTheme.bodyMedium,
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 16),
                      ElevatedButton(
                        onPressed: _loadData,
                        child: const Text('Повторить'),
                      ),
                    ],
                  ),
                )
              : Container(
                  color: AppTheme.backgroundColor,
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Client Card with basic information
                        Card(
                          elevation: 0,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                            side: const BorderSide(color: AppTheme.dividerColor),
                          ),
                          child: Padding(
                            padding: const EdgeInsets.all(24),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Container(
                                      width: 64,
                                      height: 64,
                                      decoration: BoxDecoration(
                                        color: AppTheme.primaryColor.withOpacity(0.1),
                                        borderRadius: BorderRadius.circular(32),
                                      ),
                                      child: const Center(
                                        child: Icon(
                                          Icons.person,
                                          size: 32,
                                          color: AppTheme.primaryColor,
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: 16),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            _client!.fullName,
                                            style: Theme.of(context).textTheme.headlineSmall,
                                          ),
                                          const SizedBox(height: 4),
                                          Text(
                                            _client!.contactNumber,
                                            style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                                                  color: AppTheme.textSecondary,
                                                ),
                                          ),
                                        ],
                                      ),
                                    ),
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 16,
                                        vertical: 8,
                                      ),
                                      decoration: BoxDecoration(
                                        color: AppTheme.primaryColor.withOpacity(0.1),
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                      child: Column(
                                        children: [
                                          Text(
                                            '${_clientInstallments.length}',
                                            style: Theme.of(context).textTheme.titleLarge?.copyWith(
                                                  color: AppTheme.primaryColor,
                                                ),
                                          ),
                                          const SizedBox(height: 4),
                                          Text(
                                            _getInstallmentsLabel(_clientInstallments.length),
                                            style: Theme.of(context).textTheme.bodySmall,
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 24),
                                const Divider(),
                                const SizedBox(height: 16),
                                
                                // Client details
                                _buildDetailRow('Номер паспорта:', _client!.passportNumber),
                                _buildDetailRow('Адрес:', _client!.address),
                              ],
                            ),
                          ),
                        ),
                        
                        const SizedBox(height: 24),
                        
                        // Client installments
                        Text(
                          'Рассрочки клиента',
                          style: Theme.of(context).textTheme.titleLarge,
                        ),
                        const SizedBox(height: 16),
                        
                        if (_clientInstallments.isEmpty)
                          Center(
                            child: Padding(
                              padding: const EdgeInsets.all(24),
                              child: Column(
                                children: [
                                  Icon(
                                    Icons.receipt_long_outlined,
                                    size: 48,
                                    color: AppTheme.textTertiary,
                                  ),
                                  const SizedBox(height: 16),
                                  Text(
                                    'У клиента нет рассрочек',
                                    style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                                          color: AppTheme.textSecondary,
                                        ),
                                  ),
                                ],
                              ),
                            ),
                          )
                        else
                          ListView.builder(
                            shrinkWrap: true,
                            physics: const NeverScrollableScrollPhysics(),
                            itemCount: _clientInstallments.length,
                            itemBuilder: (context, index) {
                              final installment = _clientInstallments[index];
                              return Padding(
                                padding: const EdgeInsets.only(bottom: 12),
                                child: InstallmentListItem(
                                  installment: installment,
                                  onTap: () => _navigateToInstallmentDetails(installment.id),
                                  onEdit: () => _navigateToInstallmentDetails(installment.id),
                                  onDelete: () {
                                    // TODO: Implement delete action if needed
                                  },
                                  onRegisterPayment: () => _navigateToInstallmentDetails(installment.id),
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

  Widget _buildDetailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            flex: 1,
            child: Text(
              label,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: AppTheme.textSecondary,
                  ),
            ),
          ),
          Expanded(
            flex: 3,
            child: Text(
              value,
              style: Theme.of(context).textTheme.bodyMedium,
            ),
          ),
        ],
      ),
    );
  }
  
  String _getInstallmentsLabel(int count) {
    if (count == 0) {
      return 'рассрочек';
    } else if (count == 1) {
      return 'рассрочка';
    } else if (count >= 2 && count <= 4) {
      return 'рассрочки';
    } else {
      return 'рассрочек';
    }
  }
} 