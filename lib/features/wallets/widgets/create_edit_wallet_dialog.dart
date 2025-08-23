import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/localization/app_localizations.dart';
import '../domain/entities/wallet.dart';
import '../../../shared/widgets/custom_text_field.dart';
import '../../../shared/widgets/custom_button.dart';
import '../../../shared/widgets/custom_confirmation_dialog.dart';

class CreateEditWalletDialog extends StatefulWidget {
  final Wallet? wallet;
  final VoidCallback onSuccess;

  const CreateEditWalletDialog({
    super.key,
    this.wallet,
    required this.onSuccess,
  });

  @override
  State<CreateEditWalletDialog> createState() => _CreateEditWalletDialogState();
}

class _CreateEditWalletDialogState extends State<CreateEditWalletDialog> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _investmentAmountController = TextEditingController();
  final _investorPercentageController = TextEditingController();
  final _userPercentageController = TextEditingController();

  WalletType _selectedType = WalletType.personal;
  DateTime? _returnDate;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    if (widget.wallet != null) {
      _nameController.text = widget.wallet!.name;
      _selectedType = widget.wallet!.type;
      if (widget.wallet!.isInvestorWallet) {
        _investmentAmountController.text = widget.wallet!.investmentAmount?.toString() ?? '';
        _investorPercentageController.text = widget.wallet!.investorPercentage?.toString() ?? '';
        _userPercentageController.text = widget.wallet!.userPercentage?.toString() ?? '';
        _returnDate = widget.wallet!.investmentReturnDate;
      }
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _investmentAmountController.dispose();
    _investorPercentageController.dispose();
    _userPercentageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final isEditing = widget.wallet != null;

    return Dialog(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppTheme.borderRadiusLg),
      ),
      child: Container(
        width: MediaQuery.of(context).size.width * 0.9,
        constraints: const BoxConstraints(maxWidth: 500),
        padding: const EdgeInsets.all(AppTheme.spacingLg),
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header
              Row(
                children: [
                  Icon(
                    isEditing ? Icons.edit : Icons.add,
                    color: AppTheme.primaryColor,
                    size: 28,
                  ),
                  const SizedBox(width: AppTheme.spacingMd),
                  Text(
                    isEditing ? 'Редактировать кошелек' : 'Создать кошелек',
                    style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const Spacer(),
                  IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ],
              ),
              const SizedBox(height: AppTheme.spacingLg),

              // Wallet type selection
              Text(
                'Тип кошелька',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: AppTheme.textPrimary,
                ),
              ),
              const SizedBox(height: AppTheme.spacingMd),
              Row(
                children: [
                  Expanded(
                    child: _buildTypeOption(
                      type: WalletType.personal,
                      title: 'Личный кошелек',
                      description: 'Для ваших личных средств',
                      icon: Icons.account_balance_wallet,
                    ),
                  ),
                  const SizedBox(width: AppTheme.spacingMd),
                  Expanded(
                    child: _buildTypeOption(
                      type: WalletType.investor,
                      title: 'Инвестор',
                      description: 'Для инвестиций с доходом',
                      icon: Icons.trending_up,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: AppTheme.spacingLg),

              // Basic fields
              CustomTextField(
                controller: _nameController,
                label: 'Название кошелька',
                hintText: 'Введите название',
                validator: (value) {
                  if (value?.isEmpty ?? true) {
                    return 'Название обязательно';
                  }
                  return null;
                },
              ),
              const SizedBox(height: AppTheme.spacingMd),

              // Investor-specific fields
              if (_selectedType == WalletType.investor) ...[
                CustomTextField(
                  controller: _investmentAmountController,
                  label: 'Сумма инвестиции (₽)',
                  hintText: '1000000',
                  keyboardType: TextInputType.number,
                  validator: (value) {
                    if (value?.isEmpty ?? true) {
                      return 'Сумма инвестиции обязательна';
                    }
                    final amount = double.tryParse(value!);
                    if (amount == null || amount <= 0) {
                      return 'Введите корректную сумму';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: AppTheme.spacingMd),

                Row(
                  children: [
                    Expanded(
                      child: CustomTextField(
                        controller: _investorPercentageController,
                        label: 'Процент инвестора (%)',
                        hintText: '70',
                        keyboardType: TextInputType.number,
                        validator: (value) {
                          if (value?.isEmpty ?? true) {
                            return 'Процент обязателен';
                          }
                          final percent = double.tryParse(value!);
                          if (percent == null || percent < 0 || percent > 100) {
                            return '0-100';
                          }
                          return null;
                        },
                      ),
                    ),
                    const SizedBox(width: AppTheme.spacingMd),
                    Expanded(
                      child: CustomTextField(
                        controller: _userPercentageController,
                        label: 'Ваш процент (%)',
                        hintText: '30',
                        keyboardType: TextInputType.number,
                        validator: (value) {
                          if (value?.isEmpty ?? true) {
                            return 'Процент обязателен';
                          }
                          final percent = double.tryParse(value!);
                          if (percent == null || percent < 0 || percent > 100) {
                            return '0-100';
                          }
                          final investorPercent = double.tryParse(_investorPercentageController.text);
                          if (investorPercent != null && percent != null) {
                            if ((investorPercent + percent) != 100) {
                              return 'Сумма должна быть 100%';
                            }
                          }
                          return null;
                        },
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: AppTheme.spacingMd),

                // Return date picker
                InkWell(
                  onTap: _selectReturnDate,
                  child: Container(
                    padding: const EdgeInsets.all(AppTheme.spacingMd),
                    decoration: BoxDecoration(
                      border: Border.all(color: AppTheme.borderColor),
                      borderRadius: BorderRadius.circular(AppTheme.borderRadiusMedium),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.calendar_today, color: AppTheme.textSecondary),
                        const SizedBox(width: AppTheme.spacingMd),
                        Expanded(
                          child: Text(
                            _returnDate != null
                                ? DateFormat('dd.MM.yyyy').format(_returnDate!)
                                : 'Выберите дату возврата инвестиции',
                            style: TextStyle(
                              color: _returnDate != null ? AppTheme.textPrimary : AppTheme.textSecondary,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],

              const SizedBox(height: AppTheme.spacingLg),

              // Action buttons
              Row(
                children: [
                  Expanded(
                    child: CustomButton(
                      text: l10n?.cancel ?? 'Отмена',
                      onPressed: () => Navigator.of(context).pop(),
                      color: AppTheme.primaryColor.withOpacity(0.1),
                      textColor: AppTheme.primaryColor,
                    ),
                  ),
                  const SizedBox(width: AppTheme.spacingMd),
                  Expanded(
                    child: CustomButton(
                      text: isEditing ? 'Сохранить' : 'Создать',
                      onPressed: _saveWallet,
                      color: AppTheme.primaryColor,
                      textColor: Colors.white,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTypeOption({
    required WalletType type,
    required String title,
    required String description,
    required IconData icon,
  }) {
    final isSelected = _selectedType == type;

    return InkWell(
      onTap: () => setState(() => _selectedType = type),
      child: Container(
        padding: const EdgeInsets.all(AppTheme.spacingMd),
        decoration: BoxDecoration(
          border: Border.all(
            color: isSelected ? AppTheme.primaryColor : AppTheme.borderColor,
            width: isSelected ? 2 : 1,
          ),
          borderRadius: BorderRadius.circular(AppTheme.borderRadiusMedium),
          color: isSelected ? AppTheme.primaryColor.withOpacity(0.05) : Colors.transparent,
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

  Future<void> _selectReturnDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _returnDate ?? DateTime.now().add(const Duration(days: 365)),
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 365 * 10)),
    );

    if (picked != null) {
      setState(() => _returnDate = picked);
    }
  }

  Future<void> _saveWallet() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    try {
      // TODO: Implement actual save logic with repository
      await Future.delayed(const Duration(seconds: 1)); // Mock delay

      if (mounted) {
        Navigator.of(context).pop();
        widget.onSuccess();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Ошибка: $e'),
            backgroundColor: AppTheme.errorColor,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }
}
