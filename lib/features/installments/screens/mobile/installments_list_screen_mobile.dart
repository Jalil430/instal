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
        title: state.isSelectionMode
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
                    onChanged: (value) => state.setStateWrapper(() => state.searchQuery = value),
                    hintText: '${l10n?.search ?? 'Поиск'} ${state.getItemsText(0)}...',
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
          else
            Padding(
              padding: const EdgeInsets.only(right: 8),
              child: PopupMenuButton<String>(
                icon: const Icon(Icons.filter_list),
                tooltip: l10n?.filterByStatus ?? 'Filter by status',
                onSelected: (value) {
                  state.setStatusFilter(value);
                },
                itemBuilder: (context) {
                  final translatedFilters = state.getTranslatedStatusFilters();
                  return translatedFilters.entries.map((entry) {
                    final isSelected = state.statusFilter == entry.key;
                    return PopupMenuItem<String>(
                      value: entry.key,
                      child: Row(
                        children: [
                          if (isSelected)
                            const Icon(
                              Icons.check,
                              color: AppTheme.primaryColor,
                              size: 18,
                            ),
                          if (isSelected) const SizedBox(width: 8),
                          Text(
                            entry.value,
                            style: TextStyle(
                              fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                              color: isSelected ? AppTheme.primaryColor : null,
                            ),
                          ),
                        ],
                      ),
                    );
                  }).toList();
                },
              ),
            ),
        ],
        bottom: state.isSelectionMode
            ? PreferredSize(
                preferredSize: const Size.fromHeight(48),
                child: Container(
                  color: AppTheme.subtleBackgroundColor,
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
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
      body: state.isLoading
          ? const Center(
              child: CircularProgressIndicator(),
            )
          : state.filteredAndSortedInstallments.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.search_off,
                        size: 64,
                        color: Colors.grey[400],
                      ),
                      const SizedBox(height: 16),
                      Text(
                        l10n?.notFound ?? 'Ничего не найдено',
                        style: TextStyle(
                          fontSize: 16,
                          color: Colors.grey[600],
                        ),
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
                    itemCount: state.filteredAndSortedInstallments.length,
                    itemBuilder: (context, index) {
                      final installment = state.filteredAndSortedInstallments[index];
                      
                      // Use pre-calculated values from optimized response
                      final clientName = installment is InstallmentModel
                          ? (installment.clientName ?? l10n?.unknown ?? 'Unknown')
                          : (l10n?.unknown ?? 'Unknown');
                      final paidAmount = installment is InstallmentModel
                          ? (installment.paidAmount ?? 0.0)
                          : 0.0;
                      final leftAmount = installment is InstallmentModel
                          ? (installment.remainingAmount ?? installment.installmentPrice)
                          : installment.installmentPrice;
                      
                      // Get payment status using dynamic calculation
                      final status = installment is InstallmentModel
                          ? installment.dynamicStatus
                          : 'предстоящий';
                      
                      // Create next payment from optimized data
                      InstallmentPayment? nextPayment;
                      if (installment is InstallmentModel && installment.nextPaymentDate != null) {
                        nextPayment = InstallmentPayment(
                          id: '${installment.id}_next',
                          installmentId: installment.id,
                          paymentNumber: 1,
                          dueDate: installment.nextPaymentDate!,
                          expectedAmount: installment.nextPaymentAmount ?? 0.0,
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
      floatingActionButton: state.isSelectionMode
          ? null
          : FloatingActionButton(
              onPressed: state.showCreateInstallmentDialog,
              backgroundColor: AppTheme.primaryColor,
              child: const Icon(Icons.add, color: Colors.white),
            ),
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
    if (nextPayment != null && (status == 'просрочено' || status == 'предстоящий')) {
      final now = DateTime.now();
      final today = DateTime(now.year, now.month, now.day);
      final dueDate = nextPayment.dueDate;
      final due = DateTime(dueDate.year, dueDate.month, dueDate.day);
      final daysDifference = due.difference(today).inDays;
      
      if (status == 'просрочено' && daysDifference < 0) {
        daysText = l10n?.daysShort(daysDifference) ?? '${daysDifference.abs()}d';
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
    final nextPaymentDate = nextPayment?.dueDate != null
        ? dateFormat.format(nextPayment!.dueDate)
        : '-';
    
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      elevation: 1,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(
          color: state.selectedInstallmentIds.contains(installment.id)
              ? AppTheme.primaryColor
              : Colors.transparent,
          width: 2,
        ),
      ),
      child: InkWell(
        onTap: () => state.isSelectionMode
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
                        padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 4), // Slightly bigger padding
                        decoration: BoxDecoration(
                          color: statusColor.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(10), // Same as desktop
                          border: Border.all(
                            color: statusColor.withOpacity(0.2), // Same as desktop
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
                            color: leftAmount > 0 ? Colors.orange[700] : AppTheme.successColor,
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
                            style: const TextStyle(
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                      const Spacer(),
                      // Register payment icon
                      IconButton(
                        icon: const Icon(Icons.payment_outlined),
                        onPressed: () => nextPayment != null 
                            ? _registerPayment(context, nextPayment)
                            : null,
                        tooltip: l10n?.registerPayment ?? 'Register Payment',
                        iconSize: 20,
                        color: nextPayment != null ? AppTheme.primaryColor : Colors.grey.withOpacity(0.5),
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(),
                      ),
                      const SizedBox(width: 8),
                      // WhatsApp reminder icon
                      IconButton(
                        icon: const Icon(Icons.chat_bubble_outline),
                        onPressed: () => _sendSingleReminder(context, installment.id),
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
      itemBuilder: (context) => [
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
      builder: (context) => AlertDialog(
        title: Text(l10n?.sendWhatsAppReminder ?? 'Send Reminder'),
        content: Text(l10n?.sendReminderConfirmation ?? 'Are you sure you want to send a reminder?'),
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
        // This will refresh the data
        state.forceRefresh();
      },
    );
  }
} 