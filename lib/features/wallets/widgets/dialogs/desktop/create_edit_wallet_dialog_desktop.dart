import 'package:flutter/material.dart';

import '../../../../../core/theme/app_theme.dart';
import '../../../../../core/localization/app_localizations.dart';
import '../../../domain/entities/wallet.dart';

import '../../../../../shared/widgets/custom_button.dart';

class CreateEditWalletDialogDesktop extends StatelessWidget {
  final GlobalKey<FormState> formKey;
  final TextEditingController nameController;
  final TextEditingController investmentAmountController;
  final TextEditingController investorPercentageController;
  final TextEditingController userPercentageController;
  final FocusNode nameFocus;
  final FocusNode investmentAmountFocus;
  final FocusNode investorPercentageFocus;
  final FocusNode userPercentageFocus;
  final WalletType selectedType;
  final DateTime? returnDate;
  final bool isSaving;
  final bool isEditing;
  final ValueChanged<WalletType> onTypeChanged;
  final ValueChanged<DateTime?> onReturnDateChanged;
  final VoidCallback onSave;

  const CreateEditWalletDialogDesktop({
    Key? key,
    required this.formKey,
    required this.nameController,
    required this.investmentAmountController,
    required this.investorPercentageController,
    required this.userPercentageController,
    required this.nameFocus,
    required this.investmentAmountFocus,
    required this.investorPercentageFocus,
    required this.userPercentageFocus,
    required this.selectedType,
    required this.returnDate,
    required this.isSaving,
    required this.isEditing,
    required this.onTypeChanged,
    required this.onReturnDateChanged,
    required this.onSave,
  }) : super(key: key);



