import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/localization/app_localizations.dart';
import '../../../shared/widgets/custom_status_badge.dart';
import '../../../shared/widgets/custom_icon_button.dart';
import '../domain/entities/installment.dart';
import '../domain/entities/installment_payment.dart';
import '../data/models/installment_model.dart';
import 'installment_payment_item.dart';
import 'payment_registration_dialog.dart';
import '../../../shared/widgets/custom_contextual_dialog.dart';
import '../services/reminder_service.dart';

class InstallmentListItem extends StatefulWidget {
  final Installment installment;
  final String clientName;
  final String productName;
  final int? installmentNumber;
  final double paidAmount;
  final double leftAmount;
  final List<InstallmentPayment> payments;
  final InstallmentPayment? nextPayment;
  final bool isExpanded;
  final bool isLoadingPayments;
  final VoidCallback onTap;
  final VoidCallback? onClientTap;
  final Function(bool) onExpansionChanged;
  final VoidCallback? onDataChanged;
  final Function(Installment)? onInstallmentUpdated;
  final VoidCallback? onDelete;
  final VoidCallback? onSelect;
  final bool isSelected;
  final VoidCallback? onSelectionToggle;

  const InstallmentListItem({
    super.key,
    required this.installment,
    required this.clientName,
    required this.productName,
    this.installmentNumber,
    required this.paidAmount,
    required this.leftAmount,
    required this.payments,
    this.nextPayment,
    required this.isExpanded,
    this.isLoadingPayments = false,
    required this.onTap,
    this.onClientTap,
    required this.onExpansionChanged,
    this.onDataChanged,
    this.onInstallmentUpdated,
    this.onDelete,
    this.onSelect,
    this.isSelected = false,
    this.onSelectionToggle,
  });

  static String getOverallStatus(
    BuildContext context,
    List<InstallmentPayment> payments,
  ) {
    // If no payments, return a default status.
    if (payments.isEmpty) return 'предстоящий';

    // First, check for any overdue payments, as this has the highest priority.
    if (payments.any((p) => p.status == 'просрочено')) {
      return 'просрочено';
    }

    // Check for any due today payments
    if (payments.any((p) => p.status == 'к оплате')) {
      return 'к оплате';
    }

    // Filter out paid payments to find the next one.
    final unpaidPayments =
        payments.where((p) => p.status != 'оплачено').toList();

    // If all payments are paid, the installment is considered paid.
    if (unpaidPayments.isEmpty) {
      return 'оплачено';
    }

    // If we have unpaid payments but none are overdue or due today, 
    // then they must be upcoming
    return 'предстоящий';
  }

  @override
  State<InstallmentListItem> createState() => _InstallmentListItemState();
}

class _InstallmentListItemState extends State<InstallmentListItem> with TickerProviderStateMixin {
  bool _isHovered = false;
  bool _isClientNameHovered = false;
  final bool _isArrowHovered = false;
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

  Widget _buildDueDateDetails(BuildContext context, InstallmentPayment nextPayment) {
    final l10n = AppLocalizations.of(context)!;
    
    // Find the first overdue payment. If none, use the next upcoming payment.
    final relevantPayment = widget.payments.firstWhere(
      (p) => p.status == 'просрочено',
      orElse: () => nextPayment,
    );

    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final dueDate = relevantPayment.dueDate;
    final due = DateTime(dueDate.year, dueDate.month, dueDate.day);
    final daysDifference = due.difference(today).inDays;

    String? text;
    Color? color;
    
    if (relevantPayment.status == 'просрочено' && daysDifference < 0) {
      text = l10n.daysShort(daysDifference);
      color = AppTheme.errorColor;
    } else if (relevantPayment.status == 'предстоящий' && daysDifference > 0) {
      text = l10n.daysShort(daysDifference);
      color = AppTheme.pendingColor;
    }

    if (text != null) {
      return Text(
        text,
        style: TextStyle(
          color: color,
          fontSize: 12,
          fontWeight: FontWeight.w400,
        ),
      );
    }
    return const SizedBox.shrink();
  }

  Widget _buildOverdueCount(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final overduePayments = widget.payments.where((p) => p.status == 'просрочено').toList();
    final overallStatus = widget.payments.isEmpty 
        ? (widget.installment is InstallmentModel 
            ? (widget.installment as InstallmentModel).dynamicStatus
            : 'предстоящий')
        : InstallmentListItem.getOverallStatus(context, widget.payments);

    if (overallStatus == 'просрочено' && overduePayments.length > 1) {
      return Padding(
        padding: const EdgeInsets.only(left: 8.0),
        child: Text(
          overduePayments.length.toString(),
          style: const TextStyle(
            color: AppTheme.errorColor,
            fontSize: 12,
            fontWeight: FontWeight.w400,
          ),
        ),
      );
    }
    return const SizedBox.shrink();
  }

