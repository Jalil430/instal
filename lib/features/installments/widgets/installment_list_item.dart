import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/localization/app_localizations.dart';
import '../../../shared/widgets/custom_status_badge.dart';
import '../../../shared/widgets/custom_icon_button.dart';
import '../domain/entities/installment.dart';
import '../domain/entities/installment_payment.dart';
import 'installment_payment_item.dart';
import 'payment_registration_dialog.dart';
import '../../../shared/widgets/custom_contextual_dialog.dart';

class InstallmentListItem extends StatefulWidget {
  final Installment installment;
  final String clientName;
  final String productName;
  final double paidAmount;
  final double leftAmount;
  final List<InstallmentPayment> payments;
  final InstallmentPayment? nextPayment;
  final bool isExpanded;
  final VoidCallback onTap;
  final VoidCallback? onClientTap;
  final Function(bool) onExpansionChanged;
  final VoidCallback? onDataChanged;
  final VoidCallback? onDelete;
  final VoidCallback? onSelect;

  const InstallmentListItem({
    super.key,
    required this.installment,
    required this.clientName,
    required this.productName,
    required this.paidAmount,
    required this.leftAmount,
    required this.payments,
    this.nextPayment,
    required this.isExpanded,
    required this.onTap,
    this.onClientTap,
    required this.onExpansionChanged,
    this.onDataChanged,
    this.onDelete,
    this.onSelect,
  });

  @override
  State<InstallmentListItem> createState() => _InstallmentListItemState();
}

class _InstallmentListItemState extends State<InstallmentListItem> with TickerProviderStateMixin {
  bool _isHovered = false;
  bool _isClientNameHovered = false;
  bool _isArrowHovered = false;
  bool _isNextPaymentHovered = false;
  
  late AnimationController _hoverController;
  late Animation<double> _hoverAnimation;

