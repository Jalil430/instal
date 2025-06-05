import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/localization/app_localizations.dart';
import '../domain/entities/installment_payment.dart';

class InstallmentPaymentItem extends StatelessWidget {
  final InstallmentPayment payment;
  final VoidCallback onRegisterPayment;

  const InstallmentPaymentItem({
    super.key,
    required this.payment,
    required this.onRegisterPayment,
  });

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final currencyFormat = NumberFormat.currency(
      locale: 'ru_RU',
      symbol: '₽',
      decimalDigits: 0,
    );
    final dateFormat = DateFormat('dd.MM.yyyy');

    final isPaid = payment.status == 'оплачено';
    final isOverdue = payment.status == 'просрочено';
    final isDueToPay = payment.status == 'к оплате';
    final isUpcoming = payment.status == 'предстоящий';

    // Get consistent colors with status badges
    Color statusColor;
    if (isPaid) {
      statusColor = AppTheme.successColor;
    } else if (isOverdue) {
      statusColor = AppTheme.errorColor;
    } else if (isDueToPay) {
      statusColor = AppTheme.warningColor;
    } else if (isUpcoming) {
      statusColor = AppTheme.pendingColor;
    } else {
      statusColor = AppTheme.textHint;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
      decoration: const BoxDecoration(
        border: Border(
          top: BorderSide(
            color: AppTheme.borderColor,
            width: 1,
          ),
        ),
      ),
      child: Row(
        children: [
          // Status icon
          Icon(
            isPaid ? Icons.check_circle : Icons.circle_outlined,
            size: 20,
            color: statusColor,
          ),
          const SizedBox(width: 16),
          // Payment number
          SizedBox(
            width: 120,
            child: Text(
              payment.paymentNumber == 0
                  ? l10n?.downPayment ?? 'Первоначальный взнос'
                  : '${l10n?.month ?? 'Месяц'} ${payment.paymentNumber}',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: isPaid ? AppTheme.textSecondary : AppTheme.textPrimary,
                    fontWeight: FontWeight.w500,
                  ),
            ),
          ),
          const SizedBox(width: 24),
          // Due date
          SizedBox(
            width: 100,
            child: Text(
              dateFormat.format(payment.dueDate),
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: isPaid ? AppTheme.textSecondary : AppTheme.textPrimary,
                  ),
            ),
          ),
          const SizedBox(width: 24),
          // Expected amount
          Expanded(
            child: Text(
              currencyFormat.format(payment.expectedAmount),
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: isPaid ? AppTheme.textSecondary : AppTheme.textPrimary,
                  ),
            ),
          ),
          // Paid amount
          if (isPaid) ...[
            const SizedBox(width: 16),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: AppTheme.successColor.withOpacity(0.1),
                borderRadius: BorderRadius.circular(4),
              ),
              child: Text(
                currencyFormat.format(payment.paidAmount),
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: AppTheme.successColor,
                      fontWeight: FontWeight.w600,
                    ),
              ),
            ),
            if (payment.paidDate != null) ...[
              const SizedBox(width: 8),
              Text(
                dateFormat.format(payment.paidDate!),
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: AppTheme.textSecondary,
                    ),
              ),
            ],
          ],
          // Register payment button
          if (!isPaid) ...[
            const SizedBox(width: 16),
            TextButton(
              onPressed: onRegisterPayment,
              style: TextButton.styleFrom(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              ),
              child: Text(
                l10n?.registerPayment ?? 'Оплатить',
                style: TextStyle(
                  fontSize: 12,
                  color: isOverdue ? AppTheme.errorColor : AppTheme.primaryColor,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
} 