import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:instal_app/core/localization/app_localizations.dart';
import 'package:instal_app/core/theme/app_theme.dart';
import 'package:instal_app/features/installments/domain/entities/installment_payment.dart';
import 'package:instal_app/features/installments/data/models/installment_model.dart';
import 'package:instal_app/features/installments/screens/installments_list_screen.dart';
import 'package:instal_app/features/installments/widgets/installment_list_item.dart';
import 'package:instal_app/shared/widgets/custom_button.dart';
import 'package:instal_app/shared/widgets/custom_search_bar.dart';
import 'package:instal_app/shared/widgets/custom_dropdown.dart';
import 'package:instal_app/features/wallets/widgets/wallet_selector.dart';
import 'package:instal_app/features/wallets/domain/entities/wallet.dart';
import 'package:instal_app/features/wallets/domain/entities/wallet_balance.dart';
import 'package:instal_app/features/wallets/data/repositories/wallet_repository_impl.dart';
import 'package:instal_app/features/wallets/data/datasources/wallet_remote_datasource_impl.dart';
import 'package:instal_app/features/auth/presentation/widgets/auth_service_provider.dart';

class InstallmentsListScreenDesktop extends StatelessWidget {
  final InstallmentsListScreenState state;

  const InstallmentsListScreenDesktop({super.key, required this.state});

