import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../../../../core/utils/num_format.dart';
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
                  _buildInfoRow(l10n?.contactNumber ?? 'Телефон', client.contactNumber),
                  _buildInfoRow(l10n?.passportNumber ?? 'Номер паспорта', client.passportNumber),
                  _buildInfoRow(l10n?.address ?? 'Адрес', client.address ?? (l10n?.unknown ?? 'Не указан')),

                  const SizedBox(height: 24),
                  // Guarantor Info Section
                  Text(
                    l10n?.gurantor ?? 'Поручитель',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w500,
                      color: AppTheme.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 16),
                  _buildInfoRow(l10n?.guarantorFullName ?? 'ФИО поручителя', client.guarantorFullName ?? (l10n?.unknown ?? 'Не указано')),
                  _buildInfoRow(l10n?.guarantorContactNumber ?? 'Контактный номер поручителя', client.guarantorContactNumber ?? (l10n?.unknown ?? 'Не указан')),
                  _buildInfoRow(l10n?.guarantorPassportNumber ?? 'Паспорт поручителя', client.guarantorPassportNumber ?? (l10n?.unknown ?? 'Не указан')),
                  _buildInfoRow(l10n?.guarantorAddress ?? 'Адрес поручителя', client.guarantorAddress ?? (l10n?.unknown ?? 'Не указан')),

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
                  
                  Container(
                    decoration: BoxDecoration(
                      color: AppTheme.surfaceColor,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: AppTheme.borderColor),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Header
                        Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: AppTheme.subtleBackgroundColor,
                            borderRadius: const BorderRadius.only(
                              topLeft: Radius.circular(11),
                              topRight: Radius.circular(11),
                            ),
                            border: Border(
                              bottom: BorderSide(color: AppTheme.subtleBorderColor),
                            ),
                          ),
                          child: Row(
                            children: [
                              Text(
                                '${l10n?.clientInstallments ?? 'Рассрочки клиента'} (${installments.length})',
                                style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: AppTheme.textPrimary),
                              ),
                            ],
                          ),
                        ),
                        Padding(
                          padding: const EdgeInsets.all(16),
                          child: installments.isEmpty
                              ? Text(l10n?.noInstallments ?? 'Нет рассрочек', style: const TextStyle(color: AppTheme.textSecondary))
                              : SizedBox(
                                  height: 300,
                                  child: ListView.builder(
                                    itemCount: installments.length,
                                    itemBuilder: (context, index) => _buildMobileInstallmentItem(context, installments[index]),
                                  ),
                                ),
                        ),
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
    return InkWell(
      onTap: () => context.go('/installments/${installment.id}'),
      child: Container(
        margin: const EdgeInsets.only(bottom: AppTheme.spacingSm),
        padding: const EdgeInsets.all(AppTheme.spacingMd),
        decoration: BoxDecoration(
          color: AppTheme.subtleBackgroundColor,
          borderRadius: BorderRadius.circular(AppTheme.borderRadiusMedium),
          border: Border.all(color: AppTheme.subtleBorderColor),
        ),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    installment.productName,
                    style: const TextStyle(fontWeight: FontWeight.w500),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '${stripTrailingZeroMoney(currencyFormat.format(installment.installmentPrice))} • ${installment.termMonths} ${AppLocalizations.of(context)?.months ?? 'месяцев'}',
                    style: const TextStyle(fontSize: 12, color: AppTheme.textSecondary),
                  ),
                ],
              ),
            ),
            Text(
              dateFormat.format(installment.downPaymentDate),
              style: const TextStyle(fontSize: 12, color: AppTheme.textSecondary),
            ),
          ],
        ),
      ),
    );
  }
} 
