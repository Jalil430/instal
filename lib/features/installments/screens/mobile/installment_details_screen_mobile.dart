import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/localization/app_localizations.dart';
import '../../../../shared/widgets/custom_icon_button.dart';
import '../../../../shared/widgets/custom_button.dart';
import '../../domain/entities/installment.dart';
import '../../domain/entities/installment_payment.dart';
import '../../../clients/domain/entities/client.dart';
import '../../../investors/domain/entities/investor.dart';
import '../../widgets/installment_payment_item.dart';
import '../../widgets/payment_registration_dialog.dart';
import '../../widgets/payment_deletion_dialog.dart';

class InstallmentDetailsScreenMobile extends StatelessWidget {
  final Installment installment;
  final Client client;
  final Investor? investor;
  final List<InstallmentPayment> payments;
  final DateFormat dateFormat;
  final NumberFormat currencyFormat;
  final Function() onDelete;
  final Function(InstallmentPayment) onPaymentPress;
  
  const InstallmentDetailsScreenMobile({
    Key? key,
    required this.installment,
    required this.client,
    this.investor,
    required this.payments,
    required this.dateFormat,
    required this.currencyFormat,
    required this.onDelete,
    required this.onPaymentPress,
  }) : super(key: key);

  // Remove the adapter method as it's not the right approach

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final mediaQuery = MediaQuery.of(context);
    final statusBarHeight = mediaQuery.padding.top;

