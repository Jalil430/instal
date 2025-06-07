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
import 'package:intl/intl.dart';
import '../../../shared/widgets/custom_add_button.dart';

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
                          style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                            fontWeight: FontWeight.w700,
                            letterSpacing: -0.5,
                          ),
                        ),
                        Text(
                          '${_filteredAndSortedInstallments.length} ${_getItemsText(_filteredAndSortedInstallments.length)}',
                          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
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
                      hintText: '${l10n?.search ?? 'Поиск'} ${(l10n?.installments ?? 'рассрочки').toLowerCase()}...',
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
                    CustomAddButton(
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
                  : _filteredAndSortedInstallments.isEmpty
                      ? _buildEnhancedEmptyState(context)
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
                                          (l10n?.client ?? 'Клиент').toUpperCase(),
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
                                          (l10n?.productName ?? 'Название товара').toUpperCase(),
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
                                          (l10n?.status ?? 'Статус').toUpperCase(),
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
                                        'СЛЕДУЮЩИЙ ПЛАТЕЖ',
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
                                child: FadeTransition(
                                  opacity: _fadeAnimation,
                                  child: ListView.builder(
                                    padding: EdgeInsets.zero,
                                    itemCount: _filteredAndSortedInstallments.length,
                                    itemBuilder: (context, index) {
                                      final installment = _filteredAndSortedInstallments[index];
                                      final payments = _installmentPayments[installment.id] ?? [];
                                      final clientName = _clientNames[installment.clientId] ?? 'Unknown';
                                      
                                      // Calculate paid amount and next payment
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
                                          onTap: () => context.go('/installments/${installment.id}'),
                                          onRegisterPayment: (payment) => _showRegisterPaymentDialog(payment),
                                          onDeletePayment: (payment) => _showDeletePaymentDialog(payment),
                                          onClientTap: () => context.go('/clients/${installment.clientId}'),
                                        ),
                                      );
                                    },
                                  ),
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

  Widget _buildEnhancedEmptyState(BuildContext context) {
    return Center(
      child: Container(
        padding: const EdgeInsets.all(48),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    AppTheme.textSecondary.withOpacity(0.05),
                    AppTheme.textSecondary.withOpacity(0.02),
                  ],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(24),
                border: Border.all(
                  color: AppTheme.textSecondary.withOpacity(0.1),
                  width: 1,
                ),
              ),
              child: Icon(
                Icons.receipt_long_outlined,
                size: 56,
                color: AppTheme.textSecondary.withOpacity(0.4),
              ),
            ),
            const SizedBox(height: 24),
            Text(
              'Нет рассрочек',
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    color: AppTheme.textSecondary,
                    fontWeight: FontWeight.w600,
                  ),
            ),
            const SizedBox(height: 8),
            Text(
              'Создайте первую рассрочку для начала работы',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: AppTheme.textSecondary.withOpacity(0.8),
                  ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 32),
            CustomAddButton(
              text: 'Добавить первую рассрочку',
              onPressed: () => context.go('/installments/add'),
              fontSize: 16,
              height: 48,
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
            ),
          ],
        ),
      ),
    );
  }

  String _getItemsText(int count) {
    if (count % 10 == 1 && count % 100 != 11) {
      return 'рассрочка';
    } else if ([2, 3, 4].contains(count % 10) && ![12, 13, 14].contains(count % 100)) {
      return 'рассрочки';
    } else {
      return 'рассрочек';
    }
  }

  void _showRegisterPaymentDialog(InstallmentPayment payment) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => _EnhancedRegisterPaymentDialog(
        payment: payment,
        onPaymentRegistered: () {
          _loadData(); // Reload data after payment
        },
      ),
    );
  }

  void _showDeletePaymentDialog(InstallmentPayment payment) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Отменить оплату'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              payment.paymentNumber == 0 
                  ? 'Первоначальный взнос'
                  : 'Месяц ${payment.paymentNumber}',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              'Вы уверены, что хотите отменить оплату этого платежа?',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: AppTheme.textSecondary,
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
              try {
                final updatedPayment = payment.copyWith(
                  isPaid: false,
                  paidDate: null,
                );
                
                await _installmentRepository.updatePayment(updatedPayment);
                _loadData(); // Reload data after payment cancellation
                Navigator.of(context).pop();
                
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Оплата отменена')),
                  );
                }
              } catch (e) {
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Ошибка: $e')),
                  );
                }
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.errorColor,
              foregroundColor: Colors.white,
            ),
            child: const Text('Отменить оплату'),
          ),
        ],
      ),
    );
  }
}

class _EnhancedRegisterPaymentDialog extends StatefulWidget {
  final InstallmentPayment payment;
  final VoidCallback onPaymentRegistered;

  const _EnhancedRegisterPaymentDialog({
    required this.payment,
    required this.onPaymentRegistered,
  });

  @override
  State<_EnhancedRegisterPaymentDialog> createState() => _EnhancedRegisterPaymentDialogState();
}

