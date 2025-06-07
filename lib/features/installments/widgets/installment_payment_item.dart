import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/localization/app_localizations.dart';
import '../../../shared/widgets/custom_status_badge.dart';
import '../domain/entities/installment_payment.dart';
import 'payment_registration_dialog.dart';
import 'payment_deletion_dialog.dart';

class InstallmentPaymentItem extends StatefulWidget {
  final InstallmentPayment payment;
  final VoidCallback onPaymentUpdated;

  const InstallmentPaymentItem({
    super.key,
    required this.payment,
    required this.onPaymentUpdated,
  });

  @override
  State<InstallmentPaymentItem> createState() => _InstallmentPaymentItemState();
}

class _InstallmentPaymentItemState extends State<InstallmentPaymentItem> with SingleTickerProviderStateMixin {
  bool _isHovered = false;
  late AnimationController _hoverController;
  late Animation<double> _hoverAnimation;

  @override
  void initState() {
    super.initState();
    _hoverController = AnimationController(
      duration: const Duration(milliseconds: 150),
      vsync: this,
    );
    _hoverAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _hoverController, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _hoverController.dispose();
    super.dispose();
  }

  void _handlePaymentRegistration(Offset position) {
    PaymentRegistrationDialog.show(
      context: context,
      position: position,
      payment: widget.payment,
      onPaymentRegistered: widget.onPaymentUpdated,
    );
  }

  void _handlePaymentDeletion(Offset position) {
    PaymentDeletionDialog.show(
      context: context,
      position: position,
      payment: widget.payment,
      onPaymentDeleted: widget.onPaymentUpdated,
    );
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

    return MouseRegion(
      onEnter: (_) {
        setState(() => _isHovered = true);
        _hoverController.forward();
      },
      onExit: (_) {
        setState(() => _isHovered = false);
        _hoverController.reverse();
      },
      child: GestureDetector(
        onTapDown: (details) {
          if (widget.payment.isPaid) {
            _handlePaymentDeletion(details.globalPosition);
          } else {
            _handlePaymentRegistration(details.globalPosition);
          }
        },
        child: AnimatedBuilder(
          animation: _hoverAnimation,
          builder: (context, child) {
            return Container(
              decoration: BoxDecoration(
                color: Color.lerp(
                  const Color(0xFFF8F9FA),
                  const Color(0xFFF1F3F4),
                  _hoverAnimation.value,
                ),
                border: Border(
                  bottom: BorderSide(
                    color: AppTheme.borderColor.withOpacity(0.3),
                    width: 1,
                  ),
                ),
                boxShadow: _isHovered ? [
                  BoxShadow(
                    color: AppTheme.primaryColor.withOpacity(0.08),
                    offset: const Offset(0, 2),
                    blurRadius: 8,
                    spreadRadius: 0,
                  ),
                ] : null,
              ),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 12),
                child: Row(
                  children: [
                    // Payment name - matches first column (client name)
                    Expanded(
                      flex: 2,
                      child: Padding(
                        padding: const EdgeInsets.only(right: 16),
                        child: Text(
                          widget.payment.paymentNumber == 0
                              ? l10n?.downPayment ?? 'Первоначальный взнос'
                              : '${l10n?.month ?? 'Месяц'} ${widget.payment.paymentNumber}',
                          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                fontWeight: FontWeight.w500,
                                fontSize: 14,
                              ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ),
                    
                    // Dates - matches second column (product name)
                    Expanded(
                      flex: 2,
                      child: Padding(
                        padding: const EdgeInsets.only(right: 16),
                        child: Row(
                          children: [
                            // Due date
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  dateFormat.format(widget.payment.dueDate),
                                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                        color: AppTheme.textPrimary,
                                        fontSize: 14,
                                        fontWeight: FontWeight.w400,
                                      ),
                                ),
                                Text(
                                  'Срок оплаты',
                                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                        color: AppTheme.textSecondary,
                                        fontSize: 10,
                                      ),
                                ),
                              ],
                            ),
                            
                            // Show paid date if available
                            if (widget.payment.isPaid && widget.payment.paidDate != null) ...[
                              Container(
                                margin: const EdgeInsets.symmetric(horizontal: 12),
                                width: 1,
                                height: 30,
                                color: AppTheme.borderColor.withOpacity(0.3),
                              ),
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    dateFormat.format(widget.payment.paidDate!),
                                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                          color: AppTheme.successColor,
                                          fontSize: 14,
                                          fontWeight: FontWeight.w400,
                                        ),
                                  ),
                                  Text(
                                    'Оплачено',
                                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                          color: AppTheme.successColor.withOpacity(0.7),
                                          fontSize: 10,
                                        ),
                                  ),
                                ],
                              ),
                            ],
                          ],
                        ),
                      ),
                    ),
                    
                    // Empty space - matches paid amount column
                    Expanded(
                      child: Padding(
                        padding: const EdgeInsets.only(right: 16),
                        child: Container(),
                      ),
                    ),
                    
                    // Empty space - matches left amount column
                    Expanded(
                      child: Padding(
                        padding: const EdgeInsets.only(right: 16),
                        child: Container(),
                      ),
                    ),
                    
                    // Empty space - matches due date column
                    Expanded(
                      child: Padding(
                        padding: const EdgeInsets.only(right: 16),
                        child: Container(),
                      ),
                    ),
                    
                    // Status badge - matches status column with fixed width
                    Expanded(
                      child: Padding(
                        padding: const EdgeInsets.only(right: 16),
                        child: Container(
                          width: 150, // Fixed width for consistency
                          alignment: Alignment.centerLeft,
                          child: CustomStatusBadge(
                            status: widget.payment.status,
                            width: 110,
                          ),
                        ),
                      ),
                    ),
                    
                    // Amount and action - matches next payment column
                    Container(
                      width: 160,
                      padding: const EdgeInsets.only(left: 8),
                      child: Row(
                        children: [
                          // Payment Amount
                          Text(
                            currencyFormat.format(widget.payment.expectedAmount),
                            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                  fontWeight: FontWeight.w400,
                                  fontSize: 14,
                                  color: AppTheme.textPrimary,
                                ),
                          ),
                          
                          const Spacer(),
                          
                          // Action indicator
                          Container(
                            width: 28,
                            height: 28,
                            decoration: BoxDecoration(
                              color: widget.payment.isPaid
                                  ? (_isHovered 
                                      ? AppTheme.errorColor.withOpacity(0.1)
                                      : AppTheme.backgroundColor)
                                  : _isHovered 
                                      ? AppTheme.primaryColor.withOpacity(0.1)
                                      : AppTheme.backgroundColor,
                              borderRadius: BorderRadius.circular(6),
                              border: Border.all(
                                color: AppTheme.borderColor.withOpacity(0.5),
                                width: 1,
                              ),
                            ),
                            child: Icon(
                              widget.payment.isPaid
                                  ? Icons.close_rounded
                                  : Icons.add_rounded,
                              size: 14,
                              color: widget.payment.isPaid
                                  ? (_isHovered 
                                      ? AppTheme.errorColor
                                      : AppTheme.textSecondary)
                                  : _isHovered 
                                      ? AppTheme.primaryColor
                                      : AppTheme.textSecondary,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        ),
      ),
    );
  }
} 