import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:instal_app/core/localization/app_localizations.dart';
import 'package:instal_app/core/theme/app_theme.dart';
import 'package:instal_app/features/installments/domain/entities/installment.dart';
import 'package:instal_app/features/installments/domain/entities/installment_payment.dart';
import 'package:instal_app/features/installments/data/models/installment_model.dart';
import 'package:instal_app/features/installments/screens/installments_list_screen.dart';
import 'package:instal_app/features/installments/widgets/installment_list_item.dart';
import 'package:instal_app/shared/widgets/create_installment_dialog.dart';
import 'package:instal_app/shared/widgets/custom_button.dart';
import 'package:instal_app/shared/widgets/custom_dropdown.dart';
import 'package:instal_app/shared/widgets/custom_search_bar.dart';

class InstallmentsListScreenDesktop extends StatelessWidget {
  final InstallmentsListScreenState state;

  const InstallmentsListScreenDesktop({super.key, required this.state});

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
                            color: state.isSelectionMode
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
                        onPressed: state.selectedInstallmentIds.isNotEmpty
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
                      // Enhanced Search field
                      CustomSearchBar(
                        value: state.searchQuery,
                        onChanged: (value) =>
                            state.setStateWrapper(() => state.searchQuery = value),
                        hintText:
                            '${l10n?.search ?? 'Поиск'} ${state.getItemsText(0)}...',
                        width: 320,
                      ),
                      const SizedBox(width: 16),
                      // Filter by status dropdown
                      CustomDropdown(
                        value: state.statusFilter,
                        width: 200,
                        items: state.getTranslatedStatusFilters(),
                        onChanged: (value) => state.setStatusFilter(value!),
                        hint: null,
                      ),
                      const SizedBox(width: 16),
                      // Custom Add button
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
              child: state.isLoading
                  ? Center(
                      child: Container(
                        padding: const EdgeInsets.all(20),
                        child: CircularProgressIndicator(
                          strokeWidth: 3,
                          valueColor: AlwaysStoppedAnimation<Color>(
                              AppTheme.brightPrimaryColor),
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
                                horizontal: 32, vertical: 16),
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
                                      (l10n?.client ?? 'Клиент')
                                          .toUpperCase(),
                                      style: Theme.of(context)
                                          .textTheme
                                          .labelMedium
                                          ?.copyWith(
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
                                      (l10n?.productNameHeader ??
                                              'Название товара')
                                          .toUpperCase(),
                                      style: Theme.of(context)
                                          .textTheme
                                          .labelMedium
                                          ?.copyWith(
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
                                      (l10n?.paidAmount ?? 'Оплачено')
                                          .toUpperCase(),
                                      style: Theme.of(context)
                                          .textTheme
                                          .labelMedium
                                          ?.copyWith(
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
                                      (l10n?.leftAmount ?? 'Осталось')
                                          .toUpperCase(),
                                      style: Theme.of(context)
                                          .textTheme
                                          .labelMedium
                                          ?.copyWith(
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
                                      (l10n?.dueDate ?? 'Срок оплаты')
                                          .toUpperCase(),
                                      style: Theme.of(context)
                                          .textTheme
                                          .labelMedium
                                          ?.copyWith(
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
                                      (l10n?.statusHeader ?? 'Статус')
                                          .toUpperCase(),
                                      style: Theme.of(context)
                                          .textTheme
                                          .labelMedium
                                          ?.copyWith(
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
                                    l10n?.nextPaymentHeader ??
                                        'СЛЕДУЮЩИЙ ПЛАТЕЖ',
                                    style: Theme.of(context)
                                        .textTheme
                                        .labelMedium
                                        ?.copyWith(
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
                            child: state.filteredAndSortedInstallments.isEmpty
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
                                    itemCount: state
                                        .filteredAndSortedInstallments.length,
                                    itemBuilder: (context, index) {
                                      final installment = state
                                          .filteredAndSortedInstallments[index];
                                      final payments = state.installmentPayments[
                                              installment.id] ??
                                          [];

                                      // Use pre-calculated values from optimized response
                                      final clientName = installment
                                              is InstallmentModel
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

                                      // Create next payment from optimized data
                                      InstallmentPayment? nextPayment;
                                      if (installment is InstallmentModel &&
                                          installment.nextPaymentDate != null) {
                                        // Determine payment number: 0 for down payment, 1+ for monthly payments
                                        int paymentNumber;
                                        if (installment.downPayment > 0 &&
                                            installment.nextPaymentDate ==
                                                installment.downPaymentDate) {
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
                                          paymentNumber = monthlyPaymentsPaid +
                                              1; // Next monthly payment number
                                        }

                                        nextPayment = InstallmentPayment(
                                          id: '${installment.id}_next',
                                          installmentId: installment.id,
                                          paymentNumber: paymentNumber,
                                          dueDate:
                                              installment.nextPaymentDate!,
                                          expectedAmount:
                                              installment.nextPaymentAmount ??
                                                  0.0,
                                          isPaid: false,
                                          paidDate: null,
                                          createdAt: DateTime.now(),
                                          updatedAt: DateTime.now(),
                                        );
                                      }
                                      return AnimatedContainer(
                                        duration: Duration(
                                            milliseconds: 100 + (index * 50)),
                                        curve: Curves.easeOutCubic,
                                        child: InstallmentListItem(
                                          installment: installment,
                                          clientName: clientName,
                                          productName: installment.productName,
                                          paidAmount: paidAmount,
                                          leftAmount: leftAmount,
                                          payments: payments,
                                          nextPayment: nextPayment,
                                          isExpanded:
                                              state.expandedStates[installment.id] ??
                                                  false,
                                          isLoadingPayments: state
                                              .loadingPayments
                                              .contains(installment.id),
                                          onTap: state.isSelectionMode
                                              ? () => state
                                                  .toggleSelection(installment.id)
                                              : () => context.go(
                                                  '/installments/${installment.id}'),
                                          onClientTap: () => context
                                              .go('/clients/${installment.clientId}'),
                                          onExpansionChanged: (expanded) {
                                            state.setStateWrapper(() {
                                              state.expandedStates[
                                                  installment.id] = expanded;
                                            });

                                            // Load payments only when expanding and if not already loaded
                                            if (expanded &&
                                                (state.installmentPayments[
                                                            installment.id]
                                                        ?.isEmpty ??
                                                    true)) {
                                              state.loadPaymentsForInstallment(
                                                  installment.id);
                                            }
                                          },
                                          onDataChanged: () => state.loadData(),
                                          onInstallmentUpdated:
                                              (updatedInstallment) {
                                            state.setStateWrapper(() {
                                              // Find and update the specific installment in the list
                                              final index = state.installments
                                                  .indexWhere((i) =>
                                                      i.id ==
                                                      updatedInstallment.id);
                                              if (index != -1) {
                                                // Update the installment
                                                state.installments[index] =
                                                    updatedInstallment;

                                                // Set expansion state to collapsed since the widget will rebuild and collapse
                                                state.expandedStates[
                                                    updatedInstallment
                                                        .id] = false;

                                                // Clear the payments since the installment collapsed
                                                state.installmentPayments[
                                                    updatedInstallment
                                                        .id] = [];
                                              }
                                            });
                                          },
                                          onDelete: () =>
                                              state.deleteInstallment(installment),
                                          onSelect: () =>
                                              state.toggleSelection(installment.id),
                                          isSelected: state
                                              .selectedInstallmentIds
                                              .contains(installment.id),
                                          onSelectionToggle: () =>
                                              state.toggleSelection(installment.id),
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