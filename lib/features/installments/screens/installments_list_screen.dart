import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/localization/app_localizations.dart';
import '../widgets/installment_list_item.dart';
import '../domain/entities/installment.dart';
import '../domain/entities/installment_payment.dart';
import '../domain/repositories/installment_repository.dart';
import '../data/repositories/installment_repository_impl.dart';
import '../data/datasources/installment_local_datasource.dart';
import '../../clients/domain/repositories/client_repository.dart';
import '../../clients/data/repositories/client_repository_impl.dart';
import '../../clients/data/datasources/client_local_datasource.dart';
import '../../../shared/database/database_helper.dart';

class InstallmentsListScreen extends StatefulWidget {
  const InstallmentsListScreen({super.key});

  @override
  State<InstallmentsListScreen> createState() => _InstallmentsListScreenState();
}

class _InstallmentsListScreenState extends State<InstallmentsListScreen> {
  String _searchQuery = '';
  String _sortBy = 'status';
  late InstallmentRepository _installmentRepository;
  late ClientRepository _clientRepository;
  List<Installment> _installments = [];
  Map<String, String> _clientNames = {};
  Map<String, List<InstallmentPayment>> _installmentPayments = {};
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _initializeRepositories();
    _loadData();
  }

  void _initializeRepositories() {
    final db = DatabaseHelper.instance;
    _installmentRepository = InstallmentRepositoryImpl(
      InstallmentLocalDataSourceImpl(db),
    );
    _clientRepository = ClientRepositoryImpl(
      ClientLocalDataSourceImpl(db),
    );
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    try {
      // TODO: Replace with actual user ID from auth
      const userId = 'user123';
      
      final installments = await _installmentRepository.getAllInstallments(userId);
      final clients = await _clientRepository.getAllClients(userId);
      
      // Create client name map
      final clientNames = <String, String>{};
      for (final client in clients) {
        clientNames[client.id] = client.fullName;
      }
      
      // Load payments for each installment
      final installmentPayments = <String, List<InstallmentPayment>>{};
      for (final installment in installments) {
        final payments = await _installmentRepository.getPaymentsByInstallmentId(installment.id);
        installmentPayments[installment.id] = payments;
      }
      
      setState(() {
        _installments = installments;
        _clientNames = clientNames;
        _installmentPayments = installmentPayments;
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
      // Handle error
      print('Error loading data: $e');
    }
  }

  String _getOverallStatus(List<InstallmentPayment> payments) {
    // Determine overall status based on payments
    bool hasOverdue = false;
    bool hasDueToPay = false;
    bool hasUpcoming = false;
    
    for (final payment in payments) {
      if (payment.status == 'просрочено') {
        hasOverdue = true;
        break;
      } else if (payment.status == 'к оплате') {
        hasDueToPay = true;
      } else if (payment.status == 'предстоящий') {
        hasUpcoming = true;
      }
    }
    
    if (hasOverdue) return 'просрочено';
    if (hasDueToPay) return 'к оплате';
    if (hasUpcoming) return 'предстоящий';
    return 'оплачено';
  }

  List<Installment> get _filteredAndSortedInstallments {
    var filtered = _installments.where((installment) {
      if (_searchQuery.isEmpty) return true;
      
      final clientName = _clientNames[installment.clientId]?.toLowerCase() ?? '';
      final productName = installment.productName.toLowerCase();
      final query = _searchQuery.toLowerCase();
      
      return clientName.contains(query) || productName.contains(query);
    }).toList();
    
    // Sort
    switch (_sortBy) {
      case 'status':
        // Sort by payment status - priority order: просрочено, к оплате, предстоящий, оплачено
        filtered.sort((a, b) {
          final paymentsA = _installmentPayments[a.id] ?? [];
          final paymentsB = _installmentPayments[b.id] ?? [];
          
          final statusA = _getOverallStatus(paymentsA);
          final statusB = _getOverallStatus(paymentsB);
          
          // Define priority order for statuses
          final statusPriority = {
            'просрочено': 0,    // Highest priority (most urgent)
            'к оплате': 1,      // Second priority
            'предстоящий': 2,   // Third priority
            'оплачено': 3,      // Lowest priority (completed)
          };
          
          final priorityA = statusPriority[statusA] ?? 4;
          final priorityB = statusPriority[statusB] ?? 4;
          
          return priorityA.compareTo(priorityB);
        });
        break;
      case 'amount':
        filtered.sort((a, b) => b.installmentPrice.compareTo(a.installmentPrice));
        break;
      case 'client':
        filtered.sort((a, b) {
          final nameA = _clientNames[a.clientId] ?? '';
          final nameB = _clientNames[b.clientId] ?? '';
          return nameA.compareTo(nameB);
        });
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
                      l10n?.installments ?? 'Рассрочки',
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
                          hintText: '${l10n?.search ?? 'Поиск'} ${(l10n?.installments ?? 'рассрочки').toLowerCase()}...',
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
                          'status': l10n?.status ?? 'Статус',
                          'amount': l10n?.amount ?? 'Сумма',
                          'client': l10n?.clients ?? 'Клиенты',
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
                      onPressed: () => context.go('/installments/add'),
                      icon: const Icon(Icons.add),
                      label: Text(l10n?.addInstallment ?? 'Добавить рассрочку'),
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
                  flex: 2,
                  child: Text(
                    l10n?.clients ?? 'Клиенты',
                    style: Theme.of(context).textTheme.labelLarge?.copyWith(
                          color: AppTheme.textSecondary,
                        ),
                  ),
                ),
                Expanded(
                  flex: 2,
                  child: Text(
                    l10n?.productName ?? 'Название товара',
                    style: Theme.of(context).textTheme.labelLarge?.copyWith(
                          color: AppTheme.textSecondary,
                        ),
                  ),
                ),
                Expanded(
                  child: Text(
                    l10n?.paidAmount ?? 'Оплачено',
                    style: Theme.of(context).textTheme.labelLarge?.copyWith(
                          color: AppTheme.textSecondary,
                        ),
                  ),
                ),
                Expanded(
                  child: Text(
                    l10n?.leftAmount ?? 'Осталось',
                    style: Theme.of(context).textTheme.labelLarge?.copyWith(
                          color: AppTheme.textSecondary,
                        ),
                  ),
                ),
                Expanded(
                  child: Text(
                    l10n?.dueDate ?? 'Срок оплаты',
                    style: Theme.of(context).textTheme.labelLarge?.copyWith(
                          color: AppTheme.textSecondary,
                        ),
                  ),
                ),
                Expanded(
                  child: Text(
                    l10n?.status ?? 'Статус',
                    style: Theme.of(context).textTheme.labelLarge?.copyWith(
                          color: AppTheme.textSecondary,
                        ),
                  ),
                ),
                const SizedBox(width: 200), // Space for next payment section
              ],
            ),
          ),
          // List
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _filteredAndSortedInstallments.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.receipt_long_outlined,
                              size: 64,
                              color: AppTheme.textSecondary.withOpacity(0.5),
                            ),
                            const SizedBox(height: 16),
                            Text(
                              'Нет рассрочек',
                              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                                    color: AppTheme.textSecondary,
                                  ),
                            ),
                            const SizedBox(height: 8),
                            ElevatedButton.icon(
                              onPressed: () => context.go('/installments/add'),
                              icon: const Icon(Icons.add),
                              label: const Text('Добавить первую рассрочку'),
                            ),
                          ],
                        ),
                      )
                    : ListView.builder(
                        padding: const EdgeInsets.only(bottom: 24),
                        itemCount: _filteredAndSortedInstallments.length,
                        itemBuilder: (context, index) {
                          final installment = _filteredAndSortedInstallments[index];
                          final payments = _installmentPayments[installment.id] ?? [];
                          final clientName = _clientNames[installment.clientId] ?? 'Unknown';
                          
                          // Calculate paid amount and next payment
                          double paidAmount = 0;
                          InstallmentPayment? nextPayment;
                          
                          for (final payment in payments) {
                            paidAmount += payment.paidAmount;
                            if (nextPayment == null && payment.status != 'оплачено') {
                              nextPayment = payment;
                            }
                          }
                          
                          final leftAmount = installment.installmentPrice - paidAmount;
                          
                          return InstallmentListItem(
                            installment: installment,
                            clientName: clientName,
                            productName: installment.productName,
                            paidAmount: paidAmount,
                            leftAmount: leftAmount,
                            payments: payments,
                            nextPayment: nextPayment,
                            onTap: () => context.go('/installments/${installment.id}'),
                            onRegisterPayment: (payment) => _showRegisterPaymentDialog(payment),
                          );
                        },
                      ),
          ),
        ],
      ),
    );
  }

  void _showRegisterPaymentDialog(InstallmentPayment payment) {
    showDialog(
      context: context,
      builder: (context) => _RegisterPaymentDialog(
        payment: payment,
        onPaymentRegistered: () {
          _loadData(); // Reload data after payment
        },
      ),
    );
  }
}

