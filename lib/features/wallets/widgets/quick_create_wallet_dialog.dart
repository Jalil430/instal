import 'package:flutter/material.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/localization/app_localizations.dart';
import '../domain/entities/wallet.dart';
import '../../../shared/widgets/custom_text_field.dart';
import '../../../shared/widgets/custom_button.dart';
import '../../../shared/widgets/custom_confirmation_dialog.dart';

class QuickCreateWalletDialog extends StatefulWidget {
  final Function(String, WalletType) onWalletCreated;

  const QuickCreateWalletDialog({
    super.key,
    required this.onWalletCreated,
  });

  @override
  State<QuickCreateWalletDialog> createState() => _QuickCreateWalletDialogState();
}

class _QuickCreateWalletDialogState extends State<QuickCreateWalletDialog> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  WalletType _selectedType = WalletType.personal;

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);

    return Dialog(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppTheme.borderRadiusLg),
      ),
      child: Container(
        width: 400,
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
                  const Icon(
                    Icons.add,
                    color: AppTheme.primaryColor,
                    size: 28,
                  ),
                  const SizedBox(width: AppTheme.spacingMd),
                  Text(
                    'Быстрое создание кошелька',
                    style: const TextStyle(
                      fontSize: 18,
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
                  fontSize: 14,
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
                      title: 'Личный',
                      isSelected: _selectedType == WalletType.personal,
                    ),
                  ),
                  const SizedBox(width: AppTheme.spacingMd),
                  Expanded(
                    child: _buildTypeOption(
                      type: WalletType.investor,
                      title: 'Инвестор',
                      isSelected: _selectedType == WalletType.investor,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: AppTheme.spacingLg),

              // Wallet name
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
                      text: 'Создать',
                      onPressed: _createWallet,
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
    required bool isSelected,
  }) {
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
              type == WalletType.personal ? Icons.account_balance_wallet : Icons.trending_up,
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
          ],
        ),
      ),
    );
  }

  Future<void> _createWallet() async {
    if (!_formKey.currentState!.validate()) return;

    // TODO: Implement actual wallet creation
    // For now, just return the data to be handled by the parent
    widget.onWalletCreated(_nameController.text, _selectedType);
    Navigator.of(context).pop();
  }
}
