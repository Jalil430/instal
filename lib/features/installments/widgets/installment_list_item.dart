import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/localization/app_localizations.dart';
import '../../../shared/widgets/custom_status_badge.dart';
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
  final Function(InstallmentPayment)? onDeletePayment;
  final VoidCallback? onClientTap;

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
    this.onDeletePayment,
    this.onClientTap,
  });

  @override
  State<InstallmentListItem> createState() => _InstallmentListItemState();
}

class _InstallmentListItemState extends State<InstallmentListItem> with TickerProviderStateMixin {
  bool _isHovered = false;
  bool _isExpanded = false;
  bool _isClientNameHovered = false;
  bool _isArrowHovered = false;
  bool _isNextPaymentHovered = false;
  
  late AnimationController _hoverController;
  late AnimationController _expandController;
  late Animation<double> _hoverAnimation;
  late Animation<double> _expandAnimation;

  @override
  void initState() {
    super.initState();
    _hoverController = AnimationController(
      duration: const Duration(milliseconds: 200),
      vsync: this,
    );
    _expandController = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );
    
    _hoverAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _hoverController, curve: Curves.easeInOut),
    );
    _expandAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _expandController, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _hoverController.dispose();
    _expandController.dispose();
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
            child: AnimatedBuilder(
              animation: _hoverAnimation,
              builder: (context, child) {
                return Container(
                  margin: const EdgeInsets.symmetric(horizontal: 0, vertical: 0),
                  decoration: BoxDecoration(
                    color: _isExpanded
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
                                          onTap: () => widget.onRegisterPayment(widget.nextPayment!),
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
                              // Arrow button (fixed position)
                              MouseRegion(
                                onEnter: (_) => setState(() => _isArrowHovered = true),
                                onExit: (_) => setState(() => _isArrowHovered = false),
                                child: Container(
                                  width: 28,
                                  height: 28,
                                  decoration: BoxDecoration(
                                    color: _isArrowHovered 
                                        ? AppTheme.subtleHoverColor
                                        : AppTheme.backgroundColor,
                                    borderRadius: BorderRadius.circular(8),
                                    border: Border.all(
                                      color: _isArrowHovered 
                                          ? AppTheme.subtleAccentColor
                                          : AppTheme.borderColor.withOpacity(0.5),
                                      width: 1,
                                    ),
                                  ),
                                  child: IconButton(
                                    icon: AnimatedRotation(
                                      turns: _isExpanded ? 0.5 : 0,
                                      duration: const Duration(milliseconds: 200),
                                      child: Icon(
                                        Icons.keyboard_arrow_down_rounded,
                                        color: _isArrowHovered 
                                            ? AppTheme.primaryColor
                                            : AppTheme.textSecondary,
                                        size: 16,
                                      ),
                                    ),
                                    onPressed: () {
                                      setState(() => _isExpanded = !_isExpanded);
                                      if (_isExpanded) {
                                        _expandController.forward();
                                      } else {
                                        _expandController.reverse();
                                      }
                                    },
                                    padding: EdgeInsets.zero,
                                    constraints: const BoxConstraints(),
                                    hoverColor: Colors.transparent,
                                    splashColor: Colors.transparent,
                                    highlightColor: Colors.transparent,
                                  ),
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
        ),
        // Expandable payment list as table rows
        AnimatedBuilder(
          animation: _expandAnimation,
          builder: (context, child) {
            return ClipRect(
              child: Align(
                alignment: Alignment.topCenter,
                heightFactor: _expandAnimation.value,
                child: Container(
                  color: const Color(0xFFF8F9FA),
                  child: Column(
                    children: [
                      // Payment items as table rows
                      ...widget.payments.map((payment) {
                        return InstallmentPaymentItem(
                          payment: payment,
                          onRegisterPayment: () => widget.onRegisterPayment(payment),
                          onDeletePayment: widget.onDeletePayment != null 
                              ? () => widget.onDeletePayment!(payment)
                              : null,
                        );
                      }).toList(),
                    ],
                  ),
                ),
              ),
            );
          },
        ),
      ],
    );
  }
}