class _RegisterPaymentDialog extends StatefulWidget {
  final InstallmentPayment payment;
  final VoidCallback onPaymentRegistered;

  const _RegisterPaymentDialog({
    required this.payment,
    required this.onPaymentRegistered,
  });

  @override
  State<_RegisterPaymentDialog> createState() => _RegisterPaymentDialogState();
}

class _RegisterPaymentDialogState extends State<_RegisterPaymentDialog> {
  late TextEditingController _amountController;
  late InstallmentRepository _repository;

  @override
  void initState() {
    super.initState();
    _amountController = TextEditingController(
      text: widget.payment.expectedAmount.toStringAsFixed(0),
    );
    _repository = InstallmentRepositoryImpl(
      InstallmentLocalDataSourceImpl(DatabaseHelper.instance),
    );
  }

  @override
  void dispose() {
    _amountController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text('Регистрация платежа ${widget.payment.paymentNumber == 0 ? "(Первоначальный взнос)" : "(Месяц ${widget.payment.paymentNumber})"}'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          TextField(
            controller: _amountController,
            keyboardType: TextInputType.number,
            decoration: const InputDecoration(
              labelText: 'Сумма платежа',
              suffixText: '₽',
            ),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Отмена'),
        ),
        ElevatedButton(
          onPressed: () async {
            final amount = double.tryParse(_amountController.text) ?? 0;
            if (amount > 0) {
              final updatedPayment = widget.payment.copyWith(
                paidAmount: amount,
                paidDate: DateTime.now(),
                status: 'оплачено',
              );
              
              await _repository.updatePayment(updatedPayment);
              widget.onPaymentRegistered();
              Navigator.of(context).pop();
            }
          },
          child: const Text('Сохранить'),
        ),
      ],
    );
  }
} 