  void _handleNextPaymentRegistration(Offset position) {
    if (widget.nextPayment != null) {
      PaymentRegistrationDialog.show(
        context: context,
        position: position,
        payment: widget.nextPayment!,
        onPaymentRegistered: (updatedInstallment) {
          // Update the specific installment without refreshing the entire list
          widget.onInstallmentUpdated?.call(updatedInstallment);
          // Fallback to full refresh if the specific update callback is not provided
          widget.onDataChanged?.call();
        },
      );
    }
  }

  void _sendWhatsAppReminder() async {
    await ReminderService.sendSingleReminder(
      context: context,
      installmentId: widget.installment.id,
      templateType: 'manual',
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final currencyFormat = NumberFormat.currency(
      locale: l10n?.locale.languageCode == 'ru' ? 'ru_RU' : 'en_US',
      symbol: l10n?.locale.languageCode == 'ru' ? '₽' : '\$',
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
                  onSendWhatsAppReminder: () => _sendWhatsAppReminder(),
                ),
                width: 260,
                estimatedHeight: 120,
              );
            },
            child: AnimatedBuilder(
              animation: _hoverAnimation,
              builder: (context, child) {
                // Define selection color
                final Color selectionColor = const Color(0xFFE3F2FD); // Light blue selection color
                
                return Container(
                  margin: const EdgeInsets.symmetric(horizontal: 0, vertical: 0),
                  decoration: BoxDecoration(
                    color: widget.isSelected
                        ? selectionColor // Use selection color when selected
                        : widget.isExpanded
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
                      left: widget.isSelected
                          ? BorderSide(color: AppTheme.primaryColor, width: 3) // Left border for selected items
                          : BorderSide.none,
                    ),
                    // No shadow on hover
                  ),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 12),
                    child: Row(
                      children: [
                        // Removed checkbox column - now using background color for selection
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
                        // Product Name column (reduced flex)
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
                        // Installment number column (separate cell, align with header)
                        Expanded(
                          flex: 1,
                          child: Padding(
                            padding: const EdgeInsets.only(right: 16),
                            child: Text(
                              widget.installmentNumber != null
                                  ? '${widget.installmentNumber}'
                                  : '-',
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
                                    fontWeight: FontWeight.w400,
                                    fontSize: 14,
                                  ),
                              textAlign: TextAlign.start,
                            ),
                          ),
                        ),
                        // Next Due Date - Plain text
                        Expanded(
                          child: Padding(
                            padding: const EdgeInsets.only(right: 16),
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.center,
                              children: [
                                Text(
                                  dateFormat.format(nextDueDate),
                                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                        fontWeight: FontWeight.w400,
                                        fontSize: 14,
                                      ),
                                ),
                                const SizedBox(width: 3),
                                if (widget.nextPayment != null)
                                  _buildDueDateDetails(context, widget.nextPayment!),
                              ],
                            ),
                          ),
                        ),
                        // Status
                        Expanded(
                          child: Align(
                            alignment: Alignment.centerLeft,
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                CustomStatusBadge(
                                  status: widget.payments.isEmpty 
                                      ? (widget.installment is InstallmentModel 
                                          ? (widget.installment as InstallmentModel).dynamicStatus
                                          : 'предстоящий')
                                      : InstallmentListItem.getOverallStatus(
                                          context,
                                          widget.payments,
                                        ),
                                  width: 110,
                                ),
                                _buildOverdueCount(context),
                              ],
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
                              // Arrow button with optional loading indicator
                              Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
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
                                  // Loading indicator to the right of arrow
                                  if (widget.isLoadingPayments) ...[
                                    const SizedBox(width: 8),
                                    const SizedBox(
                                      width: 16,
                                      height: 16,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                        valueColor: AlwaysStoppedAnimation<Color>(AppTheme.primaryColor),
                                      ),
                                    ),
                                  ],
                                ],
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
                      onPaymentUpdated: (updatedInstallment) {
                        // Update the specific installment without refreshing the entire list
                        widget.onInstallmentUpdated?.call(updatedInstallment);
                        // Fallback to full refresh if the specific update callback is not provided
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
  final VoidCallback? onSendWhatsAppReminder;

  // WhatsApp brand color
  static const Color whatsAppColor = Color(0xFF25D366);

  const _InstallmentContextMenu({
    this.onSelect, 
    this.onDelete,
    this.onSendWhatsAppReminder,
  });

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
            icon: Icons.check,
            label: l10n?.select ?? 'Выбрать',
            onTap: onSelect,
            textStyle: textStyle,
          ),
          if (onSendWhatsAppReminder != null) ...[
            const Divider(height: 1),
            _ContextMenuTile(
              icon: Icons.chat_bubble_outline,
              label: l10n?.sendWhatsAppReminder ?? 'Send Reminder',
              onTap: onSendWhatsAppReminder,
              textStyle: textStyle?.copyWith(color: whatsAppColor),
              iconColor: whatsAppColor,
            ),
          ],
          const Divider(height: 1),
          _ContextMenuTile(
            icon: Icons.delete_outline,
            label: l10n?.deleteAction ?? 'Удалить',
            onTap: onDelete,
            textStyle: textStyle?.copyWith(color: AppTheme.errorColor),
            iconColor: AppTheme.errorColor,
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