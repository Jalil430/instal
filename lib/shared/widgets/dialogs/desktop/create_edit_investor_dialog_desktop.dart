import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/localization/app_localizations.dart';
import '../../../../features/investors/domain/entities/investor.dart';
import '../../../widgets/custom_button.dart';

class CreateEditInvestorDialogDesktop extends StatelessWidget {
  final GlobalKey<FormState> formKey;
  final TextEditingController fullNameController;
  final TextEditingController investmentAmountController;
  final TextEditingController investorPercentageController;
  final TextEditingController userPercentageController;
  final FocusNode fullNameFocus;
  final FocusNode investmentAmountFocus;
  final FocusNode investorPercentageFocus;
  final FocusNode userPercentageFocus;
  final bool isSaving;
  final bool isEditing;
  final VoidCallback onSave;
  
  const CreateEditInvestorDialogDesktop({
    Key? key,
    required this.formKey,
    required this.fullNameController,
    required this.investmentAmountController,
    required this.investorPercentageController,
    required this.userPercentageController,
    required this.fullNameFocus,
    required this.investmentAmountFocus,
    required this.investorPercentageFocus,
    required this.userPercentageFocus,
    required this.isSaving,
    required this.isEditing,
    required this.onSave,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);

    return Dialog(
      backgroundColor: AppTheme.surfaceColor,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
      child: Container(
        width: 500,  // Fixed width for desktop
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
                        ? (l10n?.editInvestor ?? 'Edit Investor')
                        : (l10n?.addInvestor ?? 'Add Investor'),
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
              
              // Form Fields
              _buildTextField(
                context: context,
                controller: fullNameController,
                focusNode: fullNameFocus,
                nextFocusNode: investmentAmountFocus,
                label: l10n?.fullName ?? 'Full Name',
                validator: (value) => value?.isEmpty == true ? l10n?.enterFullName ?? 'Enter full name' : null,
              ),
              const SizedBox(height: 16),
              
              _buildTextField(
                context: context,
                controller: investmentAmountController,
                focusNode: investmentAmountFocus,
                nextFocusNode: investorPercentageFocus,
                label: l10n?.investmentAmount ?? 'Investment Amount',
                keyboardType: TextInputType.number,
                suffix: '₽',
                validator: (value) => _validateNumber(value, l10n?.enterValidInvestmentAmount ?? 'Enter valid investment amount'),
              ),
              const SizedBox(height: 16),
              
              _buildTextField(
                context: context,
                controller: investorPercentageController,
                focusNode: investorPercentageFocus,
                label: l10n?.investorShare ?? 'Investor Share',
                keyboardType: TextInputType.number,
                suffix: '%',
                validator: (value) => _validatePercentage(context, value, l10n?.enterValidInvestorShare ?? 'Enter valid investor share'),
                isLast: true,
                onSubmit: onSave,
              ),
              const SizedBox(height: 16),
              
              _buildTextField(
                context: context,
                controller: userPercentageController,
                focusNode: userPercentageFocus,
                label: l10n?.userShare ?? 'User Share',
                keyboardType: TextInputType.number,
                suffix: '%',
                readOnly: true,
                validator: (value) => _validatePercentage(context, value, l10n?.enterValidUserShare ?? 'Enter valid user share'),
              ),
              const SizedBox(height: 12),
              
              // Helper text
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppTheme.primaryColor.withOpacity(0.05),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  children: [
                    Icon(
                      Icons.info_outline,
                      size: 16,
                      color: AppTheme.primaryColor,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        l10n?.userShareHelperText ?? 'User share is calculated automatically. Total must equal 100%.',
                        style: TextStyle(
                          fontSize: 12,
                          color: AppTheme.textSecondary,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
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
                    text: l10n?.save ?? 'Save',
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
    String? suffix,
    String? Function(String?)? validator,
    bool readOnly = false,
    bool isLast = false,
    VoidCallback? onSubmit,
  }) {
    return TextFormField(
      controller: controller,
      focusNode: focusNode,
      keyboardType: keyboardType,
      readOnly: readOnly,
      textInputAction: isLast ? TextInputAction.done : TextInputAction.next,
      onFieldSubmitted: (_) {
        if (isLast) {
          onSubmit?.call();
        } else if (nextFocusNode != null) {
          nextFocusNode.requestFocus();
        }
      },
      style: TextStyle(
        fontSize: 14,
        fontWeight: FontWeight.w400,
        color: readOnly ? AppTheme.textSecondary : AppTheme.textPrimary,
      ),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: TextStyle(
          color: AppTheme.textSecondary,
          fontSize: 14,
          fontWeight: FontWeight.w400,
        ),
        suffixText: suffix,
        suffixStyle: TextStyle(
          color: AppTheme.textSecondary,
          fontSize: 14,
          fontWeight: FontWeight.w400,
        ),
        filled: true,
        fillColor: readOnly ? AppTheme.subtleBackgroundColor : Colors.white,
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
        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
      ),
      validator: validator,
      inputFormatters: keyboardType == TextInputType.number
          ? [FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d*'))]
          : null,
    );
  }

  String? _validateNumber(String? value, String message) {
    if (value?.isEmpty == true) return message;
    final number = double.tryParse(value!);
    if (number == null || number <= 0) return message;
    return null;
  }

  String? _validatePercentage(BuildContext context, String? value, String message) {
    if (value?.isEmpty == true) return message;
    
    final number = double.tryParse(value!);
    if (number == null || number < 0 || number > 100) {
      return AppLocalizations.of(context)?.percentageValidation ?? 'Percentage must be between 0 and 100';
    }
    
    // Check if percentages add up to 100 when both fields have values
    if (investorPercentageController.text.isNotEmpty && userPercentageController.text.isNotEmpty) {
      final investorPercentage = double.tryParse(investorPercentageController.text) ?? 0;
      final userPercentage = double.tryParse(userPercentageController.text) ?? 0;
      final total = investorPercentage + userPercentage;
      
      if ((total - 100).abs() > 0.1) {
        return AppLocalizations.of(context)?.percentageSumValidation ?? 'Total must equal 100%';
      }
    }
    
    return null;
  }
} 