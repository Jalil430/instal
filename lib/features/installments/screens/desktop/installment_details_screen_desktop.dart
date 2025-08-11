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

class InstallmentDetailsScreenDesktop extends StatelessWidget {
  final Installment installment;
  final Client client;
  final Investor? investor;
  final List<InstallmentPayment> payments;
  final DateFormat dateFormat;
  final NumberFormat currencyFormat;
  final Function() onDelete;
  final Function(InstallmentPayment) onPaymentPress;
  
  const InstallmentDetailsScreenDesktop({
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

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);

    return Scaffold(
      backgroundColor: Colors.white,
      body: Column(
        children: [
          // Header
          Container(
            padding: const EdgeInsets.fromLTRB(32, 28, 32, 20),
            color: AppTheme.surfaceColor,
            child: Row(
              children: [
                CustomIconButton(
                  routePath: '/installments',
                ),
                const SizedBox(width: 16),
                Text(
                  '${l10n?.installmentDetails ?? 'Детали рассрочки'} - ${installment.productName}',
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w600,
                    letterSpacing: -0.5,
                  ),
                ),
                const Spacer(),
                CustomIconButton(
                  icon: Icons.delete_outline,
                  onPressed: onDelete,
                  hoverBackgroundColor: AppTheme.errorColor.withOpacity(0.1),
                  hoverIconColor: AppTheme.errorColor,
                  hoverBorderColor: AppTheme.errorColor.withOpacity(0.3),
                ),
              ],
            ),
          ),
          // Content
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Left column - Main Information
                      Expanded(
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
                            const SizedBox(height: 20),
                            
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
                              
                             // Installment number
                             if (installment.installmentNumber != null)
                               _buildInfoRow(l10n?.number ?? 'Number', '#${installment.installmentNumber}'),

                             // Product details (after client and investor)
                            _buildInfoRow(l10n?.product ?? 'Название товара', installment.productName),
                             _buildInfoRow(l10n?.cashPrice ?? 'Цена за наличные', currencyFormat.format(installment.cashPrice)),
                             _buildInfoRow(l10n?.installmentPrice ?? 'Сумма рассрочки', currencyFormat.format(installment.installmentPrice)),
                            _buildInfoRow(l10n?.term ?? 'Срок в месяцах', '${installment.termMonths} ${l10n?.monthsLabel ?? 'месяцев'}'),
                            _buildInfoRow(l10n?.downPaymentFull ?? 'Первоначальный взнос', currencyFormat.format(installment.downPayment)),
                             _buildInfoRow(l10n?.monthlyPayment ?? 'Ежемесячный платеж', currencyFormat.format(installment.monthlyPayment)),
                            _buildInfoRow(l10n?.buyingDate ?? 'Дата первого взноса', dateFormat.format(installment.downPaymentDate)),
                             _buildInfoRow(l10n?.installmentStartDate ?? 'Дата начала рассрочки', dateFormat.format(installment.installmentStartDate)),
                             _buildInfoRow(l10n?.installmentEndDate ?? 'Дата окончания рассрочки', dateFormat.format(installment.installmentEndDate)),
                          ],
                        ),
                      ),
                      
                      const SizedBox(width: 40),
                      
                      // Right column - Empty now
                      const Expanded(child: SizedBox()),
                    ],
                  ),

                  const SizedBox(height: 30),

                  // Payments List
                  Row(
                    children: [
                      Text(
                        '${l10n?.scheduleHeader ?? 'Платежи'} (${payments.length}/${installment.termMonths})',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w500,
                          color: AppTheme.textPrimary,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  
                  Container(
                    decoration: BoxDecoration(
                      color: AppTheme.surfaceColor,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Column(
                      children: [
                        _buildTableHeader(context),
                        ...payments.map((payment) {
                          return InstallmentPaymentItem(
                            payment: payment,
                            onPaymentUpdated: (updatedInstallment) {
                              // This callback will be handled by the parent screen
                              // and it will reload the data
                            },
                            isExpanded: false,
                          );
                        }),
                        // Add remaining payments if any
                        if (payments.length < installment.termMonths)
                          ..._buildRemainingPayments(context),
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

  Widget _buildTableHeader(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      decoration: BoxDecoration(
        color: AppTheme.subtleBackgroundColor,
        borderRadius: const BorderRadius.only(
          topLeft: Radius.circular(11),
          topRight: Radius.circular(11),
        ),
        border: Border(
          bottom: BorderSide(
            color: AppTheme.subtleBorderColor,
            width: 1,
          ),
        ),
      ),
      child: Row(
        children: [
          Expanded(
            flex: 2,
            child: Text(
              l10n?.paymentHeader ?? 'НОМЕР ПЛАТЕЖА',
              style: Theme.of(context).textTheme.labelMedium?.copyWith(
                    color: AppTheme.textSecondary,
                    fontWeight: FontWeight.w400,
                    fontSize: 12,
                    letterSpacing: 0.5,
                  ),
            ),
          ),
          Expanded(
            flex: 2,
            child: Text(
              l10n?.dateHeader ?? 'ДАТА ПЛАТЕЖА',
              style: Theme.of(context).textTheme.labelMedium?.copyWith(
                    color: AppTheme.textSecondary,
                    fontWeight: FontWeight.w400,
                    fontSize: 12,
                    letterSpacing: 0.5,
                  ),
            ),
          ),
          Expanded(
            flex: 2,
            child: Text(
              l10n?.amountHeader ?? 'СУММА ПЛАТЕЖА',
              style: Theme.of(context).textTheme.labelMedium?.copyWith(
                    color: AppTheme.textSecondary,
                    fontWeight: FontWeight.w400,
                    fontSize: 12,
                    letterSpacing: 0.5,
                  ),
            ),
          ),
          Expanded(
            flex: 2,
            child: Text(
              l10n?.statusHeader ?? 'СТАТУС',
              style: Theme.of(context).textTheme.labelMedium?.copyWith(
                    color: AppTheme.textSecondary,
                    fontWeight: FontWeight.w400,
                    fontSize: 12,
                    letterSpacing: 0.5,
                  ),
            ),
          ),
          const SizedBox(width: 40), // Space for action button
        ],
      ),
    );
  }

  List<Widget> _buildRemainingPayments(BuildContext context) {
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
      
      remainingPaymentWidgets.add(
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
          decoration: BoxDecoration(
            border: Border(
              bottom: i < remainingCount - 1 ? BorderSide(
                color: AppTheme.borderColor.withOpacity(0.3),
                width: 1,
              ) : BorderSide.none,
            ),
          ),
          child: Row(
            children: [
              Expanded(
                flex: 2,
                child: Text(
                  '${l10n?.paymentHeader ?? 'Платеж'} ${payments.length + i + 1}',
                  style: const TextStyle(
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
              Expanded(
                flex: 2,
                child: Text(
                  dateFormat.format(expectedDate),
                  style: const TextStyle(
                    color: AppTheme.textSecondary,
                  ),
                ),
              ),
              Expanded(
                flex: 2,
                child: Text(
                  currencyFormat.format(installment.monthlyPayment),
                  style: const TextStyle(
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
              Expanded(
                flex: 2,
                child: Row(
                  children: [
                    Container(
                      width: 8,
                      height: 8,
                      decoration: const BoxDecoration(
                        shape: BoxShape.circle,
                        color: Colors.grey,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      l10n?.upcoming ?? 'Ожидается',
                      style: const TextStyle(
                        color: Colors.grey,
                        fontSize: 13,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 40), // Space for action button
            ],
          ),
        ),
      );
    }
    
    return remainingPaymentWidgets;
  }

  Widget _buildInfoRow(String label, String value) {
    // For desktop, we put label and value side by side
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 180,
            child: Text(
              label,
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w400,
                color: Colors.grey,
              ),
            ),
          ),
          const SizedBox(width: 20),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w500,
                color: AppTheme.textPrimary,
              ),
            ),
          ),
        ],
      ),
    );
  }
  
  Widget _buildInfoRowWithClickableValue(BuildContext context, String label, String value, {required Function() onTap}) {
    // For desktop, we put label and value side by side with clickable value
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 180,
            child: Text(
              label,
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w400,
                color: Colors.grey,
              ),
            ),
          ),
          const SizedBox(width: 20),
          Expanded(
            child: InkWell(
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
          ),
        ],
      ),
    );
  }
} 