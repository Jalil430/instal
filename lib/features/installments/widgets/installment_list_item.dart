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
  // Shows generic per-item busy state for background operations (delete, update payment)
  final bool isBusy;
  final VoidCallback onTap;
  final VoidCallback? onClientTap;
  final Function(bool) onExpansionChanged;
  final VoidCallback? onDataChanged;
  final Function(Installment)? onInstallmentUpdated;
  // Background submission handler for payment register/delete
  final void Function(InstallmentPayment updatedPayment)?
  onSubmitPaymentInBackground;
  final VoidCallback? onDelete;
  final VoidCallback? onSelect;
  final bool isSelected;
  final VoidCallback? onSelectionToggle;
  final bool showTrailingControls;

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
    this.isBusy = false,
    required this.onTap,
    this.onClientTap,
    required this.onExpansionChanged,
    this.onDataChanged,
    this.onInstallmentUpdated,
    this.onDelete,
    this.onSubmitPaymentInBackground,
    this.onSelect,
    this.isSelected = false,
    this.onSelectionToggle,
    this.showTrailingControls = true,
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

class _InstallmentListItemState extends State<InstallmentListItem>
    with TickerProviderStateMixin {
  bool _isHovered = false;
  bool _isClientNameHovered = false;

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

  Widget _buildDueDateDetails(
    BuildContext context,
    InstallmentPayment nextPayment,
  ) {
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
    final overduePayments =
        widget.payments.where((p) => p.status == 'просрочено').toList();
    final overallStatus =
        widget.payments.isEmpty
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
          // Update in place if handler provided, else fallback to full refresh
          if (widget.onInstallmentUpdated != null) {
            widget.onInstallmentUpdated!.call(updatedInstallment);
          } else {
            widget.onDataChanged?.call();
          }
        },
        onSubmitInBackground: widget.onSubmitPaymentInBackground,
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
    final EdgeInsetsGeometry contentPadding =
        widget.showTrailingControls
            ? const EdgeInsets.symmetric(horizontal: 32, vertical: 12)
            : const EdgeInsets.symmetric(horizontal: 24, vertical: 12);

    // Get next payment due date
    final nextDueDate =
        widget.nextPayment?.dueDate ?? widget.installment.installmentEndDate;

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
                final Color selectionColor = const Color(
                  0xFFE3F2FD,
                ); // Light blue selection color

                return Container(
                  margin: const EdgeInsets.symmetric(
                    horizontal: 0,
                    vertical: 0,
                  ),
                  decoration: BoxDecoration(
                    color:
                        widget.isSelected
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
                      left:
                          widget.isSelected
                              ? BorderSide(
                                color: AppTheme.primaryColor,
                                width: 3,
                              ) // Left border for selected items
                              : BorderSide.none,
                    ),
                    // No shadow on hover
                  ),
                  child: Padding(
                    padding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    child: Row(
                      children: [
                        // Installment number column moved to the start to match the header
                        SizedBox(
                          width: 54,
                          child: Text(
                            (widget.installmentNumber ??
                                        widget
                                            .installment
                                            .installmentNumber) !=
                                    null
                                ? '${widget.installmentNumber ?? widget.installment.installmentNumber}'
                                : '-',
                            style: Theme.of(
                              context,
                            ).textTheme.bodyMedium?.copyWith(
                              fontSize: 14,
                              fontWeight: FontWeight.w500,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        const SizedBox(width: 16),
                        // Client Name - More space for client names
                        Expanded(
                          flex: 5,
                          child: GestureDetector(
                            onTap: widget.onClientTap,
                            child: Align(
                              alignment: Alignment.centerLeft,
                              child: MouseRegion(
                                onEnter:
                                    (_) => setState(
                                      () => _isClientNameHovered = true,
                                    ),
                                onExit:
                                    (_) => setState(
                                      () => _isClientNameHovered = false,
                                    ),
                                child: IntrinsicWidth(
                                  child: Text(
                                    widget.clientName,
                                    style: Theme.of(
                                      context,
                                    ).textTheme.bodyMedium?.copyWith(
                                      fontWeight: FontWeight.w500,
                                      fontSize: 14,
                                      color:
                                          widget.onClientTap != null
                                              ? AppTheme
                                                  .interactiveBrightColor
                                              : AppTheme.textPrimary,
                                      decoration:
                                          widget.onClientTap != null &&
                                                  _isClientNameHovered
                                              ? TextDecoration.underline
                                              : TextDecoration.none,
                                      decorationColor:
                                          widget.onClientTap != null
                                              ? AppTheme
                                                  .interactiveBrightColor
                                              : AppTheme.textPrimary,
                                    ),
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 16),
                        // Product Name column - Reduced space for product names
                        Expanded(
                          flex: 3,
                          child: Text(
                            widget.productName,
                            style: Theme.of(
                              context,
                            ).textTheme.bodyMedium?.copyWith(
                              fontSize: 14,
                              fontWeight: FontWeight.w500,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        const SizedBox(width: 16),
                        // Total price column
                        Expanded(
                          flex: 2,
                          child: Text(
                            currencyFormat
                                .format(widget.installment.installmentPrice),
                            style: Theme.of(
                              context,
                            ).textTheme.bodyMedium?.copyWith(
                              fontWeight: FontWeight.w400,
                              fontSize: 14,
                            ),
                            textAlign: TextAlign.start,
                          ),
                        ),
                        const SizedBox(width: 16),
                        // Paid Amount - Plain text
                        Expanded(
                          flex: 2,
                          child: Text(
                            currencyFormat.format(widget.paidAmount),
                            style: Theme.of(
                              context,
                            ).textTheme.bodyMedium?.copyWith(
                              fontWeight: FontWeight.w400,
                              fontSize: 14,
                            ),
                            textAlign: TextAlign.start,
                          ),
                        ),
                        const SizedBox(width: 16),
                        // Left Amount - Plain text
                        Expanded(
                          flex: 2,
                          child: Text(
                            currencyFormat.format(widget.leftAmount),
                            style: Theme.of(
                              context,
                            ).textTheme.bodyMedium?.copyWith(
                              fontWeight: FontWeight.w400,
                              fontSize: 14,
                            ),
                            textAlign: TextAlign.start,
                          ),
                        ),
                        const SizedBox(width: 16),
                        // Next Due Date - moved to left of status
                        Expanded(
                          flex: 2,
                          child: LayoutBuilder(
                            builder: (context, constraints) {
                              return Row(
                                crossAxisAlignment: CrossAxisAlignment.center,
                                children: [
                                  Flexible(
                                    child: Text(
                                      dateFormat.format(nextDueDate),
                                      style: Theme.of(
                                        context,
                                      ).textTheme.bodyMedium?.copyWith(
                                        fontWeight: FontWeight.w400,
                                        fontSize: 14,
                                      ),
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                  // Only show days calculation if there's enough space (>80px)
                                  if (constraints.maxWidth > 80 && widget.nextPayment != null) ...[
                                    const SizedBox(width: 3),
                                    _buildDueDateDetails(
                                      context,
                                      widget.nextPayment!,
                                    ),
                                  ],
                                ],
                              );
                            },
                          ),
                        ),
                        const SizedBox(width: 16),
                        // Status - at the very right before expand arrow
                        Expanded(
                          flex: 2,
                          child: Align(
                            alignment: Alignment.centerLeft,
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Flexible(
                                  child: CustomStatusBadge(
                                    status:
                                        widget.payments.isEmpty
                                            ? (widget.installment
                                                    is InstallmentModel
                                                ? (widget.installment
                                                        as InstallmentModel)
                                                    .dynamicStatus
                                                : 'предстоящий')
                                            : InstallmentListItem.getOverallStatus(
                                              context,
                                              widget.payments,
                                            ),
                                  ),
                                ),
                                _buildOverdueCount(context),
                              ],
                            ),
                          ),
                        ),
                        if (widget.showTrailingControls)
                          Container(
                            width: 44,
                            child: Row(
                              children: [
                                const Spacer(),
                                widget.isLoadingPayments || widget.isBusy
                                    ? const SizedBox(
                                        width: 18,
                                        height: 18,
                                        child: CircularProgressIndicator(
                                          strokeWidth: 2,
                                          valueColor:
                                              AlwaysStoppedAnimation<Color>(
                                            AppTheme.primaryColor,
                                          ),
                                        ),
                                      )
                                    : CustomIconButton(
                                        size: 28,
                                        icon: Icons.keyboard_arrow_down_rounded,
                                        onPressed: () {
                                          widget.onExpansionChanged(
                                            !widget.isExpanded,
                                          );
                                        },
                                        backgroundColor: AppTheme.backgroundColor,
                                        hoverBackgroundColor:
                                            AppTheme.subtleHoverColor,
                                        iconColor: AppTheme.textSecondary,
                                        hoverIconColor: AppTheme.primaryColor,
                                        borderColor: AppTheme.borderColor
                                            .withOpacity(0.5),
                                        hoverBorderColor:
                                            AppTheme.subtleAccentColor,
                                        rotation:
                                            widget.isExpanded
                                                ? 0.5
                                                : 0.0,
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
                  ...() {
                    // Determine permissions per payment
                    final payments = widget.payments;
                    InstallmentPayment? nextUnpaid;
                    InstallmentPayment? lastPaid;
                    for (final p in payments) {
                      if (!p.isPaid && nextUnpaid == null) {
                        nextUnpaid = p;
                      }
                      if (p.isPaid) {
                        lastPaid =
                            p; // will end as most recent paid if list is ordered
                      }
                    }

                    return payments.map((payment) {
                      final canRegister =
                          (!payment.isPaid) && (payment.id == nextUnpaid?.id);
                      final canDelete =
                          (payment.isPaid) && (payment.id == lastPaid?.id);
                      return InstallmentPaymentItem(
                        payment: payment,
                        onPaymentUpdated: (updatedInstallment) {
                          // Update in place if handler provided, else fallback to full refresh
                          if (widget.onInstallmentUpdated != null) {
                            widget.onInstallmentUpdated!(updatedInstallment);
                          } else {
                            widget.onDataChanged?.call();
                          }
                        },
                        isExpanded: true, // Expanded in list item
                        canRegister: canRegister,
                        canDelete: canDelete,
                        onSubmitPaymentInBackground:
                            widget.onSubmitPaymentInBackground,
                      );
                    });
                  }(),
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
            Icon(
              icon,
              size: 18,
              color: iconColor ?? Theme.of(context).iconTheme.color,
            ),
            const SizedBox(width: 12),
            Text(label, style: textStyle),
          ],
        ),
      ),
    );
  }
}
