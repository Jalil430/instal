import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:instal_app/core/localization/app_localizations.dart';
import 'package:instal_app/core/theme/app_theme.dart';
import 'package:instal_app/features/installments/data/models/installment_model.dart';
import 'package:instal_app/features/installments/domain/entities/installment.dart';
import 'package:instal_app/features/installments/domain/entities/installment_payment.dart';
import 'package:instal_app/features/installments/screens/installments_list_screen.dart';
import 'package:instal_app/features/installments/services/reminder_service.dart';
import 'package:instal_app/features/installments/widgets/payment_registration_dialog.dart';
import 'package:instal_app/shared/widgets/custom_button.dart';
import 'package:instal_app/shared/widgets/custom_search_bar.dart';
import 'package:instal_app/shared/widgets/custom_dropdown.dart';
import 'package:instal_app/shared/widgets/custom_toggle.dart';
import 'package:instal_app/features/wallets/widgets/wallet_selector.dart';
import 'package:instal_app/features/wallets/domain/entities/wallet.dart';
import 'package:instal_app/features/wallets/domain/entities/wallet_balance.dart';
import 'package:instal_app/features/wallets/data/repositories/wallet_repository_impl.dart';
import 'package:instal_app/features/wallets/data/datasources/wallet_remote_datasource_impl.dart';
import 'package:instal_app/features/auth/presentation/widgets/auth_service_provider.dart';
import 'package:intl/intl.dart';

class InstallmentsListScreenMobile extends StatelessWidget {
  final InstallmentsListScreenState state;

  const InstallmentsListScreenMobile({super.key, required this.state});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final currencyFormat = NumberFormat('#,###', 'ru_RU');