  void _openFiltersSheet(BuildContext context) {
    final l10n = AppLocalizations.of(context);

    showGeneralDialog(
      context: context,
      barrierDismissible: true,
      barrierLabel: l10n?.filters ?? 'Filters',
      barrierColor: Colors.black38,
      pageBuilder: (context, animation, secondaryAnimation) {
        return Align(
          alignment: Alignment.centerRight,
          child: FractionallySizedBox(
            widthFactor: 0.32,
            child: _InstallmentsFilterSheet(state: state),
          ),
        );
      },
      transitionBuilder: (context, animation, secondaryAnimation, child) {
        final offsetAnimation = Tween<Offset>(
          begin: const Offset(1, 0),
          end: Offset.zero,
        ).animate(CurvedAnimation(parent: animation, curve: Curves.easeOut));
        return SlideTransition(position: offsetAnimation, child: child);
      },
    );
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
                        Row(
                          children: [
                            Text(
                              l10n?.installments ?? 'Рассрочки',
                              style: const TextStyle(
                                fontSize: 20,
                                fontWeight: FontWeight.w600,
                                letterSpacing: -0.5,
                              ),
                            ),
                            const SizedBox(width: 12),
                            IconButton(
                              icon: const Icon(Icons.refresh, size: 20),
                              onPressed: state.forceRefresh,
                              tooltip: 'Обновить',
                              padding: EdgeInsets.zero,
                              constraints: const BoxConstraints(),
                            ),
                          ],
                        ),
                        Text(
                          state.isSelectionMode
                              ? '${l10n?.selectedItems ?? 'Selected'}: ${state.selectedInstallmentIds.length}'
                              : '${state.filteredAndSortedInstallments.length} ${state.getItemsText(state.filteredAndSortedInstallments.length)}',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w400,
                            color:
                                state.isSelectionMode
                                    ? AppTheme.primaryColor
                                    : AppTheme.textSecondary,
                          ),
                        ),
                      ],
                    ),
                    const Spacer(),
                    // Show different controls based on selection mode
                    if (state.isSelectionMode) ...[
                      // Clear selection button - light grey (at the very left)
                      CustomButton(
                        text: l10n?.cancelSelection ?? 'Cancel Selection',
                        onPressed: state.clearSelection,
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
                        onPressed: state.selectAll,
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
                        onPressed: state.selectAllOverdue,
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
                        onPressed:
                            state.selectedInstallmentIds.isNotEmpty
                                ? state.deleteBulkInstallments
                                : null,
                        color: AppTheme.errorColor,
                        icon: Icons.delete_outline,
                        height: 36,
                        fontSize: 13,
                      ),
                      const SizedBox(width: 8),
                      // Send WhatsApp Reminders button - primary action
                      CustomButton(
                        text: l10n?.sendWhatsAppReminder ?? 'Send Reminder',
                        onPressed: state.sendBulkReminders,
                        color: InstallmentsListScreenState.whatsAppColor,
                        icon: Icons.chat_bubble_outline,
                      ),
                    ] else ...[
                      // Regular mode controls
                      CustomSearchBar(
                        value: state.searchQuery,
                        onChanged: state.setSearchQuery,
                        hintText:
                            '${l10n?.search ?? 'Поиск'} ${state.getItemsText(0)}...',
                        width: 320,
                      ),
                      const SizedBox(width: 16),
                      _FilterButton(
                        onPressed: () => _openFiltersSheet(context),
                        hasActiveFilters: state.hasActiveFilters,
                        text: l10n?.filters ?? 'Filters',
                      ),
                      if (state.hasActiveFilters) ...[
                        const SizedBox(width: 8),
                        TextButton(
                          onPressed: state.resetFilters,
                          child: Text(l10n?.resetFilters ?? 'Reset filters'),
                        ),
                      ],
                      const SizedBox(width: 16),
                      CustomButton(
                        text: l10n?.addInstallment ?? 'Добавить рассрочку',
                        onPressed: () => state.showCreateInstallmentDialog(),
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
              child:
                  state.isLoading
                      ? Center(
                        child: Container(
                          padding: const EdgeInsets.all(20),
                          child: CircularProgressIndicator(
                            strokeWidth: 3,
                            valueColor: AlwaysStoppedAnimation<Color>(
                              AppTheme.brightPrimaryColor,
                            ),
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
                              padding: const EdgeInsets.symmetric(
                                horizontal: 16,
                                vertical: 16,
                              ),
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
                                  // Installment number column moved to the start
                                  SizedBox(
                                    width: 54,
                                    child: Text(
                                      '№',
                                      style: Theme.of(
                                        context,
                                      ).textTheme.labelMedium?.copyWith(
                                        color: AppTheme.textSecondary,
                                        fontWeight: FontWeight.w400,
                                        fontSize: 12,
                                        letterSpacing: 0.5,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 16),
                                  // Client header - more space for client names
                                  Expanded(
                                    flex: 5,
                                    child: Text(
                                      (l10n?.client ?? 'Клиент')
                                          .toUpperCase(),
                                      style: Theme.of(
                                        context,
                                      ).textTheme.labelMedium?.copyWith(
                                        color: AppTheme.textSecondary,
                                        fontWeight: FontWeight.w400,
                                        fontSize: 12,
                                        letterSpacing: 0.5,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 16),
                                  // Product header - reduced space for product names
                                  Expanded(
                                    flex: 3,
                                    child: Text(
                                      (l10n?.productNameHeader ??
                                              'Название товара')
                                          .toUpperCase(),
                                      style: Theme.of(
                                        context,
                                      ).textTheme.labelMedium?.copyWith(
                                        color: AppTheme.textSecondary,
                                        fontWeight: FontWeight.w400,
                                        fontSize: 12,
                                        letterSpacing: 0.5,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 16),
                                  // Total price header
                                  Expanded(
                                    flex: 2,
                                    child: Text(
                                      (l10n?.cost ?? 'Стоимость').toUpperCase(),
                                      style: Theme.of(
                                        context,
                                      ).textTheme.labelMedium?.copyWith(
                                        color: AppTheme.textSecondary,
                                        fontWeight: FontWeight.w400,
                                        fontSize: 12,
                                        letterSpacing: 0.5,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 16),
                                  // Paid amount header
                                  Expanded(
                                    flex: 2,
                                    child: Text(
                                      (l10n?.paidAmount ?? 'Оплачено')
                                          .toUpperCase(),
                                      style: Theme.of(
                                        context,
                                      ).textTheme.labelMedium?.copyWith(
                                        color: AppTheme.textSecondary,
                                        fontWeight: FontWeight.w400,
                                        fontSize: 12,
                                        letterSpacing: 0.5,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 16),
                                  // Remaining amount header
                                  Expanded(
                                    flex: 2,
                                    child: Text(
                                      (l10n?.leftAmount ?? 'Осталось')
                                          .toUpperCase(),
                                      style: Theme.of(
                                        context,
                                      ).textTheme.labelMedium?.copyWith(
                                        color: AppTheme.textSecondary,
                                        fontWeight: FontWeight.w400,
                                        fontSize: 12,
                                        letterSpacing: 0.5,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 16),
                                  // Due date header - moved to left of status
                                  Expanded(
                                    flex: 2,
                                    child: Text(
                                      (l10n?.dueDate ?? 'Срок оплаты')
                                          .toUpperCase(),
                                      style: Theme.of(
                                        context,
                                      ).textTheme.labelMedium?.copyWith(
                                        color: AppTheme.textSecondary,
                                        fontWeight: FontWeight.w400,
                                        fontSize: 12,
                                        letterSpacing: 0.5,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 16),
                                  // Status header - at the very right
                                  Expanded(
                                    flex: 2,
                                    child: Text(
                                      (l10n?.statusHeader ?? 'Статус')
                                          .toUpperCase(),
                                      style: Theme.of(
                                        context,
                                      ).textTheme.labelMedium?.copyWith(
                                        color: AppTheme.textSecondary,
                                        fontWeight: FontWeight.w400,
                                        fontSize: 12,
                                        letterSpacing: 0.5,
                                      ),
                                    ),
                                  ),
                                  // Space for the expand arrow column
                                  Container(width: 44),
                                ],
                              ),
                            ),

                            // Table Content
                            Expanded(
                              child:
                                  state.filteredAndSortedInstallments.isEmpty
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
                                        itemCount:
                                            state
                                                .filteredAndSortedInstallments
                                                .length,
                                        itemBuilder: (context, index) {
                                          final installment =
                                              state
                                                  .filteredAndSortedInstallments[index];
                                          final payments =
                                              state
                                                  .installmentPayments[installment
                                                  .id] ??
                                              [];

                                          // Use pre-calculated values from optimized response
                                          final clientName =
                                              installment is InstallmentModel
                                                  ? (installment.clientName ??
                                                      l10n?.unknown ??
                                                      'Unknown')
                                                  : (l10n?.unknown ??
                                                      'Unknown');
                                          final paidAmount =
                                              installment is InstallmentModel
                                                  ? (installment.paidAmount ??
                                                      0.0)
                                                  : 0.0;
                                          final leftAmount =
                                              installment is InstallmentModel
                                                  ? (installment
                                                          .remainingAmount ??
                                                      installment
                                                          .installmentPrice)
                                                  : installment
                                                      .installmentPrice;

                                          // Create next payment from optimized data
                                          InstallmentPayment? nextPayment;
                                          if (installment is InstallmentModel &&
                                              installment.nextPaymentDate !=
                                                  null) {
                                            // Determine payment number: 0 for down payment, 1+ for monthly payments
                                            int paymentNumber;
                                            if (installment.downPayment > 0 &&
                                                installment.nextPaymentDate ==
                                                    installment
                                                        .downPaymentDate) {
                                              paymentNumber = 0; // Down payment
                                            } else {
                                              // Calculate which monthly payment this is based on paid payments
                                              // If down payment exists, subtract 1 from paid payments to get monthly payment number
                                              int monthlyPaymentsPaid =
                                                  installment.paidPayments ?? 0;
                                              if (installment.downPayment > 0) {
                                                monthlyPaymentsPaid =
                                                    monthlyPaymentsPaid -
                                                    1; // Subtract down payment
                                              }
                                              paymentNumber =
                                                  monthlyPaymentsPaid +
                                                  1; // Next monthly payment number
                                            }

                                            nextPayment = InstallmentPayment(
                                              id: '${installment.id}_next',
                                              installmentId: installment.id,
                                              paymentNumber: paymentNumber,
                                              dueDate:
                                                  installment.nextPaymentDate!,
                                              expectedAmount:
                                                  installment
                                                      .nextPaymentAmount ??
                                                  0.0,
                                              paidAmount: 0.0,
                                              isPaid: false,
                                              paidDate: null,
                                              createdAt: DateTime.now(),
                                              updatedAt: DateTime.now(),
                                            );
                                          }
                                          return AnimatedContainer(
                                            duration: Duration(
                                              milliseconds: 100 + (index * 50),
                                            ),
                                            curve: Curves.easeOutCubic,
                                            child: InstallmentListItem(
                                              installment: installment,
                                              clientName: clientName,
                                              productName:
                                                  installment.productName,
                                              installmentNumber:
                                                  installment.installmentNumber,
                                              paidAmount: paidAmount,
                                              leftAmount: leftAmount,
                                              payments: payments,
                                              nextPayment: nextPayment,
                                              isExpanded:
                                                  state
                                                      .expandedStates[installment
                                                      .id] ??
                                                  false,
                                              isLoadingPayments: state
                                                  .loadingPayments
                                                  .contains(installment.id),
                                              isBusy: state
                                                  .loadingItemOperations
                                                  .contains(installment.id),
                                              onTap:
                                                  state.isSelectionMode
                                                      ? () =>
                                                          state.toggleSelection(
                                                            installment.id,
                                                          )
                                                      : () => context.go(
                                                        '/installments/${installment.id}',
                                                      ),
                                              onClientTap:
                                                  () => context.go(
                                                    '/clients/${installment.clientId}',
                                                  ),
                                              onExpansionChanged: (expanded) {
                                                state.setStateWrapper(() {
                                                  state.expandedStates[installment
                                                          .id] =
                                                      expanded;
                                                });

                                                // Load payments only when expanding and if not already loaded
                                                if (expanded &&
                                                    (state
                                                            .installmentPayments[installment
                                                                .id]
                                                            ?.isEmpty ??
                                                        true)) {
                                                  state
                                                      .loadPaymentsForInstallment(
                                                        installment.id,
                                                      );
                                                }
                                              },
                                              onDataChanged:
                                                  () => state.loadData(),
                                              onInstallmentUpdated: (
                                                updatedInstallment,
                                              ) {
                                                state.setStateWrapper(() {
                                                  // Find and update the specific installment in the list
                                                  final index = state
                                                      .installments
                                                      .indexWhere(
                                                        (i) =>
                                                            i.id ==
                                                            updatedInstallment
                                                                .id,
                                                      );
                                                  if (index != -1) {
                                                    final prev =
                                                        state
                                                            .installments[index];
                                                    // Preserve installment number if backend didn't return it,
                                                    // while keeping the concrete type (InstallmentModel when applicable)
                                                    final merged = () {
                                                      if (updatedInstallment
                                                              .installmentNumber !=
                                                          null) {
                                                        return updatedInstallment;
                                                      }
                                                      if (updatedInstallment
                                                          is InstallmentModel) {
                                                        final u =
                                                            updatedInstallment;
                                                        return InstallmentModel(
                                                          id: u.id,
                                                          userId: u.userId,
                                                          clientId: u.clientId,
                                                          investorId:
                                                              u.investorId,
                                                          walletId: u.walletId,
                                                          productName:
                                                              u.productName,
                                                          cashPrice:
                                                              u.cashPrice,
                                                          installmentPrice:
                                                              u.installmentPrice,
                                                          termMonths:
                                                              u.termMonths,
                                                          downPayment:
                                                              u.downPayment,
                                                          monthlyPayment:
                                                              u.monthlyPayment,
                                                          downPaymentDate:
                                                              u.downPaymentDate,
                                                          installmentStartDate:
                                                              u.installmentStartDate,
                                                          installmentEndDate:
                                                              u.installmentEndDate,
                                                          installmentNumber:
                                                              prev.installmentNumber,
                                                          createdAt:
                                                              u.createdAt,
                                                          updatedAt:
                                                              u.updatedAt,
                                                          // optimized fields
                                                          clientName:
                                                              u.clientName,
                                                          walletName:
                                                              u.walletName,
                                                          paidAmount:
                                                              u.paidAmount,
                                                          remainingAmount:
                                                              u.remainingAmount,
                                                          nextPaymentDate:
                                                              u.nextPaymentDate,
                                                          nextPaymentAmount:
                                                              u.nextPaymentAmount,
                                                          paymentStatus:
                                                              u.paymentStatus,
                                                          overdueCount:
                                                              u.overdueCount,
                                                          totalPayments:
                                                              u.totalPayments,
                                                          paidPayments:
                                                              u.paidPayments,
                                                          lastPaymentDate:
                                                              u.lastPaymentDate,
                                                        );
                                                      }
                                                      return updatedInstallment
                                                          .copyWith(
                                                            installmentNumber:
                                                                prev.installmentNumber,
                                                          );
                                                    }();

                                                    // Update the installment with preserved fields when necessary
                                                    state.installments[index] =
                                                        merged;

                                                    // Set expansion state to collapsed since the widget will rebuild and collapse
                                                    state.expandedStates[merged
                                                            .id] =
                                                        false;

                                                    // Clear the payments since the installment collapsed
                                                    state.installmentPayments[merged
                                                            .id] =
                                                        [];
                                                  }
                                                });
                                              },
                                              onSubmitPaymentInBackground:
                                                  state
                                                      .submitPaymentInBackground,
                                              onDelete:
                                                  () => state.deleteInstallment(
                                                    installment,
                                                  ),
                                              onEdit:
                                                  () => state.editInstallment(
                                                    installment,
                                                  ),
                                              onSelect:
                                                  () => state.toggleSelection(
                                                    installment.id,
                                                  ),
                                              isSelected: state
                                                  .selectedInstallmentIds
                                                  .contains(installment.id),
                                              onSelectionToggle:
                                                  () => state.toggleSelection(
                                                    installment.id,
                                                  ),
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
}

class _InstallmentsFilterSheet extends StatefulWidget {
  final InstallmentsListScreenState state;

  const _InstallmentsFilterSheet({required this.state});

  @override
  State<_InstallmentsFilterSheet> createState() => _InstallmentsFilterSheetState();
}

class _InstallmentsFilterSheetState extends State<_InstallmentsFilterSheet> {
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
    
    print('🔄 Desktop: Starting wallet loading...');
    setState(() => _isLoadingWallets = true);
    
    try {
      final authService = AuthServiceProvider.of(context);
      final currentUser = await authService.getCurrentUser();
      
      if (currentUser == null) {
        print('❌ Desktop: No current user found');
        throw Exception('User not authenticated');
      }
      
      print('👤 Desktop: Loading wallets for user: ${currentUser.id}');
      final walletRepository = WalletRepositoryImpl(WalletRemoteDataSourceImpl());
      
      // Load wallets and balances
      final wallets = await walletRepository.getAllWallets(currentUser.id);
      print('📦 Desktop: Loaded ${wallets.length} wallets');
      
      if (!mounted) return;
      
      final balances = await walletRepository.getAllWalletBalances(currentUser.id);
      print('💰 Desktop: Loaded ${balances.length} wallet balances');
      
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
      
      print('✅ Desktop: Wallet loading completed successfully');
    } catch (e) {
      print('❌ Desktop: Error loading wallets: $e');
      if (mounted) {
        setState(() => _isLoadingWallets = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);

    return Material(
      color: AppTheme.surfaceColor,
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header
              Row(
                children: [
                  Expanded(
                    child: Text(
                      l10n?.filters ?? 'Фильтры',
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.w600,
                          ),
                    ),
                  ),
                  IconButton(
                    onPressed: () => Navigator.of(context).pop(),
                    icon: const Icon(Icons.close),
                  ),
                ],
              ),
              const SizedBox(height: 24),
              
              // Wallet Filter (moved to top)
              Text(
                l10n?.wallet ?? 'Кошелек',
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: AppTheme.textPrimary,
                ),
              ),
              const SizedBox(height: 8),
              _isLoadingWallets
                  ? Container(
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
                    )
                  : CustomDropdown<String>(
                      value: _wallet,
                      items: _getWalletFilterOptions(),
                      onChanged: (value) {
                        setState(() {
                          _wallet = value ?? 'all';
                          if (_wallet == 'all') {
                            _selectedWallet = null;
                          } else if (_wallet == 'noWallet') {
                            _selectedWallet = null;
                          } else {
                            _selectedWallet = _wallets.cast<Wallet?>().firstWhere(
                              (w) => w?.id == _wallet,
                              orElse: () => null,
                            );
                          }
                        });
                      },
                      hint: 'Все',
                      width: double.infinity,
                    ),
              const SizedBox(height: 16),

              // Status Filter
              Text(
                l10n?.status ?? 'Статус',
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: AppTheme.textPrimary,
                ),
              ),
              const SizedBox(height: 8),
              CustomDropdown<String>(
                value: _status,
                items: _getStatusFilterOptions(),
                onChanged: (value) => setState(() => _status = value ?? 'all'),
                hint: 'Все',
                width: double.infinity,
              ),
              const SizedBox(height: 16),

              // Created Date Filter
              Text(
                'Дата создания',
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: AppTheme.textPrimary,
                ),
              ),
              const SizedBox(height: 8),
              CustomDropdown<String>(
                value: _createdDateFilter,
                items: _getDateFilterOptions(),
                onChanged: (value) => setState(() => _createdDateFilter = value ?? 'all'),
                hint: 'Все',
                width: double.infinity,
              ),
              const SizedBox(height: 16),

              // Sort By
              Text(
                'Сортировать по',
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: AppTheme.textPrimary,
                ),
              ),
              const SizedBox(height: 8),
              CustomDropdown<String>(
                value: _sortBy,
                items: _getSortOptions(),
                onChanged: (value) => setState(() => _sortBy = value ?? _sortBy),
                hint: 'Статус',
                width: double.infinity,
              ),
              const SizedBox(height: 12),
              
              // Sort Direction
              SegmentedButton<bool>(
                segments: [
                  ButtonSegment<bool>(
                    value: true,
                    icon: const Icon(Icons.arrow_upward),
                    label: Text(l10n?.ascending ?? 'По возрастанию'),
                  ),
                  ButtonSegment<bool>(
                    value: false,
                    icon: const Icon(Icons.arrow_downward),
                    label: Text(l10n?.descending ?? 'По убыванию'),
                  ),
                ],
                selected: {_ascending},
                onSelectionChanged: (value) =>
                    setState(() => _ascending = value.first),
              ),
              
              const Spacer(),
              
              // Action Buttons
              Row(
                children: [
                  OutlinedButton(
                    onPressed: () {
                      state.resetFilters();
                      Navigator.of(context).pop();
                    },
                    child: Text(l10n?.resetFilters ?? 'Сбросить фильтры'),
                  ),
                  const Spacer(),
                  FilledButton(
                    onPressed: _apply,
                    child: Text(l10n?.apply ?? 'Применить'),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
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

  void _apply() {
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
    Navigator.of(context).pop();
  }
}

class _FilterButton extends StatelessWidget {
  final VoidCallback onPressed;
  final bool hasActiveFilters;
  final String text;

  const _FilterButton({
    required this.onPressed,
    required this.hasActiveFilters,
    required this.text,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 40,
      decoration: BoxDecoration(
        color: hasActiveFilters 
            ? AppTheme.primaryColor.withOpacity(0.1)
            : AppTheme.subtleBackgroundColor,
        border: Border.all(
          color: hasActiveFilters 
              ? AppTheme.primaryColor.withOpacity(0.3)
              : AppTheme.subtleBorderColor,
          width: 1,
        ),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onPressed,
          borderRadius: BorderRadius.circular(8),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.tune_rounded,
                  size: 18,
                  color: hasActiveFilters
                      ? AppTheme.primaryColor
                      : AppTheme.textSecondary,
                ),
                const SizedBox(width: 8),
                Text(
                  text,
                  style: TextStyle(
                    color: hasActiveFilters
                        ? AppTheme.primaryColor
                        : AppTheme.textSecondary,
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                    fontFamily: 'Inter',
                  ),
                ),
                if (hasActiveFilters) ...[
                  const SizedBox(width: 6),
                  Container(
                    width: 6,
                    height: 6,
                    decoration: BoxDecoration(
                      color: AppTheme.primaryColor,
                      shape: BoxShape.circle,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}
