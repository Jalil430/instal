import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/localization/app_localizations.dart';
import '../domain/entities/installment.dart';
import '../domain/entities/installment_payment.dart';
import 'installment_payment_item.dart';

class InstallmentListItem extends StatefulWidget {
  final Installment installment;
  final String clientName;
  final String productName;
  final double paidAmount;
  final double leftAmount;
  final List<InstallmentPayment> payments;
  final InstallmentPayment? nextPayment;
  final VoidCallback onTap;
  final Function(InstallmentPayment) onRegisterPayment;

  const InstallmentListItem({
    super.key,
    required this.installment,
    required this.clientName,
    required this.productName,
    required this.paidAmount,
    required this.leftAmount,
    required this.payments,
    this.nextPayment,
    required this.onTap,
    required this.onRegisterPayment,
  });

  @override
  State<InstallmentListItem> createState() => _InstallmentListItemState();
}

class _InstallmentListItemState extends State<InstallmentListItem> {
  bool _isHovered = false;
  bool _isExpanded = false;

  String _getOverallStatus() {
    // Determine overall status based on payments
    bool hasOverdue = false;
    bool hasDueToPay = false;
    bool hasUpcoming = false;
    
    for (final payment in widget.payments) {
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

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final currencyFormat = NumberFormat.currency(
      locale: 'ru_RU',
      symbol: '₽',
      decimalDigits: 0,
    );
    final dateFormat = DateFormat('dd.MM.yyyy');

    // Get next payment due date
    final nextDueDate = widget.nextPayment?.dueDate ?? widget.installment.installmentEndDate;

    return Column(
      children: [
        MouseRegion(
          onEnter: (_) => setState(() => _isHovered = true),
          onExit: (_) => setState(() => _isHovered = false),
          child: GestureDetector(
            onTap: widget.onTap,
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 150),
              margin: const EdgeInsets.symmetric(horizontal: 24, vertical: 1),
              decoration: BoxDecoration(
                color: _isHovered ? AppTheme.backgroundColor : AppTheme.surfaceColor,
                border: Border(
                  bottom: BorderSide(
                    color: _isExpanded ? Colors.transparent : AppTheme.borderColor,
                    width: 1,
                  ),
                ),
              ),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 0, vertical: 16),
                child: Row(
                  children: [
                    // Client Name
                    Expanded(
                      flex: 2,
                      child: Text(
                        widget.clientName,
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                              fontWeight: FontWeight.w500,
                            ),
                      ),
                    ),
                    // Product Name
                    Expanded(
                      flex: 2,
                      child: Text(
                        widget.productName,
                        style: Theme.of(context).textTheme.bodyMedium,
                      ),
                    ),
                    // Paid Amount
                    Expanded(
                      child: Text(
                        currencyFormat.format(widget.paidAmount),
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                              color: AppTheme.successColor,
                              fontWeight: FontWeight.w500,
                            ),
                      ),
                    ),
                    // Left Amount
                    Expanded(
                      child: Text(
                        currencyFormat.format(widget.leftAmount),
                        style: Theme.of(context).textTheme.bodyMedium,
                      ),
                    ),
                    // Due Date
                    Expanded(
                      child: Text(
                        dateFormat.format(nextDueDate),
                        style: Theme.of(context).textTheme.bodyMedium,
                      ),
                    ),
                    // Status
                    Expanded(
                      child: _buildStatusBadge(context, _getOverallStatus()),
                    ),
                    // Next Payment Section
                    Container(
                      width: 200,
                      padding: const EdgeInsets.only(left: 16),
                      child: Row(
                        children: [
                          if (widget.nextPayment != null) ...[
                            Expanded(
                              child: OutlinedButton(
                                onPressed: () => widget.onRegisterPayment(widget.nextPayment!),
                                style: OutlinedButton.styleFrom(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 12,
                                    vertical: 8,
                                  ),
                                  textStyle: Theme.of(context).textTheme.bodySmall,
                                ),
                                child: Text(
                                  widget.nextPayment!.paymentNumber == 0
                                      ? l10n?.downPayment ?? 'Первоначальный взнос'
                                      : '${l10n?.month ?? 'Месяц'} ${widget.nextPayment!.paymentNumber}',
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                          ],
                          IconButton(
                            icon: Icon(
                              _isExpanded
                                  ? Icons.arrow_drop_up
                                  : Icons.arrow_drop_down,
                              color: AppTheme.textSecondary,
                            ),
                            onPressed: () {
                              setState(() => _isExpanded = !_isExpanded);
                            },
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
        // Expandable payment list
        AnimatedCrossFade(
          firstChild: const SizedBox.shrink(),
          secondChild: Container(
            margin: const EdgeInsets.symmetric(horizontal: 24),
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
              children: widget.payments.map((payment) {
                return InstallmentPaymentItem(
                  payment: payment,
                  onRegisterPayment: () => widget.onRegisterPayment(payment),
                );
              }).toList(),
            ),
          ),
          crossFadeState: _isExpanded
              ? CrossFadeState.showSecond
              : CrossFadeState.showFirst,
          duration: const Duration(milliseconds: 200),
        ),
      ],
    );
  }

  Widget _buildStatusBadge(BuildContext context, String status) {
    final l10n = AppLocalizations.of(context);
    
    String label;
    Color color;
    Color backgroundColor;

    switch (status) {
      case 'оплачено':
        label = l10n?.paid ?? 'Оплачено';
        color = AppTheme.successColor;
        backgroundColor = AppTheme.successColor.withOpacity(0.1);
        break;
      case 'предстоящий':
        label = l10n?.upcoming ?? 'Предстоящий';
        color = AppTheme.pendingColor;
        backgroundColor = AppTheme.pendingColor.withOpacity(0.1);
        break;
      case 'к оплате':
        label = l10n?.dueToPay ?? 'К оплате';
        color = AppTheme.warningColor;
        backgroundColor = AppTheme.warningColor.withOpacity(0.1);
        break;
      case 'просрочено':
        label = l10n?.overdue ?? 'Просрочено';
        color = AppTheme.errorColor;
        backgroundColor = AppTheme.errorColor.withOpacity(0.1);
        break;
      default:
        label = status;
        color = AppTheme.textSecondary;
        backgroundColor = AppTheme.textSecondary.withOpacity(0.1);
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        label,
        style: Theme.of(context).textTheme.labelSmall?.copyWith(
              color: color,
              fontWeight: FontWeight.w600,
            ),
      ),
    );
  }
} 