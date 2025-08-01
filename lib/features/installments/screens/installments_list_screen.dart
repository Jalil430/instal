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
import '../data/datasources/installment_remote_datasource.dart';
import '../data/models/installment_model.dart';
import '../../clients/domain/repositories/client_repository.dart';
import '../../clients/data/repositories/client_repository_impl.dart';
import '../../clients/data/datasources/client_remote_datasource.dart';
import '../../../shared/widgets/custom_button.dart';
import '../../../shared/widgets/custom_confirmation_dialog.dart';
import '../../../core/api/cache_service.dart';
import '../../auth/presentation/widgets/auth_service_provider.dart';
import '../services/reminder_service.dart';
import '../../../shared/widgets/create_installment_dialog.dart';
import '../../../core/error/global_error_handler.dart';

class InstallmentsListScreen extends StatefulWidget {
  const InstallmentsListScreen({super.key});

  @override
  State<InstallmentsListScreen> createState() => _InstallmentsListScreenState();
}

class _InstallmentsListScreenState extends State<InstallmentsListScreen> with TickerProviderStateMixin {
  // WhatsApp brand color - static so it can be accessed from dialog
  static const Color whatsAppColor = Color(0xFF25D366);
  
  String _searchQuery = '';
  String _sortBy = 'status';
  late InstallmentRepository _installmentRepository;
  late ClientRepository _clientRepository;
  List<Installment> _installments = [];
  Map<String, String> _clientNames = {};
  Map<String, List<InstallmentPayment>> _installmentPayments = {};
  final Map<String, bool> _expandedStates = {}; // Track expansion state by installment ID
  final Set<String> _selectedInstallmentIds = {}; // Track selected installments
  final Set<String> _loadingPayments = {}; // Track which installments are loading payments
  bool _isLoading = true;
  bool _isInitialized = false;
  bool _isSelectionMode = false;
  
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

  void _initializeRepositories() {
    _installmentRepository = InstallmentRepositoryImpl(
      InstallmentRemoteDataSourceImpl(),
    );
    _clientRepository = ClientRepositoryImpl(
      ClientRemoteDataSourceImpl(),
    );
  }

