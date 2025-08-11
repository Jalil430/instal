import 'package:flutter/material.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/localization/app_localizations.dart';
import '../../../../features/clients/domain/entities/client.dart';
import '../../../widgets/custom_button.dart';

class CreateEditClientDialogDesktop extends StatelessWidget {
  final GlobalKey<FormState> formKey;
  final TextEditingController fullNameController;
  final TextEditingController contactNumberController;
  final TextEditingController passportNumberController;
  final TextEditingController addressController;
  final TextEditingController guarantorFullNameController;
  final TextEditingController guarantorContactNumberController;
  final TextEditingController guarantorPassportNumberController;
  final TextEditingController guarantorAddressController;
  final FocusNode fullNameFocus;
  final FocusNode contactNumberFocus;
  final FocusNode passportNumberFocus;
  final FocusNode addressFocus;
  final FocusNode guarantorFullNameFocus;
  final FocusNode guarantorContactNumberFocus;
  final FocusNode guarantorPassportNumberFocus;
  final FocusNode guarantorAddressFocus;
  final bool isSaving;
  final bool isEditing;
  final VoidCallback onSave;
  
  const CreateEditClientDialogDesktop({
    Key? key,
    required this.formKey,
    required this.fullNameController,
    required this.contactNumberController,
    required this.passportNumberController,
    required this.addressController,
    required this.guarantorFullNameController,
    required this.guarantorContactNumberController,
    required this.guarantorPassportNumberController,
    required this.guarantorAddressController,
    required this.fullNameFocus,
    required this.contactNumberFocus,
    required this.passportNumberFocus,
    required this.addressFocus,
    required this.guarantorFullNameFocus,
    required this.guarantorContactNumberFocus,
    required this.guarantorPassportNumberFocus,
    required this.guarantorAddressFocus,
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
                        ? (l10n?.editClient ?? 'Edit Client')
                        : (l10n?.addClient ?? 'Add Client'),
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
                nextFocusNode: contactNumberFocus,
                label: l10n?.fullName ?? 'Full Name',
                validator: (value) => value?.isEmpty == true ? l10n?.enterFullName ?? 'Enter full name' : null,
              ),
              const SizedBox(height: 16),
              
              _buildTextField(
                context: context,
                controller: contactNumberController,
                focusNode: contactNumberFocus,
                nextFocusNode: passportNumberFocus,
                label: l10n?.contactNumber ?? 'Contact Number',
                keyboardType: TextInputType.phone,
                // Optional field; no validator
                validator: null,
              ),
              const SizedBox(height: 16),
              
              _buildTextField(
                context: context,
                controller: passportNumberController,
                focusNode: passportNumberFocus,
                nextFocusNode: addressFocus,
                label: l10n?.passportNumber ?? 'Passport Number',
                // Optional field; no validator
                validator: null,
              ),
              const SizedBox(height: 16),
              
              _buildTextField(
                context: context,
                controller: addressController,
                focusNode: addressFocus,
                label: l10n?.address ?? 'Address (Optional)',
                nextFocusNode: guarantorFullNameFocus,
              ),
              const SizedBox(height: 16),

              // Guarantor fields
              _buildTextField(
                context: context,
                controller: guarantorFullNameController,
                focusNode: guarantorFullNameFocus,
                nextFocusNode: guarantorContactNumberFocus,
                label: l10n?.guarantorFullName ?? 'Guarantor Full Name (Optional)',
              ),
              const SizedBox(height: 16),
              _buildTextField(
                context: context,
                controller: guarantorContactNumberController,
                focusNode: guarantorContactNumberFocus,
                nextFocusNode: guarantorPassportNumberFocus,
                label: l10n?.guarantorContactNumber ?? 'Guarantor Contact Number (Optional)',
                keyboardType: TextInputType.phone,
              ),
              const SizedBox(height: 16),
              _buildTextField(
                context: context,
                controller: guarantorPassportNumberController,
                focusNode: guarantorPassportNumberFocus,
                nextFocusNode: guarantorAddressFocus,
                label: l10n?.guarantorPassportNumber ?? 'Guarantor Passport Number (Optional)',
              ),
              const SizedBox(height: 16),
              _buildTextField(
                context: context,
                controller: guarantorAddressController,
                focusNode: guarantorAddressFocus,
                label: l10n?.guarantorAddress ?? 'Guarantor Address (Optional)',
                isLast: true,
                onSubmit: onSave,
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
        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
      ),
      validator: validator,
    );
  }
} 