    return Scaffold(
      backgroundColor: Colors.white,
      body: Column(
        children: [
          // Header with safe area for status bar
          Container(
            padding: EdgeInsets.fromLTRB(16, statusBarHeight + 16, 16, 16),
            decoration: const BoxDecoration(
              color: AppTheme.surfaceColor,
              boxShadow: [
                BoxShadow(
                  color: Color(0x0D000000),
                  blurRadius: 4,
                  offset: Offset(0, 2),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    CustomIconButton(
                      routePath: '/installments',
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Text(
                        '${l10n?.installmentDetails ?? 'Детали рассрочки'}',
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w600,
                          letterSpacing: -0.5,
                        ),
                      ),
                    ),
                    CustomIconButton(
                      icon: Icons.delete_outline,
                      onPressed: onDelete,
                      hoverBackgroundColor: AppTheme.errorColor.withOpacity(0.1),
                      hoverIconColor: AppTheme.errorColor,
                      hoverBorderColor: AppTheme.errorColor.withOpacity(0.3),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  installment.productName,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w500,
                    color: AppTheme.textPrimary,
                  ),
                ),
              ],
            ),
          ),
          
          // Content
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Product Info
                  Text(
                    l10n?.information ?? 'Информация о товаре',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w500,
                      color: AppTheme.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 16),
                  
                  // Client Info (moved to top)
                  _buildInfoRowWithClickableValue(
                    context,
                    l10n?.client ?? 'Клиент',
                    client.fullName,
                    onTap: () => context.go('/clients/${client.id}'),
                  ),
                  
                  // Investor Info (moved to top)
                  if (investor != null)
                    _buildInfoRowWithClickableValue(
                      context,
                      l10n?.investor ?? 'Инвестор',
                      investor!.fullName,
                      onTap: () => context.go('/investors/${investor!.id}'),
                    ),
                    
                  // Product details (after client and investor)
                  _buildInfoRow(l10n?.product ?? 'Название товара', installment.productName),
                  _buildInfoRow(l10n?.installmentPrice ?? 'Сумма рассрочки', currencyFormat.format(installment.installmentPrice)),
                  _buildInfoRow(l10n?.term ?? 'Срок в месяцах', '${installment.termMonths} ${l10n?.monthsLabel ?? 'месяцев'}'),
                  _buildInfoRow(l10n?.downPaymentFull ?? 'Первоначальный взнос', currencyFormat.format(installment.downPayment)),
                  _buildInfoRow(l10n?.buyingDate ?? 'Дата первого взноса', dateFormat.format(installment.downPaymentDate)),
                  _buildInfoRow(l10n?.monthlyPayment ?? 'Ежемесячный платеж', currencyFormat.format(installment.monthlyPayment)),
                  
                  const SizedBox(height: 24),

                  // Payments List
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          '${l10n?.scheduleHeader ?? 'Платежи'} (${payments.length}/${installment.termMonths})',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w500,
                            color: AppTheme.textPrimary,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  
                  Container(
                    decoration: BoxDecoration(
                      color: AppTheme.surfaceColor,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Column(
                      children: [
                        ...payments.asMap().entries.map((entry) {
                          final index = entry.key;
                          final payment = entry.value;
                          
                          // Determine payment status
                          final now = DateTime.now();
                          final isPaid = payment.isPaid;
                          final isOverdue = !isPaid && payment.dueDate.isBefore(now);
                          final isUpcoming = !isPaid && payment.dueDate.isAfter(now);
                          
                          // Select status color - use same colors as CustomStatusBadge
                          Color statusColor = AppTheme.pendingColor;
                          String statusText = l10n?.upcoming ?? 'Предстоящий';
                          
                          if (isPaid) {
                            statusColor = AppTheme.successColor;
                            statusText = l10n?.paid ?? 'Оплачено';
                          } else if (isOverdue) {
                            statusColor = AppTheme.errorColor;
                            statusText = l10n?.overdue ?? 'Просрочено';
                          }
                          
                          return Container(
                            margin: EdgeInsets.only(bottom: 8),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(8),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withOpacity(0.05),
                                  blurRadius: 4,
                                  offset: Offset(0, 2),
                                ),
                              ],
                            ),
                            child: Padding(
                              padding: const EdgeInsets.all(16),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                    children: [
                                      Text(
                                        payment.paymentNumber == 0
                                            ? l10n?.downPayment ?? 'Первоначальный взнос'
                                            : '${l10n?.month ?? 'Месяц'} ${payment.paymentNumber}',
                                        style: const TextStyle(
                                          fontWeight: FontWeight.w500,
                                          fontSize: 16,
                                        ),
                                      ),
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                        decoration: BoxDecoration(
                                          color: statusColor.withOpacity(0.1),
                                          borderRadius: BorderRadius.circular(4),
                                        ),
                                        child: Row(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            Container(
                                              width: 8,
                                              height: 8,
                                              decoration: BoxDecoration(
                                                shape: BoxShape.circle,
                                                color: statusColor,
                                              ),
                                            ),
                                            const SizedBox(width: 6),
                                            Text(
                                              statusText,
                                              style: TextStyle(
                                                fontSize: 13,
                                                color: statusColor,
                                                fontWeight: FontWeight.w500,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 16),
                                  Row(
                                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                    children: [
                                      Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          const SizedBox(height: 4),
                                          Row(
                                            children: [
                                              Column(
                                                crossAxisAlignment: CrossAxisAlignment.start,
                                                children: [
                                                  Text(
                                                    l10n?.dueDate ?? 'Срок оплаты',
                                                    style: TextStyle(
                                                      fontSize: 12,
                                                      color: Colors.grey,
                                                    ),
                                                  ),
                                                  const SizedBox(height: 4),
                                                  Text(
                                                    dateFormat.format(payment.dueDate),
                                                    style: TextStyle(
                                                      fontWeight: FontWeight.w500,
                                                    ),
                                                  ),
                                                ],
                                              ),
                                              if (isPaid && payment.paidDate != null) ...[
                                                const SizedBox(width: 16),
                                                Column(
                                                  crossAxisAlignment: CrossAxisAlignment.start,
                                                  children: [
                                                    Text(
                                                      l10n?.paid ?? 'Оплачено',
                                                      style: TextStyle(
                                                        fontSize: 12,
                                                        color: Colors.grey,
                                                      ),
                                                    ),
                                                    const SizedBox(height: 4),
                                                    Text(
                                                      dateFormat.format(payment.paidDate!),
                                                      style: TextStyle(
                                                        fontWeight: FontWeight.w500,
                                                        color: AppTheme.successColor,
                                                      ),
                                                    ),
                                                  ],
                                                ),
                                              ],
                                            ],
                                          ),
                                        ],
                                      ),
                                      Column(
                                        crossAxisAlignment: CrossAxisAlignment.end,
                                        children: [
                                          Text(
                                            l10n?.amount ?? 'Сумма',
                                            style: TextStyle(
                                              fontSize: 12,
                                              color: Colors.grey,
                                            ),
                                          ),
                                          const SizedBox(height: 4),
                                          Text(
                                            currencyFormat.format(installment.monthlyPayment),
                                            style: TextStyle(
                                              fontWeight: FontWeight.w500,
                                              fontSize: 16,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ],
                                  ),

                                  const SizedBox(height: 16),
                                  SizedBox(
                                    width: double.infinity,
                                    child: ElevatedButton(
                                      onPressed: () {
                                        // Calculate center position for dialog
                                        final screenSize = MediaQuery.of(context).size;
                                        final position = Offset(screenSize.width / 2, screenSize.height / 2);
                                        
                                        if (isPaid) {
                                          // Show payment deletion dialog
                                          PaymentDeletionDialog.show(
                                            context: context,
                                            position: position,
                                            payment: payment,
                                            onPaymentDeleted: (updatedInstallment) {
                                              // The same approach as in desktop - just reload data
                                              onPaymentPress(payment);
                                            },
                                          );
                                        } else {
                                          // Show payment registration dialog
                                          PaymentRegistrationDialog.show(
                                            context: context,
                                            position: position,
                                            payment: payment,
                                            onPaymentRegistered: (updatedInstallment) {
                                              // The same approach as in desktop - just reload data
                                              onPaymentPress(payment);
                                            },
                                          );
                                        }
                                      },
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: isPaid ? AppTheme.errorColor : AppTheme.primaryColor,
                                        foregroundColor: Colors.white,
                                        padding: const EdgeInsets.symmetric(vertical: 12),
                                      ),
                                      child: Text(
                                        isPaid 
                                            ? (l10n?.cancelPayment ?? 'Отменить платеж')
                                            : (l10n?.registerPayment ?? 'Зарегистрировать платеж'),
                                        style: const TextStyle(
                                          fontWeight: FontWeight.w500,
                                        ),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          );
                        }),
                        
                        // Add remaining payments if any
                        if (payments.length < installment.termMonths)
                          ..._buildRemainingPaymentsCardLayout(context),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  List<Widget> _buildRemainingPaymentsCardLayout(BuildContext context) {
    final remainingCount = installment.termMonths - payments.length;
    final l10n = AppLocalizations.of(context);
    
    if (remainingCount <= 0) return [];
    
    final lastPaymentDate = payments.isEmpty 
        ? installment.downPaymentDate
        : payments.last.dueDate;
    
    final List<Widget> remainingPaymentWidgets = [];
    
    for (int i = 0; i < remainingCount; i++) {
      // Calculate expected payment date (1 month after previous payment)
      final expectedDate = DateTime(
        lastPaymentDate.year, 
        lastPaymentDate.month + i + 1, 
        lastPaymentDate.day
      );
      
      // Create a placeholder payment object for this future payment
      final paymentNumber = payments.length + i + 1;
      final futurePlaceholderPayment = InstallmentPayment(
        id: 'placeholder_${installment.id}_$paymentNumber',
        installmentId: installment.id,
        paymentNumber: paymentNumber == 1 ? 0 : paymentNumber - 1, // Use 0 for down payment
        dueDate: expectedDate,
        expectedAmount: installment.monthlyPayment,
        isPaid: false,
        paidDate: null,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );
      
      remainingPaymentWidgets.add(
        Container(
          margin: EdgeInsets.only(bottom: 8),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(8),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.05),
                blurRadius: 4,
                offset: Offset(0, 2),
              ),
            ],
          ),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      payments.length + i + 1 == 1
                          ? l10n?.downPayment ?? 'Первоначальный взнос'
                          : '${l10n?.month ?? 'Месяц'} ${payments.length + i}',
                      style: const TextStyle(
                        fontWeight: FontWeight.w500,
                        fontSize: 16,
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: AppTheme.pendingColor.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Container(
                            width: 8,
                            height: 8,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: AppTheme.pendingColor,
                            ),
                          ),
                          const SizedBox(width: 6),
                          Text(
                            l10n?.upcoming ?? 'Предстоящий',
                            style: TextStyle(
                              fontSize: 13,
                              color: AppTheme.pendingColor,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          l10n?.dueDate ?? 'Срок оплаты',
                          style: const TextStyle(
                            fontSize: 12,
                            color: Colors.grey,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          dateFormat.format(expectedDate),
                          style: const TextStyle(
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text(
                          l10n?.amount ?? 'Сумма',
                          style: const TextStyle(
                            fontSize: 12,
                            color: Colors.grey,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          currencyFormat.format(installment.monthlyPayment),
                          style: const TextStyle(
                            fontWeight: FontWeight.w500,
                            fontSize: 16,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: () {
                      // Calculate center position for dialog
                      final screenSize = MediaQuery.of(context).size;
                      final position = Offset(screenSize.width / 2, screenSize.height / 2);
                      
                      // Always show registration dialog since this is a future payment
                      PaymentRegistrationDialog.show(
                        context: context,
                        position: position,
                        payment: futurePlaceholderPayment,
                        onPaymentRegistered: (updatedInstallment) {
                          // The same approach as in desktop - just reload data
                          onPaymentPress(futurePlaceholderPayment);
                        },
                      );
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppTheme.primaryColor,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                    child: Text(
                      l10n?.registerPayment ?? 'Зарегистрировать платеж',
                      style: const TextStyle(
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }
    
    return remainingPaymentWidgets;
  }

  Widget _buildInfoRow(String label, String value) {
    // For mobile, we stack label and value vertically for better space utilization
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w400,
              color: Colors.grey,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w500,
              color: AppTheme.textPrimary,
            ),
          ),
        ],
      ),
    );
  }
  
  Widget _buildInfoRowWithClickableValue(BuildContext context, String label, String value, {required Function() onTap}) {
    // For mobile, stacked layout with clickable value
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w400,
              color: Colors.grey,
            ),
          ),
          const SizedBox(height: 4),
          InkWell(
            onTap: onTap,
            child: Text(
              value,
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w500,
                color: Colors.blue,
              ),
            ),
          ),
        ],
      ),
    );
  }
} 