  Future<void> _loadData() async {
    if (!mounted) return;
    setState(() => _isLoading = true);
    
    // Performance measurement
    final stopwatch = Stopwatch()..start();
    
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
      
      // Get all installments with pre-calculated fields (single optimized call!)
      final installments = await _installmentRepository.getAllInstallments(currentUser.id);
      
      if (!mounted) return;
      
      // Extract pre-calculated data from optimized response
      final clientNames = <String, String>{};
      final paymentsMap = <String, List<InstallmentPayment>>{};
      
      for (final installment in installments) {
        // Client names are now included in the installment data
        if (installment is InstallmentModel && installment.clientName != null) {
          clientNames[installment.clientId] = installment.clientName!;
        }
        
        // For now, keep payments empty since we have summary data
        // Individual payments will be loaded only when needed (on expand)
        paymentsMap[installment.id] = [];
      }
      
      setState(() {
        _installments = installments;
        _clientNames = clientNames;
        _installmentPayments = paymentsMap;
        _isLoading = false;
      });
      
      if (mounted) {
        _fadeController.forward();
      }
      
      // Performance logging
      stopwatch.stop();
      print('🚀 Installments loaded in ${stopwatch.elapsedMilliseconds}ms (${installments.length} installments, ${paymentsMap.values.fold(0, (sum, payments) => sum + payments.length)} payments)');
      
    } catch (e) {
      stopwatch.stop();
      print('Error loading installments data: $e');
      if (mounted) {
        setState(() {
          _isLoading = false;
          _installments = [];
          _clientNames = {};
          _installmentPayments = {};
        });
        
        // Show more specific error messages
        String errorMessage;
        if (e.toString().contains('502') || e.toString().contains('Bad Gateway')) {
          errorMessage = 'Сервер временно недоступен. Попробуйте позже.';
        } else if (e.toString().contains('500') || e.toString().contains('ServerException')) {
          errorMessage = 'Ошибка сервера. Попробуйте позже.';
        } else if (e.toString().contains('Network error')) {
          errorMessage = 'Ошибка сети. Проверьте подключение к интернету.';
        } else {
          errorMessage = '${AppLocalizations.of(context)?.errorLoadingData ?? 'Ошибка загрузки данных'}: ${e.toString().replaceAll('ApiException: ', '').replaceAll('ServerException: ', '')}';
        }
        
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(errorMessage),
            backgroundColor: AppTheme.errorColor,
            duration: const Duration(seconds: 5),
          ),
        );
      }
    }
  }

  Future<void> _refreshData() async {
    // Refresh without showing loading spinner - use cached data while loading
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
      
      // Get all installments with pre-calculated fields (single optimized call!)
      final installments = await _installmentRepository.getAllInstallments(currentUser.id);
      
      // Extract pre-calculated data from optimized response
      final clientNames = <String, String>{};
      final paymentsMap = <String, List<InstallmentPayment>>{};
      
      for (final installment in installments) {
        // Client names are now included in the installment data
        if (installment is InstallmentModel && installment.clientName != null) {
          clientNames[installment.clientId] = installment.clientName!;
        }
        
        // Keep existing payments if already loaded, otherwise empty
        if (!_installmentPayments.containsKey(installment.id)) {
          paymentsMap[installment.id] = [];
        } else {
          paymentsMap[installment.id] = _installmentPayments[installment.id]!;
        }
      }
      
      setState(() {
        _installments = installments;
        _clientNames = clientNames;
        _installmentPayments = paymentsMap;
      });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('${AppLocalizations.of(context)?.errorLoadingData ?? 'Error loading data'}: $e')),
        );
      }
    }
  }

  /// Load payments for a specific installment (lazy loading)
  Future<void> _loadPaymentsForInstallment(String installmentId) async {
    // Set loading state
    setState(() {
      _loadingPayments.add(installmentId);
    });
    
    try {
      final payments = await _installmentRepository.getPaymentsByInstallmentId(installmentId);
      setState(() {
        _installmentPayments[installmentId] = payments;
        _loadingPayments.remove(installmentId);
      });
    } catch (e) {
      print('Failed to load payments for installment $installmentId: $e');
      setState(() {
        _loadingPayments.remove(installmentId);
      });
      // Don't show error to user for individual payment loading failures
    }
  }

  List<Installment> get _filteredAndSortedInstallments {
    var filtered = _installments.where((installment) {
      if (_searchQuery.isEmpty) return true;
      
      final clientName = installment is InstallmentModel ? (installment.clientName?.toLowerCase() ?? '') : '';
      final productName = installment.productName.toLowerCase();
      final query = _searchQuery.toLowerCase();
      
      return clientName.contains(query) || productName.contains(query);
    }).toList();
    
    // Sort
    switch (_sortBy) {
      case 'status':
        // Sort by payment status using pre-calculated status - priority order: просрочено, к оплате, предстоящий, оплачено
        filtered.sort((a, b) {
          final statusA = a is InstallmentModel ? (a.paymentStatus ?? 'предстоящий') : 'предстоящий';
          final statusB = b is InstallmentModel ? (b.paymentStatus ?? 'предстоящий') : 'предстоящий';
          
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
          final nameA = a is InstallmentModel ? (a.clientName ?? '') : '';
          final nameB = b is InstallmentModel ? (b.clientName ?? '') : '';
          return nameA.compareTo(nameB);
        });
        break;
      case 'creationDate':
      default:
        filtered.sort((a, b) => b.createdAt.compareTo(a.createdAt));
    }
    
    return filtered;
  }

  // Selection methods
  void _toggleSelection(String installmentId) {
    setState(() {
      if (_selectedInstallmentIds.contains(installmentId)) {
        _selectedInstallmentIds.remove(installmentId);
        if (_selectedInstallmentIds.isEmpty) {
          _isSelectionMode = false;
        }
      } else {
        _selectedInstallmentIds.add(installmentId);
        _isSelectionMode = true;
      }
    });
  }

  void _selectAll() {
    setState(() {
      _selectedInstallmentIds.clear();
      _selectedInstallmentIds.addAll(_filteredAndSortedInstallments.map((i) => i.id));
      _isSelectionMode = true;
    });
  }
  
  void _selectAllOverdue() {
    setState(() {
      _selectedInstallmentIds.clear();
      
      // Find all installments with overdue status using pre-calculated status
      for (final installment in _filteredAndSortedInstallments) {
        final status = installment is InstallmentModel ? (installment.paymentStatus ?? 'предстоящий') : 'предстоящий';
        
        // Add to selection if status is overdue
        if (status == 'просрочено') {
          _selectedInstallmentIds.add(installment.id);
        }
      }
      
      _isSelectionMode = _selectedInstallmentIds.isNotEmpty;
    });
  }

  void _clearSelection() {
    setState(() {
      _selectedInstallmentIds.clear();
      _isSelectionMode = false;
    });
  }

  void _sendBulkReminders() async {
    if (_selectedInstallmentIds.isEmpty) return;
    
    // Show confirmation dialog
    final confirmed = await _showBulkReminderConfirmationDialog();
    if (!confirmed) return;
    
    await ReminderService.sendBulkReminders(
      context: context,
      installmentIds: _selectedInstallmentIds.toList(),
      templateType: 'manual',
    );
    
    // Clear selection after sending
    _clearSelection();
  }

  Future<void> _deleteBulkInstallments() async {
    if (_selectedInstallmentIds.isEmpty) return;
    
    final l10n = AppLocalizations.of(context);
    
    // Show confirmation dialog
    final confirmed = await showCustomConfirmationDialog(
      context: context,
      title: l10n?.deleteInstallmentTitle ?? 'Delete Installment',
      content: _selectedInstallmentIds.length == 1
          ? l10n?.deleteInstallmentConfirmation ?? 'Are you sure you want to delete this installment?'
          : '${l10n?.deleteInstallmentConfirmation ?? 'Are you sure you want to delete these installments?'} (${_selectedInstallmentIds.length})',
    );
    
    if (confirmed != true) return;
    
    try {
      // Clear cache to ensure fresh data after deletion
      final cache = CacheService();
      final authService = AuthServiceProvider.of(context);
      final currentUser = await authService.getCurrentUser();
      
      if (currentUser != null) {
        cache.remove(CacheService.installmentsKey(currentUser.id));
        cache.remove(CacheService.analyticsKey(currentUser.id));
      }
      
      // Show loading indicator
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
      
      // Delete all selected installments
      for (final id in _selectedInstallmentIds) {
        cache.remove(CacheService.installmentKey(id));
        cache.remove(CacheService.paymentsKey(id));
        await _installmentRepository.deleteInstallment(id);
      }
      
      // Clear the current snackbar
      ScaffoldMessenger.of(context).hideCurrentSnackBar();
      
      // Immediately remove from local state to update UI
      setState(() {
        _installments.removeWhere((i) => _selectedInstallmentIds.contains(i.id));
        for (final id in _selectedInstallmentIds) {
          _installmentPayments.remove(id);
          _expandedStates.remove(id);
          _loadingPayments.remove(id);
        }
      });
      
      // Clear selection
      _clearSelection();
      
      // Also reload data from server to ensure consistency
      _loadData();
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              _selectedInstallmentIds.length == 1
                  ? l10n?.installmentDeleted ?? 'Installment deleted'
                  : l10n?.installmentsDeleted ?? 'Installments deleted',
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
            content: Text(l10n?.installmentDeleteError(e) ?? 'Error deleting: $e'),
            backgroundColor: AppTheme.errorColor,
          ),
        );
        // Reload data on error to ensure UI consistency
        _loadData();
      }
    }
  }

  Future<bool> _showBulkReminderConfirmationDialog() async {
    final l10n = AppLocalizations.of(context);
    
    return await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(l10n?.sendWhatsAppReminder ?? 'Send Reminder'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              l10n?.sendReminderConfirmation ?? 'Are you sure you want to send reminders to the selected installments?',
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: _InstallmentsListScreenState.whatsAppColor.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: _InstallmentsListScreenState.whatsAppColor.withOpacity(0.3),
                  width: 1,
                ),
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.info_outline,
                    color: _InstallmentsListScreenState.whatsAppColor,
                    size: 20,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      l10n?.sendReminderInfo ?? 'This will send individual messages to each client.',
                      style: TextStyle(
                        color: _InstallmentsListScreenState.whatsAppColor,
                        fontSize: 12,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text(
              l10n?.cancel ?? 'Cancel',
              style: TextStyle(color: AppTheme.textSecondary),
            ),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: ElevatedButton.styleFrom(
              backgroundColor: _InstallmentsListScreenState.whatsAppColor,
              foregroundColor: Colors.white,
            ),
            child: Text(l10n?.confirm ?? 'Send'),
          ),
        ],
      ),
    ) ?? false;
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
                          _isSelectionMode
                              ? '${l10n?.selectedItems ?? 'Selected'}: ${_selectedInstallmentIds.length}'
                              : '${_filteredAndSortedInstallments.length} ${_getItemsText(_filteredAndSortedInstallments.length)}',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w400,
                            color: _isSelectionMode ? AppTheme.primaryColor : AppTheme.textSecondary,
                          ),
                        ),
                      ],
                    ),
                    const Spacer(),
                    // Show different controls based on selection mode
                    if (_isSelectionMode) ...[
                      // Clear selection button - light grey (at the very left)
                      CustomButton(
                        text: l10n?.cancelSelection ?? 'Cancel Selection',
                        onPressed: _clearSelection,
                        color: Colors.grey[100],
                        textColor: AppTheme.textSecondary,
                        showIcon: false,
                        height: 36,
                        fontSize: 13,
                      ),
                      const SizedBox(width: 8),
                      // Select All button - subtle style
                      CustomButton(
                        text: l10n?.selectAll ?? 'Select All',
                        onPressed: _selectAll,
                        color: AppTheme.subtleBackgroundColor,
                        textColor: AppTheme.primaryColor,
                        showIcon: false,
                        height: 36,
                        fontSize: 13,
                      ),
                      const SizedBox(width: 8),
                      // Select All Overdue button - same style as Select All
                      CustomButton(
                        text: l10n?.selectAllOverdue ?? 'Select All Overdue',
                        onPressed: _selectAllOverdue,
                        color: AppTheme.subtleBackgroundColor,
                        textColor: AppTheme.primaryColor,
                        showIcon: false,
                        height: 36,
                        fontSize: 13,
                      ),
                      const SizedBox(width: 8),
                      // Delete button - error color
                      CustomButton(
                        text: l10n?.deleteAction ?? 'Delete',
                        onPressed: _selectedInstallmentIds.isNotEmpty ? _deleteBulkInstallments : null,
                        color: AppTheme.errorColor,
                        icon: Icons.delete_outline,
                        height: 36,
                        fontSize: 13,
                      ),
                      const SizedBox(width: 8),
                      // Send WhatsApp Reminders button - primary action
                      CustomButton(
                        text: l10n?.sendWhatsAppReminder ?? 'Send Reminder',
                        onPressed: _sendBulkReminders,
                        color: whatsAppColor,
                        icon: Icons.chat_bubble_outline,
                      ),
                    ] else ...[
                      // Regular mode controls
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
                        onPressed: () => _showCreateInstallmentDialog(),
                      ),
                    ],
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
                                // No checkbox column - using background color for selection
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
                                      
                                      // Use pre-calculated values from optimized response
                                      final clientName = installment is InstallmentModel ? (installment.clientName ?? AppLocalizations.of(context)?.unknown ?? 'Unknown') : (AppLocalizations.of(context)?.unknown ?? 'Unknown');
                                      final paidAmount = installment is InstallmentModel ? (installment.paidAmount ?? 0.0) : 0.0;
                                      final leftAmount = installment is InstallmentModel ? (installment.remainingAmount ?? installment.installmentPrice) : installment.installmentPrice;
                                      
                                      // Create next payment from optimized data
                                      InstallmentPayment? nextPayment;
                                      if (installment is InstallmentModel && installment.nextPaymentDate != null) {
                                        // Determine payment number: 0 for down payment, 1+ for monthly payments
                                        int paymentNumber;
                                        if (installment.downPayment > 0 && installment.nextPaymentDate == installment.downPaymentDate) {
                                          paymentNumber = 0; // Down payment
                                        } else {
                                          // Calculate which monthly payment this is based on paid payments
                                          // If down payment exists, subtract 1 from paid payments to get monthly payment number
                                          int monthlyPaymentsPaid = installment.paidPayments ?? 0;
                                          if (installment.downPayment > 0) {
                                            monthlyPaymentsPaid = monthlyPaymentsPaid - 1; // Subtract down payment
                                          }
                                          paymentNumber = monthlyPaymentsPaid + 1; // Next monthly payment number
                                        }
                                        
                                        nextPayment = InstallmentPayment(
                                          id: '${installment.id}_next',
                                          installmentId: installment.id,
                                          paymentNumber: paymentNumber,
                                          dueDate: installment.nextPaymentDate!,
                                          expectedAmount: installment.nextPaymentAmount ?? 0.0,
                                          isPaid: false,
                                          paidDate: null,
                                          createdAt: DateTime.now(),
                                          updatedAt: DateTime.now(),
                                        );
                                      }
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
                                          isLoadingPayments: _loadingPayments.contains(installment.id),
                                          onTap: _isSelectionMode 
                                              ? () => _toggleSelection(installment.id)
                                              : () => context.go('/installments/${installment.id}'),
                                          onClientTap: () => context.go('/clients/${installment.clientId}'),
                                          onExpansionChanged: (expanded) {
                                            setState(() {
                                              _expandedStates[installment.id] = expanded;
                                            });
                                            
                                            // Load payments only when expanding and if not already loaded
                                            if (expanded && (_installmentPayments[installment.id]?.isEmpty ?? true)) {
                                              _loadPaymentsForInstallment(installment.id);
                                            }
                                          },
                                          onDataChanged: () => _loadData(),
                                          onInstallmentUpdated: (updatedInstallment) {
                                            setState(() {
                                              // Find and update the specific installment in the list
                                              final index = _installments.indexWhere((i) => i.id == updatedInstallment.id);
                                              if (index != -1) {
                                                // Update the installment
                                                _installments[index] = updatedInstallment;
                                                
                                                // Set expansion state to collapsed since the widget will rebuild and collapse
                                                _expandedStates[updatedInstallment.id] = false;
                                                
                                                // Clear the payments since the installment collapsed
                                                _installmentPayments[updatedInstallment.id] = [];
                                              }
                                            });
                                          },
                                          onDelete: () => _deleteInstallment(installment),
                                          onSelect: () => _toggleSelection(installment.id),
                                          isSelected: _selectedInstallmentIds.contains(installment.id),
                                          onSelectionToggle: () => _toggleSelection(installment.id),
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
        // Clear cache to ensure fresh data after deletion
        final cache = CacheService();
        final authService = AuthServiceProvider.of(context);
        final currentUser = await authService.getCurrentUser();
        
        if (currentUser != null) {
          cache.remove(CacheService.installmentsKey(currentUser.id));
          cache.remove(CacheService.analyticsKey(currentUser.id));
        }
        cache.remove(CacheService.installmentKey(installment.id));
        cache.remove(CacheService.paymentsKey(installment.id));
        
        // Delete from server
        await _installmentRepository.deleteInstallment(installment.id);
        
        // Immediately remove from local state to update UI
        setState(() {
          _installments.removeWhere((i) => i.id == installment.id);
          _installmentPayments.remove(installment.id);
          _expandedStates.remove(installment.id);
          _loadingPayments.remove(installment.id);
        });
        
        // Also reload data from server to ensure consistency
        _loadData();
        
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(l10n?.installmentDeleted ?? 'Рассрочка удалена'),
              backgroundColor: AppTheme.successColor,
            ),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(l10n?.installmentDeleteError(e) ?? 'Ошибка удаления: $e'),
              backgroundColor: AppTheme.errorColor,
            ),
          );
          // Reload data on error to ensure UI consistency
          _loadData();
        }
      }
    }
  }

  void _showCreateInstallmentDialog() {
    showDialog(
      context: context,
      builder: (context) => CreateInstallmentDialog(
        onSuccess: _loadData,
      ),
    );
  }
} 