import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/localization/app_localizations.dart';
import '../../../../shared/widgets/custom_icon_button.dart';
import '../../../../shared/widgets/custom_button.dart';
import '../../domain/entities/investor.dart';
import '../../../installments/domain/entities/installment.dart';

class InvestorDetailsScreenDesktop extends StatelessWidget {
  final Investor investor;
  final List<Installment> installments;
  final DateFormat dateFormat;
  final NumberFormat currencyFormat;
  final Function() onDelete;
  final Function() onEdit;
  
  const InvestorDetailsScreenDesktop({
    Key? key,
    required this.investor,
    required this.installments,
    required this.dateFormat,
    required this.currencyFormat,
    required this.onDelete,
    required this.onEdit,
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
                  routePath: '/investors',
                ),
                const SizedBox(width: 16),
                Text(
                  '${l10n?.investorDetails ?? 'Детали инвестора'} - ${investor.fullName}',
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w600,
                    letterSpacing: -0.5,
                  ),
                ),
                const Spacer(),
                CustomIconButton(
                  icon: Icons.edit_outlined,
                  onPressed: onEdit,
                ),
                const SizedBox(width: 12),
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
                  // Investor Info
                  Text(
                    l10n?.information ?? 'Информация',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w500,
                      color: AppTheme.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 20),
                  _buildInfoRow(l10n?.fullName ?? 'Полное имя', investor.fullName),
                  _buildInfoRow(l10n?.contactNumber ?? 'Контактный номер', investor.userId),
                  _buildInfoRow(l10n?.investmentAmount ?? 'Сумма инвестиций', currencyFormat.format(investor.investmentAmount)),
                  _buildInfoRow(l10n?.investorShare ?? 'Доля инвестора', '${investor.investorPercentage}%'),
                  _buildInfoRow(l10n?.creationDate ?? 'Дата создания', dateFormat.format(investor.createdAt)),

                  const SizedBox(height: 20),

                  // Installments List
                  Row(
                    children: [
                      Text(
                        '${l10n?.investorInstallments ?? 'Рассрочки инвестора'} (${installments.length})',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w500,
                          color: AppTheme.textPrimary,
                        ),
                      ),
                      const Spacer(),
                      CustomButton(
                        onPressed: () => context.go('/installments/add?investorId=${investor.id}'),
                        text: l10n?.addInstallment ?? 'Добавить рассрочку',
                        icon: Icons.add,
                        showIcon: true,
                        height: 40
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
                        if (installments.isEmpty)
                          Padding(
                            padding: const EdgeInsets.all(24),
                            child: Center(
                              child: Text(l10n?.noInstallments ?? 'Нет рассрочек'),
                            ),
                          )
                        else
                          ...installments.map((installment) {
                            return _buildInstallmentListItem(context, installment);
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
    // For desktop, we put label and value side by side
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 200,
            child: Text(
              label,
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w400,
                color: Colors.grey,
              ),
            ),
          ),
          const SizedBox(width: 32),
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
            flex: 3,
            child: Text(
              l10n?.productNameHeader ?? 'ТОВАР',
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
              l10n?.amountHeader ?? 'СУММА',
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
              l10n?.termHeader ?? 'СРОК',
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
              l10n?.buyingDateHeader ?? 'ДАТА ПОКУПКИ',
              style: Theme.of(context).textTheme.labelMedium?.copyWith(
                    color: AppTheme.textSecondary,
                    fontWeight: FontWeight.w400,
                    fontSize: 12,
                    letterSpacing: 0.5,
                  ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInstallmentListItem(BuildContext context, Installment installment) {
    return InkWell(
      onTap: () => context.go('/installments/${installment.id}'),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        decoration: BoxDecoration(
          border: Border(
            bottom: BorderSide(
              color: AppTheme.borderColor.withOpacity(0.3),
              width: 1,
            ),
          ),
        ),
        child: Row(
          children: [
            Expanded(
              flex: 3,
              child: Text(
                installment.productName,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      fontWeight: FontWeight.w500,
                    ),
              ),
            ),
            Expanded(
              flex: 2,
              child: Text(
                currencyFormat.format(installment.installmentPrice),
                style: Theme.of(context).textTheme.bodyMedium,
              ),
            ),
            Expanded(
              flex: 2,
              child: Text(
                '${installment.termMonths} ${AppLocalizations.of(context)?.months ?? 'месяцев'}',
                style: Theme.of(context).textTheme.bodyMedium,
              ),
            ),
            Expanded(
              flex: 2,
              child: Text(
                dateFormat.format(installment.downPaymentDate),
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: AppTheme.textSecondary,
                    ),
              ),
            ),
          ],
        ),
      ),
    );
  }
} 