    return Scaffold(
      backgroundColor: AppTheme.backgroundColor,
      appBar: AppBar(
        titleSpacing: 16,
        title:
            state.isSelectionMode
                ? Text(
                  l10n?.installments ?? 'Рассрочки',
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                  ),
                )
                : Row(
                  children: [
                    Text(
                      l10n?.installments ?? 'Рассрочки',
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                    child: CustomSearchBar(
                      value: state.searchQuery,
                      onChanged: state.setSearchQuery,
                      hintText: '${l10n?.search ?? 'Поиск'}...',
                      height: 36,
                    ),
                  ),
                  ],
                ),
        backgroundColor: AppTheme.surfaceColor,
        elevation: 1,
        actions: [
          if (state.isSelectionMode)
            IconButton(
              icon: const Icon(Icons.close),
              onPressed: state.clearSelection,
              tooltip: l10n?.cancelSelection ?? 'Cancel Selection',
            )
          else ...[
            if (state.hasActiveFilters)
              IconButton(
                icon: const Icon(Icons.filter_alt_off),
                tooltip: l10n?.resetFilters ?? 'Reset filters',
                onPressed: state.resetFilters,
              ),
            IconButton(
              icon: const Icon(Icons.tune),
              tooltip: l10n?.filters ?? 'Filters',
              onPressed: () => _showFiltersSheet(context),
            ),
          ],
        ],
        bottom:
            state.isSelectionMode
                ? PreferredSize(
                  preferredSize: const Size.fromHeight(48),
                  child: Container(
                    color: AppTheme.subtleBackgroundColor,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 8,
                    ),
                    child: Row(
                      children: [
                        Text(
                          '${state.selectedInstallmentIds.length} ${l10n?.selectedItems ?? 'selected'}',
                          style: const TextStyle(
                            fontWeight: FontWeight.w500,
                            color: AppTheme.primaryColor,
                          ),
                        ),
                        const Spacer(),
                        _buildPopupMenu(context),
                      ],
                    ),
                  ),
                )
                : null,
      ),
      body:
          state.isLoading
              ? const Center(child: CircularProgressIndicator())
              : state.filteredAndSortedInstallments.isEmpty
              ? Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.search_off, size: 64, color: Colors.grey[400]),
                    const SizedBox(height: 16),
                    Text(
                      l10n?.notFound ?? 'Ничего не найдено',
                      style: TextStyle(fontSize: 16, color: Colors.grey[600]),
                    ),
                  ],
                ),
              )
              : RefreshIndicator(
                onRefresh: () async {
                  state.forceRefresh();
                  // Need to return a future to satisfy RefreshIndicator
                  return Future.value();
                },
                child: ListView.builder(
                  padding: const EdgeInsets.only(top: 8, bottom: 80),
                  physics: const AlwaysScrollableScrollPhysics(),
                  itemCount: state.filteredAndSortedInstallments.length,
                  itemBuilder: (context, index) {
                    final installment =
                        state.filteredAndSortedInstallments[index];

                    // Use pre-calculated values from optimized response
                    final clientName =
                        installment is InstallmentModel
                            ? (installment.clientName ??
                                l10n?.unknown ??
                                'Unknown')
                            : (l10n?.unknown ?? 'Unknown');
                    final paidAmount =
                        installment is InstallmentModel
                            ? (installment.paidAmount ?? 0.0)
                            : 0.0;
                    final leftAmount =
                        installment is InstallmentModel
                            ? (installment.remainingAmount ??
                                installment.installmentPrice)
                            : installment.installmentPrice;

                    // Get payment status using dynamic calculation
                    final status =
                        installment is InstallmentModel
                            ? installment.dynamicStatus
                            : 'предстоящий';

                    // Create next payment from optimized data
                    InstallmentPayment? nextPayment;
                    if (installment is InstallmentModel &&
                        installment.nextPaymentDate != null) {
                      // Determine correct next payment number
                      int paymentNumber;
                      if (installment.downPayment > 0 &&
                          installment.nextPaymentDate ==
                              installment.downPaymentDate) {
                        paymentNumber = 0; // Down payment due next
                      } else {
                        int monthlyPaymentsPaid = installment.paidPayments ?? 0;
                        if (installment.downPayment > 0) {
                          monthlyPaymentsPaid =
                              monthlyPaymentsPaid - 1; // subtract down payment
                        }
                        if (monthlyPaymentsPaid < 0) monthlyPaymentsPaid = 0;
                        paymentNumber =
                            monthlyPaymentsPaid +
                            1; // next monthly payment number
                      }

                      nextPayment = InstallmentPayment(
                        id: '${installment.id}_next',
                        installmentId: installment.id,
                        paymentNumber: paymentNumber,
                        dueDate: installment.nextPaymentDate!,
                        expectedAmount: installment.nextPaymentAmount ?? 0.0,
                        paidAmount: 0.0,
                        isPaid: false,
                        paidDate: null,
                        createdAt: DateTime.now(),
                        updatedAt: DateTime.now(),
                      );
                    }

                    return _buildInstallmentCard(
                      context,
                      installment,
                      clientName,
                      paidAmount,
                      leftAmount,
                      status,
                      nextPayment,
                      currencyFormat,
                    );
                  },
                ),
              ),
      floatingActionButton:
          state.isSelectionMode
              ? null
              : FloatingActionButton(
                onPressed: state.showCreateInstallmentDialog,
                backgroundColor: AppTheme.primaryColor,
                child: const Icon(Icons.add, color: Colors.white),
              ),
    );
  }

  void _showFiltersSheet(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      backgroundColor: AppTheme.surfaceColor,
      builder: (context) {
        return _MobileFilterSheet(state: state);
      },
    );
  }

  Widget _buildInstallmentCard(
    BuildContext context,
    Installment installment,
    String clientName,
    double paidAmount,
    double leftAmount,
    String status,
    InstallmentPayment? nextPayment,
    NumberFormat currencyFormat,
  ) {
    final l10n = AppLocalizations.of(context);

    // Determine status color and text with days count
    Color statusColor;
    String statusText;

    // Calculate days difference for overdue and upcoming statuses
    String? daysText;
    if (nextPayment != null &&
        (status == 'просрочено' || status == 'предстоящий')) {
      final now = DateTime.now();
      final today = DateTime(now.year, now.month, now.day);
      final dueDate = nextPayment.dueDate;
      final due = DateTime(dueDate.year, dueDate.month, dueDate.day);
      final daysDifference = due.difference(today).inDays;

      if (status == 'просрочено' && daysDifference < 0) {
        daysText =
            l10n?.daysShort(daysDifference) ?? '${daysDifference.abs()}d';
      } else if (status == 'предстоящий' && daysDifference > 0) {
        daysText = l10n?.daysShort(daysDifference) ?? '${daysDifference}d';
      }
    }

    switch (status) {
      case 'просрочено':
        statusColor = AppTheme.errorColor;
        statusText = l10n?.overdue ?? 'Просрочено';
        break;
      case 'к оплате':
        statusColor = AppTheme.warningColor;
        statusText = l10n?.dueToPay ?? 'К оплате';
        break;
      case 'оплачено':
        statusColor = AppTheme.successColor;
        statusText = l10n?.paid ?? 'Оплачено';
        break;
      case 'предстоящий':
      default:
        statusColor = AppTheme.pendingColor;
        statusText = l10n?.upcoming ?? 'Предстоящий';
    }

    final dateFormat = DateFormat('dd.MM.yyyy');
    final nextPaymentDate =
        nextPayment?.dueDate != null
            ? dateFormat.format(nextPayment!.dueDate)
            : '-';

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      elevation: 1,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(
          color:
              state.selectedInstallmentIds.contains(installment.id)
                  ? AppTheme.primaryColor
                  : Colors.transparent,
          width: 2,
        ),
      ),
      child: InkWell(
        onTap:
            () =>
                state.isSelectionMode
                    ? state.toggleSelection(installment.id)
                    : context.go('/installments/${installment.id}'),
        onLongPress: () => state.toggleSelection(installment.id),
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Product name and status
              Row(
                children: [
                  Expanded(
                    child: Text(
                      installment.productName,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // Days count on the left
                      if (daysText != null) ...[
                        Text(
                          daysText,
                          style: TextStyle(
                            color: statusColor,
                            fontSize: 12,
                            fontWeight: FontWeight.w400,
                          ),
                        ),
                        const SizedBox(width: 4),
                      ],
                      // Status badge with desktop styling but smaller
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 7,
                          vertical: 4,
                        ), // Slightly bigger padding
                        decoration: BoxDecoration(
                          color: statusColor.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(
                            10,
                          ), // Same as desktop
                          border: Border.all(
                            color: statusColor.withOpacity(
                              0.2,
                            ), // Same as desktop
                            width: 1,
                          ),
                        ),
                        child: Text(
                          statusText,
                          style: TextStyle(
                            fontSize: 12, // Same as desktop now
                            fontWeight: FontWeight.w400, // Same as desktop
                            color: statusColor,
                          ),
                          textAlign: TextAlign.center, // Same as desktop
                        ),
                      ),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 8),

              // Client name
              InkWell(
                onTap: () => context.go('/clients/${installment.clientId}'),
                child: Row(
                  children: [
                    const Icon(
                      Icons.person_outline,
                      size: 18,
                      color: AppTheme.primaryColor,
                    ),
                    const SizedBox(width: 4),
                    Expanded(
                      child: Text(
                        clientName,
                        style: const TextStyle(
                          color: AppTheme.primaryColor,
                          fontSize: 16,
                          fontWeight: FontWeight.w500,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),

              // Payment info
              Row(
                children: [
                  // Paid amount
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          l10n?.paidAmount ?? 'Paid',
                          style: const TextStyle(
                            fontSize: 12,
                            color: AppTheme.textSecondary,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          currencyFormat.format(paidAmount) + ' ₽',
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                            color: AppTheme.successColor,
                          ),
                        ),
                      ],
                    ),
                  ),

                  // Left amount
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          l10n?.leftAmount ?? 'Left',
                          style: const TextStyle(
                            fontSize: 12,
                            color: AppTheme.textSecondary,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          currencyFormat.format(leftAmount) + ' ₽',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                            color:
                                leftAmount > 0
                                    ? Colors.orange[700]
                                    : AppTheme.successColor,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 16),

              // Next payment info
              if (nextPayment != null) ...[
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: AppTheme.subtleBackgroundColor,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    children: [
                      const Icon(
                        Icons.calendar_today,
                        size: 16,
                        color: AppTheme.textSecondary,
                      ),
                      const SizedBox(width: 8),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            l10n?.nextPayment ?? 'Next Payment',
                            style: const TextStyle(
                              fontSize: 12,
                              color: AppTheme.textSecondary,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            '${currencyFormat.format(nextPayment.expectedAmount)} ₽ • $nextPaymentDate',
                            style: const TextStyle(fontWeight: FontWeight.w500),
                          ),
                        ],
                      ),
                      const Spacer(),
                      // Register payment icon
                      IconButton(
                        icon: const Icon(Icons.payment_outlined),
                        onPressed:
                            () =>
                                nextPayment != null
                                    ? _registerPayment(context, nextPayment)
                                    : null,
                        tooltip: l10n?.registerPayment ?? 'Register Payment',
                        iconSize: 20,
                        color:
                            nextPayment != null
                                ? AppTheme.primaryColor
                                : Colors.grey.withOpacity(0.5),
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(),
                      ),
                      const SizedBox(width: 8),
                      // WhatsApp reminder icon
                      IconButton(
                        icon: const Icon(Icons.chat_bubble_outline),
                        onPressed:
                            () => _sendSingleReminder(context, installment.id),
                        tooltip: l10n?.sendWhatsAppReminder ?? 'Send Reminder',
                        iconSize: 20,
                        color: InstallmentsListScreenState.whatsAppColor,
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(),
                      ),
                    ],
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPopupMenu(BuildContext context) {
    final l10n = AppLocalizations.of(context);

    return PopupMenuButton<String>(
      icon: const Icon(Icons.more_vert),
      onSelected: (value) {
        switch (value) {
          case 'select_all':
            state.selectAll();
            break;
          case 'select_overdue':
            state.selectAllOverdue();
            break;
          case 'send_reminders':
            state.sendBulkReminders();
            break;
          case 'delete':
            state.deleteBulkInstallments();
            break;
        }
      },
      itemBuilder:
          (context) => [
            PopupMenuItem<String>(
              value: 'select_all',
              child: Row(
                children: [
                  const Icon(Icons.select_all, size: 18),
                  const SizedBox(width: 12),
                  Text(l10n?.selectAll ?? 'Select All'),
                ],
              ),
            ),
            PopupMenuItem<String>(
              value: 'select_overdue',
              child: Row(
                children: [
                  const Icon(Icons.warning_amber, size: 18),
                  const SizedBox(width: 12),
                  Text(l10n?.selectAllOverdue ?? 'Select Overdue'),
                ],
              ),
            ),
            const PopupMenuDivider(),
            PopupMenuItem<String>(
              value: 'send_reminders',
              child: Row(
                children: [
                  Icon(
                    Icons.chat_bubble_outline,
                    size: 18,
                    color: InstallmentsListScreenState.whatsAppColor,
                  ),
                  const SizedBox(width: 12),
                  Text(l10n?.sendWhatsAppReminder ?? 'Send Reminder'),
                ],
              ),
            ),
            PopupMenuItem<String>(
              value: 'delete',
              child: Row(
                children: [
                  const Icon(
                    Icons.delete_outline,
                    size: 18,
                    color: AppTheme.errorColor,
                  ),
                  const SizedBox(width: 12),
                  Text(
                    l10n?.deleteAction ?? 'Delete',
                    style: const TextStyle(color: AppTheme.errorColor),
                  ),
                ],
              ),
            ),
          ],
    );
  }

  void _sendSingleReminder(BuildContext context, String installmentId) async {
    final l10n = AppLocalizations.of(context);

    // Show confirmation dialog
    final confirmed = await showDialog<bool>(
      context: context,
      builder:
          (context) => AlertDialog(
            title: Text(l10n?.sendWhatsAppReminder ?? 'Send Reminder'),
            content: Text(
              l10n?.sendReminderConfirmation ??
                  'Are you sure you want to send a reminder?',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(false),
                child: Text(l10n?.cancel ?? 'Cancel'),
              ),
              ElevatedButton(
                onPressed: () => Navigator.of(context).pop(true),
                style: ElevatedButton.styleFrom(
                  backgroundColor: InstallmentsListScreenState.whatsAppColor,
                ),
                child: Text(l10n?.confirm ?? 'Send'),
              ),
            ],
          ),
    );

    if (confirmed == true) {
      await ReminderService.sendBulkReminders(
        context: context,
        installmentIds: [installmentId],
        templateType: 'manual',
      );
    }
  }

  // Register payment method for handling payment registration dialog
  void _registerPayment(BuildContext context, InstallmentPayment payment) {
    // Calculate position for dialog (center of screen for mobile)
    final screenSize = MediaQuery.of(context).size;
    final position = Offset(screenSize.width / 2, screenSize.height / 2);

    PaymentRegistrationDialog.show(
      context: context,
      position: position,
      payment: payment,
      onPaymentRegistered: (updatedInstallment) {
        // Legacy path: still refresh in case background mode not used
        state.forceRefresh();
      },
      onSubmitInBackground: state.submitPaymentInBackground,
    );
  }
}

class _MobileFilterSheet extends StatefulWidget {
  final InstallmentsListScreenState state;

  const _MobileFilterSheet({required this.state});

  @override
  State<_MobileFilterSheet> createState() => _MobileFilterSheetState();
}

class _MobileFilterSheetState extends State<_MobileFilterSheet> {
  late String _status;
  late String _wallet;
  late String _sortBy;
  late bool _ascending;
  late String _createdDateFilter;

  // For wallet selector
  List<Wallet> _wallets = [];
  Map<String, WalletBalance> _walletBalances = {};
  Wallet? _selectedWallet;
  bool _isLoadingWallets = true;

  InstallmentsListScreenState get state => widget.state;

  @override
  void initState() {
    super.initState();
    _status = state.statusFilter;
    _wallet = state.walletFilter;
    _sortBy = state.sortBy;
    _ascending = state.sortAscending;
    _createdDateFilter = state.createdDateFilter;
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _loadWallets();
  }

  Future<void> _loadWallets() async {
    if (!mounted) return;
    
    print('🔄 Mobile: Starting wallet loading...');
    setState(() => _isLoadingWallets = true);
    
    try {
      final authService = AuthServiceProvider.of(context);
      final currentUser = await authService.getCurrentUser();
      
      if (currentUser == null) {
        print('❌ Mobile: No current user found');
        throw Exception('User not authenticated');
      }
      
      print('👤 Mobile: Loading wallets for user: ${currentUser.id}');
      final walletRepository = WalletRepositoryImpl(WalletRemoteDataSourceImpl());
      
      // Load wallets and balances
      final wallets = await walletRepository.getAllWallets(currentUser.id);
      print('📦 Mobile: Loaded ${wallets.length} wallets');
      
      if (!mounted) return;
      
      final balances = await walletRepository.getAllWalletBalances(currentUser.id);
      print('💰 Mobile: Loaded ${balances.length} wallet balances');
      
      if (!mounted) return;
      
      final balancesMap = {for (final b in balances) b.walletId: b};

      setState(() {
        _wallets = wallets;
        _walletBalances = balancesMap;
        _isLoadingWallets = false;
        
        // Set selected wallet based on current filter
        if (_wallet != 'all' && _wallet != 'noWallet') {
          _selectedWallet = wallets.cast<Wallet?>().firstWhere(
            (w) => w?.id == _wallet,
            orElse: () => null,
          );
        }
      });
      
      print('✅ Mobile: Wallet loading completed successfully');
    } catch (e) {
      print('❌ Mobile: Error loading wallets: $e');
      if (mounted) {
        setState(() => _isLoadingWallets = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);

    return Padding(
      padding: EdgeInsets.only(
        left: 16,
        right: 16,
        top: 16,
        bottom: MediaQuery.of(context).viewInsets.bottom + 16,
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            Row(
              children: [
                Text(
                  l10n?.filters ?? 'Фильтры',
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const Spacer(),
                TextButton(
                  onPressed: () {
                    state.resetFilters();
                    setState(() {
                      _status = 'all';
                      _wallet = 'all';
                      _sortBy = 'status';
                      _ascending = true;
                      _createdDateFilter = 'all';
                      _selectedWallet = null;
                    });
                  },
                  child: Text(l10n?.resetFilters ?? 'Сбросить'),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // Wallet Filter (moved to top)
            if (_isLoadingWallets) ...[
              Text(
                l10n?.wallet ?? 'Кошелек',
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: AppTheme.textPrimary,
                ),
              ),
              const SizedBox(height: 8),
              Container(
                width: double.infinity,
                height: 44,
                padding: const EdgeInsets.symmetric(horizontal: 16),
                decoration: BoxDecoration(
                  color: AppTheme.subtleBackgroundColor,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: AppTheme.borderColor),
                ),
                child: Row(
                  children: [
                    SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        valueColor: AlwaysStoppedAnimation<Color>(AppTheme.primaryColor),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      l10n?.loadingWallets ?? 'Загрузка кошельков...',
                      style: TextStyle(
                        color: AppTheme.textSecondary,
                        fontSize: 14,
                        fontWeight: FontWeight.w400,
                      ),
                    ),
                  ],
                ),
              ),
            ] else
              _buildDropdown(
                label: l10n?.wallet ?? 'Кошелек',
                value: _wallet,
                options: _getWalletFilterOptions(),
                onChanged: (value) {
                  _wallet = value;
                  if (_wallet == 'all' || _wallet == 'noWallet') {
                    _selectedWallet = null;
                  } else {
                    _selectedWallet = _wallets.cast<Wallet?>().firstWhere(
                      (w) => w?.id == _wallet,
                      orElse: () => null,
                    );
                  }
                  _applyFilters();
                },
              ),
            const SizedBox(height: 16),

            const SizedBox(height: 16),

            _buildDropdown(
              label: l10n?.status ?? 'Статус',
              value: _status,
              options: _getStatusFilterOptions(),
              onChanged: (value) {
                _status = value;
                state.setStatusFilter(_status);
              },
            ),
            const SizedBox(height: 16),

            _buildDropdown(
              label: 'Дата создания',
              value: _createdDateFilter,
              options: _getDateFilterOptions(),
              onChanged: (value) {
                _createdDateFilter = value;
                state.setCreatedDateFilter(_createdDateFilter);
              },
            ),
            const SizedBox(height: 16),

            _buildDropdown(
              label: 'Сортировать по',
              value: _sortBy,
              options: _getSortOptions(),
              onChanged: (value) {
                _sortBy = value;
                state.setSortBy(_sortBy);
              },
            ),
            const SizedBox(height: 12),
            
            // Sort Direction
            CustomToggle<bool>(
              value: _ascending,
              onChanged: (value) {
                _ascending = value;
                state.setSortAscending(_ascending);
                setState(() {});
              },
              options: [
                CustomToggleOption<bool>(
                  value: true,
                  label: l10n?.ascending ?? 'По возрастанию',
                  icon: Icons.arrow_upward,
                ),
                CustomToggleOption<bool>(
                  value: false,
                  label: l10n?.descending ?? 'По убыванию',
                  icon: Icons.arrow_downward,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDropdown({
    required String label,
    required String value,
    required Map<String, String> options,
    required ValueChanged<String> onChanged,
  }) {
    final currentValue = options.containsKey(value) ? value : options.keys.first;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: AppTheme.textPrimary,
          ),
        ),
        const SizedBox(height: 8),
        CustomDropdown<String>(
          value: currentValue,
          items: options,
          onChanged: (selected) {
            if (selected != null) {
              setState(() {
                onChanged(selected);
              });
            }
          },
          width: double.infinity,
        ),
      ],
    );
  }

  Map<String, String> _getStatusFilterOptions() {
    return state.getTranslatedStatusFilters();
  }

  Map<String, String> _getWalletFilterOptions() {
    final l10n = AppLocalizations.of(context);
    final Map<String, String> options = {
      'all': l10n?.all ?? 'Все',
      'noWallet': l10n?.withoutWallet ?? 'Без кошелька',
    };
    
    // Add actual wallets
    for (final wallet in _wallets) {
      final balance = _walletBalances[wallet.id];
      final balanceText = balance != null
          ? NumberFormat.currency(
              locale: l10n?.locale.languageCode == 'ru' ? 'ru_RU' : 'en_US',
              symbol: l10n?.locale.languageCode == 'ru' ? '₽' : '\$',
              decimalDigits: 2,
            ).format(balance.balance)
          : NumberFormat.currency(
              locale: l10n?.locale.languageCode == 'ru' ? 'ru_RU' : 'en_US',
              symbol: l10n?.locale.languageCode == 'ru' ? '₽' : '\$',
              decimalDigits: 2,
            ).format(0);
      
      options[wallet.id] = '${wallet.name} ($balanceText)';
    }
    
    return options;
  }

  Map<String, String> _getDateFilterOptions() {
    return {
      'all': 'Все',
      'today': 'Сегодня',
      'yesterday': 'Вчера',
      'thisWeek': 'На этой неделе',
      'lastWeek': 'На прошлой неделе',
      'thisMonth': 'В этом месяце',
      'lastMonth': 'В прошлом месяце',
      'last3Months': 'За последние 3 месяца',
      'last6Months': 'За последние 6 месяцев',
      'thisYear': 'В этом году',
    };
  }

  Map<String, String> _getSortOptions() {
    return {
      'status': 'Статус',
      'installmentNumber': 'Номер',
      'amount': 'Стоимость',
    };
  }

  void _applyFilters() {
    if (state.statusFilter != _status) {
      state.setStatusFilter(_status);
    }
    if (state.walletFilter != _wallet) {
      state.setWalletFilter(_wallet);
    }
    if (state.sortBy != _sortBy) {
      state.setSortBy(_sortBy);
    }
    if (state.sortAscending != _ascending) {
      state.setSortAscending(_ascending);
    }
    if (state.createdDateFilter != _createdDateFilter) {
      state.setCreatedDateFilter(_createdDateFilter);
    }
  }

}
