import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/localization/app_localizations.dart';
import '../../../shared/widgets/custom_status_badge.dart';
import '../../../shared/widgets/custom_icon_button.dart';
import '../domain/entities/installment.dart';
import '../domain/entities/installment_payment.dart';
import 'payment_registration_dialog.dart';
import 'payment_deletion_dialog.dart';

class InstallmentPaymentItem extends StatefulWidget {
  final InstallmentPayment payment;
  final Function(Installment) onPaymentUpdated;
  final bool isExpanded;

  const InstallmentPaymentItem({
    super.key,
    required this.payment,
    required this.onPaymentUpdated,
    this.isExpanded = false,
  });

  @override
  State<InstallmentPaymentItem> createState() => _InstallmentPaymentItemState();
}

class _InstallmentPaymentItemState extends State<InstallmentPaymentItem> with SingleTickerProviderStateMixin {
  bool _isHovered = false;
  late AnimationController _hoverController;
  late Animation<double> _hoverAnimation;
  final GlobalKey _actionButtonKey = GlobalKey();

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
    // Get the button's position in the screen coordinate system
    if (_actionButtonKey.currentContext != null) {
      final RenderBox renderBox = _actionButtonKey.currentContext!.findRenderObject() as RenderBox;
      final Size size = renderBox.size;
      final Offset buttonPosition = renderBox.localToGlobal(Offset.zero);
      
      // Center of the button
      final Offset centerPosition = Offset(
        buttonPosition.dx + size.width / 2,
        buttonPosition.dy + size.height / 2,
      );
      
      PaymentRegistrationDialog.show(
        context: context,
        position: position.dx > 0 && position.dy > 0 ? position : centerPosition,
        payment: widget.payment,
        onPaymentRegistered: widget.onPaymentUpdated,
      );
    } else {
      // Fallback to whatever position is given
      PaymentRegistrationDialog.show(
        context: context,
        position: position,
        payment: widget.payment,
        onPaymentRegistered: widget.onPaymentUpdated,
      );
    }
  }

  void _handlePaymentDeletion(Offset position) {
    // Get the button's position in the screen coordinate system
    if (_actionButtonKey.currentContext != null) {
      final RenderBox renderBox = _actionButtonKey.currentContext!.findRenderObject() as RenderBox;
      final Size size = renderBox.size;
      final Offset buttonPosition = renderBox.localToGlobal(Offset.zero);
      
      // Center of the button
      final Offset centerPosition = Offset(
        buttonPosition.dx + size.width / 2,
        buttonPosition.dy + size.height / 2,
      );
      
      PaymentDeletionDialog.show(
        context: context,
        position: position.dx > 0 && position.dy > 0 ? position : centerPosition,
        payment: widget.payment,
        onPaymentDeleted: widget.onPaymentUpdated,
      );
    } else {
      // Fallback to whatever position is given
      PaymentDeletionDialog.show(
        context: context,
        position: position,
        payment: widget.payment,
        onPaymentDeleted: widget.onPaymentUpdated,
      );
    }
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
    
    // Conditional colors based on the context (expanded in list vs. in details screen)
    final Color baseColor;
    final Color hoverColor;

    if (widget.isExpanded) {
      // Colors for when it's part of an expanded list item
      baseColor = const Color(0xFFF8F9FA);
      hoverColor = const Color(0xFFF1F3F4);
    } else {
      // Colors to match the non-expanded InstallmentListItem
      baseColor = AppTheme.surfaceColor;
      hoverColor = AppTheme.backgroundColor;
    }

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
                  baseColor,
                  hoverColor,
                  _hoverAnimation.value,
                ),
                border: Border(
                  bottom: BorderSide(
                    color: AppTheme.borderColor.withOpacity(0.3),
                    width: 1,
                  ),
                ),
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
                                  l10n?.dueDate ?? 'Срок оплаты',
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
                                    l10n?.paid ?? 'Оплачено',
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
                          
                          // Action indicator using CustomIconButton
                          CustomIconButton(
                            size: 28,
                            icon: widget.payment.isPaid ? Icons.close_rounded : Icons.add_rounded,
                            interactive: false, // Make it non-tappable
                            forceHover: _isHovered, // Control hover from parent
                            // Colors for hover state are still needed
                            hoverBackgroundColor: widget.payment.isPaid 
                                ? AppTheme.errorColor.withOpacity(0.1)
                                : AppTheme.primaryColor.withOpacity(0.1),
                            hoverIconColor: widget.payment.isPaid 
                                ? AppTheme.errorColor
                                : AppTheme.primaryColor,
                            hoverBorderColor: widget.payment.isPaid 
                                ? AppTheme.errorColor.withOpacity(0.3)
                                : AppTheme.primaryColor.withOpacity(0.3),
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