  Widget _buildDateField({
    required BuildContext context,
    required String label,
    required DateTime? value,
    required Function(DateTime) onChanged,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
            color: AppTheme.textSecondary,
            fontSize: 14,
            fontWeight: FontWeight.w400,
          ),
        ),
        const SizedBox(height: 8),
        InkWell(
          onTap: () async {
            final date = await showDatePicker(
              context: context,
              initialDate: value ?? DateTime.now(),
              firstDate: DateTime(2020),
              lastDate: DateTime(2030),
            );
            if (date != null) {
              onChanged(date);
            }
          },
          child: Container(
            width: double.infinity,
            height: 44,
            padding: const EdgeInsets.symmetric(horizontal: 12),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: AppTheme.borderColor),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    value != null
                        ? '${value.day.toString().padLeft(2, '0')}.${value.month.toString().padLeft(2, '0')}.${value.year}'
                        : AppLocalizations.of(context)?.selectDate ?? 'Select date',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w400,
                      color: value != null ? AppTheme.textPrimary : AppTheme.textSecondary,
                    ),
                  ),
                ),
                Icon(
                  Icons.calendar_today,
                  color: AppTheme.textSecondary,
                  size: 18,
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildTypeOption({
    required WalletType type,
    required String title,
    required String description,
    required IconData icon,
  }) {
    final isSelected = selectedType == type;

    return InkWell(
      onTap: () => onTypeChanged(type),
      child: Container(
        padding: const EdgeInsets.all(AppTheme.spacingMd),
        decoration: BoxDecoration(
          border: Border.all(
            color: isSelected ? AppTheme.primaryColor : AppTheme.borderColor,
            width: isSelected ? 2 : 1,
          ),
          borderRadius: BorderRadius.circular(AppTheme.borderRadiusMedium),
          color: isSelected ? AppTheme.primaryColor.withValues(alpha: 0.05) : Colors.transparent,
        ),
        child: Column(
          children: [
            Icon(
              icon,
              color: isSelected ? AppTheme.primaryColor : AppTheme.textSecondary,
              size: 32,
            ),
            const SizedBox(height: AppTheme.spacingSm),
            Text(
              title,
              style: TextStyle(
                fontWeight: FontWeight.w600,
                color: isSelected ? AppTheme.primaryColor : AppTheme.textPrimary,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              description,
              style: TextStyle(
                fontSize: 12,
                color: AppTheme.textSecondary,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);

    return Dialog(
      backgroundColor: AppTheme.surfaceColor,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
      child: Container(
        width: 500,  // Fixed width for desktop like client dialog
        padding: const EdgeInsets.all(24),
        child: Form(
          key: formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header
              Row(
                children: [
                  Text(
                    isEditing
                        ? (l10n?.editInvestor ?? 'Редактировать кошелек')
                        : (l10n?.createWallet ?? 'Создать кошелек'),
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const Spacer(),
                  IconButton(
                    onPressed: () => Navigator.of(context).pop(),
                    icon: const Icon(Icons.close),
                    style: IconButton.styleFrom(
                      backgroundColor: AppTheme.subtleBackgroundColor,
                      foregroundColor: AppTheme.textSecondary,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 24),
              // Wallet type selection
              Text(
                l10n?.walletType ?? 'Тип кошелька',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: AppTheme.textPrimary,
                ),
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: _buildTypeOption(
                      type: WalletType.personal,
                      title: l10n?.personal ?? 'Личный',
                      description: l10n?.personalWalletDescription ?? 'Для ваших личных средств',
                      icon: Icons.account_balance_wallet,
                    ),
                  ),
                  const SizedBox(width: AppTheme.spacingMd),
                  Expanded(
                    child: _buildTypeOption(
                      type: WalletType.investor,
                      title: l10n?.investor ?? 'Инвестор',
                      description: l10n?.investorWalletDescription ?? 'Для инвестиций с доходом',
                      icon: Icons.trending_up,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: AppTheme.spacingLg),

              // Basic fields
              _buildTextField(
                context: context,
                controller: nameController,
                focusNode: nameFocus,
                nextFocusNode: selectedType == WalletType.investor ? investmentAmountFocus : null,
                label: l10n?.walletName ?? 'Название кошелька',
                validator: (value) {
                  if (value?.isEmpty ?? true) {
                    return l10n?.nameRequired ?? 'Название обязательно';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),

              // Investor-specific fields
              if (selectedType == WalletType.investor) ...[
                _buildTextField(
                  context: context,
                  controller: investmentAmountController,
                  focusNode: investmentAmountFocus,
                  nextFocusNode: investorPercentageFocus,
                  label: l10n?.investmentAmount ?? 'Сумма инвестиции (₽)',
                  keyboardType: TextInputType.number,
                  validator: (value) {
                    if (value?.isEmpty ?? true) {
                      return l10n?.investmentAmountRequired ?? 'Сумма инвестиции обязательна';
                    }
                    final amount = double.tryParse(value!);
                    if (amount == null || amount <= 0) {
                      return l10n?.enterValidAmount ?? 'Введите корректную сумму';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 16),

                Row(
                  children: [
                    Expanded(
                      child: _buildTextField(
                        context: context,
                        controller: investorPercentageController,
                        focusNode: investorPercentageFocus,
                        nextFocusNode: userPercentageFocus,
                        label: l10n?.investorPercentage ?? 'Процент инвестора (%)',
                        keyboardType: TextInputType.number,
                        validator: (value) {
                          if (value?.isEmpty ?? true) {
                            return l10n?.percentageRequired ?? 'Процент обязателен';
                          }
                          final percent = double.tryParse(value!);
                          if (percent == null || percent < 0 || percent > 100) {
                            return l10n?.percentageRange ?? '0-100';
                          }
                          return null;
                        },
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _buildTextField(
                        context: context,
                        controller: userPercentageController,
                        focusNode: userPercentageFocus,
                        label: l10n?.yourPercentage ?? 'Ваш процент (%)',
                        keyboardType: TextInputType.number,
                        validator: (value) {
                          if (value?.isEmpty ?? true) {
                            return l10n?.percentageRequired ?? 'Процент обязателен';
                          }
                          final percent = double.tryParse(value!);
                          if (percent == null || percent < 0 || percent > 100) {
                            return l10n?.percentageRange ?? '0-100';
                          }
                          final investorPercent = double.tryParse(investorPercentageController.text);
                          if (investorPercent != null && percent != null) {
                            if ((investorPercent + percent) != 100) {
                              return l10n?.percentageSum100 ?? 'Сумма должна быть 100%';
                            }
                          }
                          return null;
                        },
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),

                // Return date picker
                _buildDateField(
                  context: context,
                  label: l10n?.investmentReturnDate ?? 'Дата возврата инвестиции',
                  value: returnDate,
                  onChanged: onReturnDateChanged,
                ),
              ],

              const SizedBox(height: 24),

              // Actions
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: isSaving ? null : () => Navigator.of(context).pop(),
                    child: Text(
                      l10n?.cancel ?? 'Cancel',
                      style: TextStyle(color: AppTheme.textSecondary),
                    ),
                  ),
                  const SizedBox(width: 12),
                  CustomButton(
                    text: isSaving
                        ? (l10n?.creating ?? 'Создание...')
                        : (isEditing ? (l10n?.save ?? 'Сохранить') : (l10n?.create ?? 'Создать')),
                    onPressed: isSaving ? null : onSave,
                    showIcon: false,
                    width: 120,
                    height: 40,
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTextField({
    required BuildContext context,
    required TextEditingController controller,
    required FocusNode focusNode,
    FocusNode? nextFocusNode,
    required String label,
    TextInputType? keyboardType,
    String? Function(String?)? validator,
    bool isLast = false,
    VoidCallback? onSubmit,
  }) {
    return TextFormField(
      controller: controller,
      focusNode: focusNode,
      keyboardType: keyboardType,
      textInputAction: isLast ? TextInputAction.done : TextInputAction.next,
      onFieldSubmitted: (_) {
        if (isLast) {
          onSubmit?.call();
        } else if (nextFocusNode != null) {
          nextFocusNode.requestFocus();
        }
      },
      style: const TextStyle(
        fontSize: 14,
        fontWeight: FontWeight.w400,
      ),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: TextStyle(
          color: AppTheme.textSecondary,
          fontSize: 14,
          fontWeight: FontWeight.w400,
        ),
        filled: true,
        fillColor: Colors.white,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: BorderSide(color: AppTheme.borderColor),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: BorderSide(color: AppTheme.borderColor),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: BorderSide(color: AppTheme.primaryColor, width: 2),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: BorderSide(color: AppTheme.errorColor),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: BorderSide(color: AppTheme.errorColor, width: 2),
        ),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      ),
      validator: validator,
    );
  }
}
