import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/localization/app_localizations.dart';
import '../../../../shared/widgets/custom_icon_button.dart';
import '../../../../shared/widgets/custom_button.dart';
import '../../domain/entities/client.dart';
import '../../../installments/domain/entities/installment.dart';

class ClientDetailsScreenMobile extends StatelessWidget {
  final Client client;
  final List<Installment> installments;
  final DateFormat dateFormat;
  final NumberFormat currencyFormat;
  final Function() onDelete;
  final Function() onEdit;
  
  const ClientDetailsScreenMobile({
    Key? key,
    required this.client,
    required this.installments,
    required this.dateFormat,
    required this.currencyFormat,
    required this.onDelete,
    required this.onEdit,
  }) : super(key: key);

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
                      routePath: '/clients',
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Text(
                        '${l10n?.clientDetails ?? 'Детали клиента'}',
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w600,
                          letterSpacing: -0.5,
                        ),
                      ),
                    ),
                    CustomIconButton(
                      icon: Icons.edit_outlined,
                      onPressed: onEdit,
                    ),
                    const SizedBox(width: 8),
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
                  client.fullName,
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
                  // Client Info
                  Text(
                    l10n?.information ?? 'Информация',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w500,
                      color: AppTheme.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 16),
                  _buildInfoRow(l10n?.fullName ?? 'Полное имя', client.fullName),
                  _buildInfoRow(l10n?.contactNumber ?? 'Контактный номер', client.contactNumber),
                  _buildInfoRow(l10n?.passportNumber ?? 'Номер паспорта', client.passportNumber),
                  _buildInfoRow(l10n?.address ?? 'Адрес', client.address ?? 'Не указан'),
                  _buildInfoRow(l10n?.creationDate ?? 'Дата создания', dateFormat.format(client.createdAt)),

                  const SizedBox(height: 24),

                  // Installments List
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          '${l10n?.clientInstallments ?? 'Рассрочки клиента'} (${installments.length})',
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
                  
                  if (installments.isEmpty)
                    Center(
                      child: Padding(
                        padding: const EdgeInsets.all(24),
                        child: Text(l10n?.noInstallments ?? 'Нет рассрочек'),
                      ),
                    )
                  else
                    Container(
                      decoration: BoxDecoration(
                        color: AppTheme.surfaceColor,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Column(
                        children: [
                          ...installments.map((installment) {
                            return _buildMobileInstallmentItem(context, installment);
                          }),
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

  Widget _buildMobileInstallmentItem(BuildContext context, Installment installment) {
    // In mobile, we show installment details in a card with a vertical layout
    return InkWell(
      onTap: () => context.go('/installments/${installment.id}'),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          border: Border(
            bottom: BorderSide(
              color: AppTheme.borderColor.withOpacity(0.3),
              width: 1,
            ),
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              installment.productName,
              style: const TextStyle(
                fontWeight: FontWeight.w500,
                fontSize: 15,
              ),
            ),
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  currencyFormat.format(installment.installmentPrice),
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                Text(
                  '${installment.termMonths} ${AppLocalizations.of(context)?.months ?? 'месяцев'}',
                ),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              dateFormat.format(installment.downPaymentDate),
              style: const TextStyle(
                color: AppTheme.textSecondary,
                fontSize: 13,
              ),
            ),
          ],
        ),
      ),
    );
  }
} 