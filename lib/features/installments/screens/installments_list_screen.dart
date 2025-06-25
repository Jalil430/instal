import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/localization/app_localizations.dart';
import '../../../shared/widgets/custom_dropdown.dart';
import '../../../shared/widgets/custom_search_bar.dart';
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
import '../../../shared/widgets/custom_button.dart';
import '../../../shared/widgets/custom_confirmation_dialog.dart';

class InstallmentsListScreen extends StatefulWidget {
  const InstallmentsListScreen({super.key});

  @override
  State<InstallmentsListScreen> createState() => _InstallmentsListScreenState();
}

class _InstallmentsListScreenState extends State<InstallmentsListScreen> with TickerProviderStateMixin {
  String _searchQuery = '';
  String _sortBy = 'status';
  late InstallmentRepository _installmentRepository;
  late ClientRepository _clientRepository;
  List<Installment> _installments = [];
  Map<String, String> _clientNames = {};
  Map<String, List<InstallmentPayment>> _installmentPayments = {};
  final Map<String, bool> _expandedStates = {}; // Track expansion state by installment ID
  bool _isLoading = true;
  
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
    
    _initializeRepositories();
    _loadData();
  }

  @override
  void dispose() {
    _fadeController.dispose();
    super.dispose();
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
          
          final statusA = InstallmentListItem.getOverallStatus(context, paymentsA);
          final statusB = InstallmentListItem.getOverallStatus(context, paymentsB);
          
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
          // Enhanced Header with search and sort
          Container(
            padding: const EdgeInsets.fromLTRB(32, 28, 32, 20),
            decoration: BoxDecoration(
              color: AppTheme.surfaceColor,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.05),
                  offset: const Offset(0, 2),
                  blurRadius: 8,
                  spreadRadius: 0,
                ),
              ],
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
                          l10n?.installments ?? 'Рассрочки',
                          style: const TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.w600,
                            letterSpacing: -0.5,
                          ),
                        ),
                        Text(
                          '${_filteredAndSortedInstallments.length} ${_getItemsText(_filteredAndSortedInstallments.length)}',
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
                      hintText: '${l10n?.search ?? 'Поиск'} ${_getItemsText(0)}...',
                      width: 320,
                    ),
                    const SizedBox(width: 16),
                    // Enhanced Sort dropdown
                    CustomDropdown(
                      value: _sortBy,
                      width: 200,
                      items: {
                        'creationDate': l10n?.creationDate ?? 'Дата создания',
                        'status': l10n?.status ?? 'Статус',
                        'amount': l10n?.amount ?? 'Сумма',
                        'client': l10n?.client ?? 'Клиент',
                      },
                      onChanged: (value) => setState(() => _sortBy = value!),
                    ),
                    const SizedBox(width: 16),
                    // Custom Add button
                    CustomButton(
                      text: l10n?.addInstallment ?? 'Добавить рассрочку',
                      onPressed: () => context.go('/installments/add'),
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
                                  flex: 2,
                                  child: Padding(
                                    padding: const EdgeInsets.only(right: 16),
                                    child: Text(
                                      (l10n?.client ?? l10n?.client ?? 'Клиент').toUpperCase(),
                                      style: Theme.of(context).textTheme.labelMedium?.copyWith(
                                            color: AppTheme.textSecondary,
                                            fontWeight: FontWeight.w400,
                                            fontSize: 12,
                                            letterSpacing: 0.5,
                                          ),
                                    ),
                                  ),
                                ),
                                Expanded(
                                  flex: 2,
                                  child: Padding(
                                    padding: const EdgeInsets.only(right: 16),
                                    child: Text(
                                      (l10n?.productName ?? l10n?.productNameHeader ?? 'Название товара').toUpperCase(),
                                      style: Theme.of(context).textTheme.labelMedium?.copyWith(
                                            color: AppTheme.textSecondary,
                                            fontWeight: FontWeight.w400,
                                            fontSize: 12,
                                            letterSpacing: 0.5,
                                          ),
                                    ),
                                  ),
                                ),
                                Expanded(
                                  child: Padding(
                                    padding: const EdgeInsets.only(right: 16),
                                    child: Text(
                                      (l10n?.paidAmount ?? 'Оплачено').toUpperCase(),
                                      style: Theme.of(context).textTheme.labelMedium?.copyWith(
                                            color: AppTheme.textSecondary,
                                            fontWeight: FontWeight.w400,
                                            fontSize: 12,
                                            letterSpacing: 0.5,
                                          ),
                                    ),
                                  ),
                                ),
                                Expanded(
                                  child: Padding(
                                    padding: const EdgeInsets.only(right: 16),
                                    child: Text(
                                      (l10n?.leftAmount ?? 'Осталось').toUpperCase(),
                                      style: Theme.of(context).textTheme.labelMedium?.copyWith(
                                            color: AppTheme.textSecondary,
                                            fontWeight: FontWeight.w400,
                                            fontSize: 12,
                                            letterSpacing: 0.5,
                                          ),
                                    ),
                                  ),
                                ),
                                Expanded(
                                  child: Padding(
                                    padding: const EdgeInsets.only(right: 16),
                                    child: Text(
                                      (l10n?.dueDate ?? 'Срок оплаты').toUpperCase(),
                                      style: Theme.of(context).textTheme.labelMedium?.copyWith(
                                            color: AppTheme.textSecondary,
                                            fontWeight: FontWeight.w400,
                                            fontSize: 12,
                                            letterSpacing: 0.5,
                                          ),
                                    ),
                                  ),
                                ),
                                Expanded(
                                  child: Padding(
                                    padding: const EdgeInsets.only(right: 16),
                                    child: Text(
                                      (l10n?.status ?? l10n?.statusHeader ?? 'Статус').toUpperCase(),
                                      style: Theme.of(context).textTheme.labelMedium?.copyWith(
                                            color: AppTheme.textSecondary,
                                            fontWeight: FontWeight.w400,
                                            fontSize: 12,
                                            letterSpacing: 0.5,
                                          ),
                                    ),
                                  ),
                                ),
                                Container(
                                  width: 160,
                                  padding: const EdgeInsets.only(left: 8),
                                  child: Text(
                                    l10n?.nextPaymentHeader ?? 'СЛЕДУЮЩИЙ ПЛАТЕЖ',
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
                            child: _filteredAndSortedInstallments.isEmpty
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
                                    itemCount: _filteredAndSortedInstallments.length,
                                    itemBuilder: (context, index) {
                                      final installment = _filteredAndSortedInstallments[index];
                                      final payments = _installmentPayments[installment.id] ?? [];
                                      final clientName = _clientNames[installment.clientId] ?? AppLocalizations.of(context)?.unknown ?? 'Unknown';
                                      double paidAmount = 0;
                                      InstallmentPayment? nextPayment;
                                      for (final payment in payments) {
                                        if (payment.isPaid) {
                                          paidAmount += payment.expectedAmount;
                                        }
                                        if (nextPayment == null && !payment.isPaid) {
                                          nextPayment = payment;
                                        }
                                      }
                                      final leftAmount = installment.installmentPrice - paidAmount;
                                      return AnimatedContainer(
                                        duration: Duration(milliseconds: 100 + (index * 50)),
                                        curve: Curves.easeOutCubic,
                                        child: InstallmentListItem(
                                          installment: installment,
                                          clientName: clientName,
                                          productName: installment.productName,
                                          paidAmount: paidAmount,
                                          leftAmount: leftAmount,
                                          payments: payments,
                                          nextPayment: nextPayment,
                                          isExpanded: _expandedStates[installment.id] ?? false,
                                          onTap: () => context.go('/installments/${installment.id}'),
                                          onClientTap: () => context.go('/clients/${installment.clientId}'),
                                          onExpansionChanged: (expanded) => setState(() {
                                            _expandedStates[installment.id] = expanded;
                                          }),
                                          onDataChanged: () => _loadData(),
                                          onDelete: () => _deleteInstallment(installment),
                                          onSelect: () {
                                            print('Selected installment: \'${installment.productName}\'');
                                          },
                                        ),
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

  String _getItemsText(int count) {
    final l10n = AppLocalizations.of(context)!;
    if (count % 10 == 1 && count % 100 != 11) {
      return l10n.installment_one;
    } else if ([2, 3, 4].contains(count % 10) && ![12, 13, 14].contains(count % 100)) {
      return l10n.installment_few;
    } else {
      return l10n.installment_many;
    }
  }

  Future<void> _deleteInstallment(Installment installment) async {
    final l10n = AppLocalizations.of(context);
    final confirmed = await showCustomConfirmationDialog(
      context: context,
      title: l10n?.deleteInstallmentTitle ?? 'Удалить рассрочку',
      content: l10n?.deleteInstallmentConfirmation ?? 'Вы уверены, что хотите удалить рассрочку?',
    );
    if (confirmed == true) {
      try {
        await _installmentRepository.deleteInstallment(installment.id);
        _loadData();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(l10n?.installmentDeleted ?? 'Рассрочка удалена')),
        );
      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(l10n?.installmentDeleteError(e) ?? 'Ошибка удаления: $e')),
        );
      }
    }
  }
} 