class _EnhancedRegisterPaymentDialogState extends State<_EnhancedRegisterPaymentDialog> with SingleTickerProviderStateMixin {
  late InstallmentRepository _repository;
  bool _isLoading = false;
  late AnimationController _animationController;
  late Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();
    _repository = InstallmentRepositoryImpl(
      InstallmentLocalDataSourceImpl(DatabaseHelper.instance),
    );
    
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );
    _scaleAnimation = Tween<double>(begin: 0.8, end: 1.0).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeOutBack),
    );
    
    _animationController.forward();
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final currencyFormat = NumberFormat.currency(
      locale: 'ru_RU',
      symbol: '₽',
      decimalDigits: 0,
    );

    return Dialog(
      backgroundColor: Colors.transparent,
      child: ScaleTransition(
        scale: _scaleAnimation,
        child: Container(
          width: 400,
          decoration: BoxDecoration(
            color: AppTheme.surfaceColor,
            borderRadius: BorderRadius.circular(20),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.15),
                offset: const Offset(0, 10),
                blurRadius: 30,
                spreadRadius: 0,
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Header
              Container(
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      AppTheme.primaryColor.withOpacity(0.1),
                      AppTheme.primaryColor.withOpacity(0.05),
                    ],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: const BorderRadius.only(
                    topLeft: Radius.circular(20),
                    topRight: Radius.circular(20),
                  ),
                ),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: AppTheme.primaryColor.withOpacity(0.2),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Icon(
                        Icons.payment_rounded,
                        color: AppTheme.primaryColor,
                        size: 24,
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Отметить как оплаченный',
                            style: Theme.of(context).textTheme.titleLarge?.copyWith(
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            widget.payment.paymentNumber == 0 
                                ? "Первоначальный взнос"
                                : "Месяц ${widget.payment.paymentNumber}",
                            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                              color: AppTheme.textSecondary,
                            ),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      onPressed: () => Navigator.of(context).pop(),
                      icon: Icon(
                        Icons.close_rounded,
                        color: AppTheme.textSecondary,
                      ),
                      style: IconButton.styleFrom(
                        backgroundColor: AppTheme.backgroundColor,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              
              // Content
              Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Payment Info
                    Container(
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        color: AppTheme.backgroundColor,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: AppTheme.borderColor.withOpacity(0.5),
                          width: 1,
                        ),
                      ),
                      child: Row(
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Сумма к оплате',
                                  style: Theme.of(context).textTheme.labelMedium?.copyWith(
                                    color: AppTheme.textSecondary,
                                  ),
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  currencyFormat.format(widget.payment.expectedAmount),
                                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                                    fontWeight: FontWeight.w700,
                                    color: AppTheme.primaryColor,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          Container(
                            width: 1,
                            height: 50,
                            color: AppTheme.borderColor,
                          ),
                          const SizedBox(width: 20),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Срок оплаты',
                                  style: Theme.of(context).textTheme.labelMedium?.copyWith(
                                    color: AppTheme.textSecondary,
                                  ),
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  DateFormat('dd.MM.yyyy').format(widget.payment.dueDate),
                                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                    
                    const SizedBox(height: 20),
                    
                    // Confirmation text
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: AppTheme.primaryColor.withOpacity(0.05),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: AppTheme.primaryColor.withOpacity(0.2),
                          width: 1,
                        ),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            Icons.info_outline_rounded,
                            color: AppTheme.primaryColor,
                            size: 20,
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              'Платеж будет отмечен как полностью оплаченный на сумму ${currencyFormat.format(widget.payment.expectedAmount)}',
                              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                color: AppTheme.primaryColor,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              
              // Actions
              Container(
                padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
                child: Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: _isLoading ? null : () => Navigator.of(context).pop(),
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          side: BorderSide(
                            color: AppTheme.borderColor,
                            width: 1,
                          ),
                        ),
                        child: Text(
                          'Отмена',
                          style: TextStyle(
                            fontWeight: FontWeight.w600,
                            color: AppTheme.textSecondary,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Container(
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: [AppTheme.primaryColor, AppTheme.primaryColor.withOpacity(0.9)],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
                          borderRadius: BorderRadius.circular(12),
                          boxShadow: [
                            BoxShadow(
                              color: AppTheme.primaryColor.withOpacity(0.3),
                              offset: const Offset(0, 4),
                              blurRadius: 12,
                              spreadRadius: 0,
                            ),
                          ],
                        ),
                        child: ElevatedButton(
                          onPressed: _isLoading ? null : _handlePayment,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.transparent,
                            foregroundColor: Colors.white,
                            shadowColor: Colors.transparent,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                            padding: const EdgeInsets.symmetric(vertical: 16),
                          ),
                          child: _isLoading
                              ? const SizedBox(
                                  width: 20,
                                  height: 20,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                                  ),
                                )
                              : const Text(
                                  'Отметить как оплаченный',
                                  style: TextStyle(
                                    fontWeight: FontWeight.w700,
                                    fontSize: 16,
                                  ),
                                ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _handlePayment() async {
    setState(() => _isLoading = true);

    try {
      final updatedPayment = widget.payment.copyWith(
        isPaid: true,
        paidDate: DateTime.now(),
      );
      
      await _repository.updatePayment(updatedPayment);
      widget.onPaymentRegistered();
      Navigator.of(context).pop();
    } catch (e) {
      // Handle error
      setState(() => _isLoading = false);
    }
  }
} 