  @override
  void initState() {
    super.initState();
    _hoverController = AnimationController(
      duration: const Duration(milliseconds: 200),
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

  String _getOverallStatus() {
    // If no payments, return default
    if (widget.payments.isEmpty) return 'предстоящий';
    
    // First check for overdue payments (highest priority)
    bool hasOverdue = widget.payments.any((payment) => payment.status == 'просрочено');
    if (hasOverdue) return 'просрочено';
    
    // Get the next unpaid payment (by due date) to determine the most relevant status
    final unpaidPayments = widget.payments
        .where((payment) => payment.status != 'оплачено')
        .toList();
    
    if (unpaidPayments.isEmpty) {
      // All payments are paid
      return 'оплачено';
    }
    
    // Sort unpaid payments by due date to get the next one
    unpaidPayments.sort((a, b) => a.dueDate.compareTo(b.dueDate));
    final nextPayment = unpaidPayments.first;
    
    // Return the status of the next payment that needs attention
    return nextPayment.status;
  }

  void _handleNextPaymentRegistration(Offset position) {
    if (widget.nextPayment != null) {
      PaymentRegistrationDialog.show(
        context: context,
        position: position,
        payment: widget.nextPayment!,
        onPaymentRegistered: () {
          // Just refresh data without affecting expansion state
          widget.onDataChanged?.call();
        },
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

    // Get next payment due date
    final nextDueDate = widget.nextPayment?.dueDate ?? widget.installment.installmentEndDate;

    return Column(
      children: [
        MouseRegion(
          onEnter: (_) {
            setState(() => _isHovered = true);
            _hoverController.forward();
          },
          onExit: (_) {
            setState(() => _isHovered = false);
            _hoverController.reverse();
          },
          child: GestureDetector(
            onTap: widget.onTap,
            onSecondaryTapDown: (details) async {
              await CustomContextualDialog.show(
                context: context,
                position: details.globalPosition,
                child: _InstallmentContextMenu(
                  onSelect: widget.onSelect,
                  onDelete: widget.onDelete,
                ),
                width: 200,
                estimatedHeight: 100,
              );
            },
            child: AnimatedBuilder(
              animation: _hoverAnimation,
              builder: (context, child) {
                return Container(
                  margin: const EdgeInsets.symmetric(horizontal: 0, vertical: 0),
                  decoration: BoxDecoration(
                    color: widget.isExpanded
                        ? Color.lerp(
                            const Color(0xFFF8F9FA),
                            const Color(0xFFF1F3F4),
                            _hoverAnimation.value,
                          )
                        : Color.lerp(
                            AppTheme.surfaceColor,
                            AppTheme.backgroundColor,
                            _hoverAnimation.value * 0.6,
                          ),
                    border: Border(
                      bottom: BorderSide(
                        color: AppTheme.borderColor.withOpacity(0.3),
                        width: 1,
                      ),
                    ),
                    // No shadow on hover
                  ),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 12),
                    child: Row(
                      children: [
                        // Client Name - Simple
                        Expanded(
                          flex: 2,
                          child: Padding(
                            padding: const EdgeInsets.only(right: 16),
                            child: GestureDetector(
                              onTap: widget.onClientTap,
                              child: Align(
                                alignment: Alignment.centerLeft,
                                child: MouseRegion(
                                  onEnter: (_) => setState(() => _isClientNameHovered = true),
                                  onExit: (_) => setState(() => _isClientNameHovered = false),
                                  child: IntrinsicWidth(
                                    child: Text(
                                      widget.clientName,
                                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                            fontWeight: FontWeight.w500,
                                            fontSize: 14,
                                            color: widget.onClientTap != null 
                                                ? AppTheme.interactiveBrightColor
                                                : AppTheme.textPrimary,
                                            decoration: widget.onClientTap != null && _isClientNameHovered
                                                ? TextDecoration.underline
                                                : TextDecoration.none,
                                            decorationColor: widget.onClientTap != null 
                                                ? AppTheme.interactiveBrightColor
                                                : AppTheme.textPrimary,
                                          ),
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                        // Product Name - Simple
                        Expanded(
                          flex: 2,
                          child: Padding(
                            padding: const EdgeInsets.only(right: 16),
                            child: Text(
                              widget.productName,
                              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w500,
                                  ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ),
                        // Paid Amount - Plain text
                        Expanded(
                          child: Padding(
                            padding: const EdgeInsets.only(right: 16),
                            child: Text(
                              currencyFormat.format(widget.paidAmount),
                              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                    fontWeight: FontWeight.w400,
                                    fontSize: 14,
                                  ),
                              textAlign: TextAlign.start,
                            ),
                          ),
                        ),
                        // Left Amount - Plain text
                        Expanded(
                          child: Padding(
                            padding: const EdgeInsets.only(right: 16),
                            child: Text(
                              currencyFormat.format(widget.leftAmount),
                              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w400,
                                  ),
                              textAlign: TextAlign.start,
                            ),
                          ),
                        ),
                        // Due Date - Plain text
                        Expanded(
                          child: Padding(
                            padding: const EdgeInsets.only(right: 16),
                            child: Text(
                              dateFormat.format(nextDueDate),
                              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w400,
                                  ),
                              textAlign: TextAlign.start,
                            ),
                          ),
                        ),
                        // Status
                        Expanded(
                          child: Padding(
                            padding: const EdgeInsets.only(right: 16),
                            child: Container(
                              width: 120, // Fixed width for consistency
                              alignment: Alignment.centerLeft,
                              child: CustomStatusBadge(
                                status: _getOverallStatus(),
                                width: 110,
                              ),
                            ),
                          ),
                        ),
                        // Next Payment Section
                        Container(
                          width: 160,
                          padding: const EdgeInsets.only(left: 8),
                          child: Row(
                            children: [
                              // Next payment button area (takes remaining space)
                              Expanded(
                                child: widget.nextPayment != null 
                                    ? MouseRegion(
                                        onEnter: (_) => setState(() => _isNextPaymentHovered = true),
                                        onExit: (_) => setState(() => _isNextPaymentHovered = false),
                                        child: GestureDetector(
                                          onTapDown: (details) => _handleNextPaymentRegistration(details.globalPosition),
                                          child: Container(
                                            height: 28,
                                            decoration: BoxDecoration(
                                              color: _isNextPaymentHovered 
                                                  ? AppTheme.subtleHoverColor
                                                  : AppTheme.subtleBackgroundColor,
                                              borderRadius: BorderRadius.circular(6),
                                              border: Border.all(
                                                color: _isNextPaymentHovered 
                                                    ? AppTheme.subtleAccentColor
                                                    : AppTheme.subtleBorderColor,
                                                width: 1,
                                              ),
                                            ),
                                            child: Center(
                                              child: Text(
                                                (widget.nextPayment!.paymentNumber == 0
                                                    ? l10n?.downPaymentShort ?? 'Взнос'
                                                    : '${l10n?.month ?? 'Месяц'} ${widget.nextPayment!.paymentNumber}'),
                                                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                                  color: AppTheme.textPrimary,
                                                  fontWeight: FontWeight.w400,
                                                  fontSize: 12,
                                                ),
                                                overflow: TextOverflow.ellipsis,
                                              ),
                                            ),
                                          ),
                                        ),
                                      )
                                    : Container(), // Empty space when no next payment
                              ),
                              const SizedBox(width: 6),
                              // Arrow button using CustomIconButton with rotation
                              CustomIconButton(
                                size: 28,
                                icon: Icons.keyboard_arrow_down_rounded,
                                onPressed: () {
                                  widget.onExpansionChanged(!widget.isExpanded);
                                },
                                backgroundColor: AppTheme.backgroundColor,
                                hoverBackgroundColor: AppTheme.subtleHoverColor,
                                iconColor: AppTheme.textSecondary,
                                hoverIconColor: AppTheme.primaryColor,
                                borderColor: AppTheme.borderColor.withOpacity(0.5),
                                hoverBorderColor: AppTheme.subtleAccentColor,
                                rotation: widget.isExpanded ? 0.5 : 0.0, // Use rotation property
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
        ),
        // Expandable payment list as table rows
        ClipRect(
          child: AnimatedAlign(
            duration: const Duration(milliseconds: 200),
            curve: Curves.easeInOut,
            alignment: Alignment.topCenter,
            heightFactor: widget.isExpanded ? 1.0 : 0.0,
            child: Container(
              color: const Color(0xFFF8F9FA),
              child: Column(
                children: [
                  // Payment items as table rows
                  ...widget.payments.map((payment) {
                    return InstallmentPaymentItem(
                      payment: payment,
                      onPaymentUpdated: () {
                        // Just refresh data without affecting expansion state
                        widget.onDataChanged?.call();
                      },
                      isExpanded: true, // Expanded in list item
                    );
                  }),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _InstallmentContextMenu extends StatelessWidget {
  final VoidCallback? onSelect;
  final VoidCallback? onDelete;

  const _InstallmentContextMenu({this.onSelect, this.onDelete});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final textStyle = Theme.of(context).textTheme.bodyMedium?.copyWith(
      fontSize: 14,
      fontWeight: FontWeight.w400,
      color: Theme.of(context).colorScheme.onSurface,
    );
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _ContextMenuTile(
            icon: Icons.check_box_outline_blank,
            label: l10n?.select ?? 'Выбрать',
            onTap: onSelect,
            textStyle: textStyle,
          ),
          _ContextMenuTile(
            icon: Icons.delete_outline,
            label: l10n?.deleteAction ?? 'Удалить',
            onTap: onDelete,
            textStyle: textStyle?.copyWith(color: Colors.red),
            iconColor: Colors.red,
          ),
        ],
      ),
    );
  }
}

class _ContextMenuTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback? onTap;
  final TextStyle? textStyle;
  final Color? iconColor;

  const _ContextMenuTile({
    required this.icon,
    required this.label,
    this.onTap,
    this.textStyle,
    this.iconColor,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(8),
      onTap: () {
        Navigator.of(context).pop();
        onTap?.call();
      },
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        child: Row(
          children: [
            Icon(icon, size: 18, color: iconColor ?? Theme.of(context).iconTheme.color),
            const SizedBox(width: 12),
            Text(label, style: textStyle),
          ],
        ),
      ),
    );
  }
}