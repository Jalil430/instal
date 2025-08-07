import 'package:flutter/material.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/localization/app_localizations.dart';
import '../../../../features/clients/domain/entities/client.dart';
import '../../../widgets/custom_button.dart';

class CreateEditClientDialogMobile extends StatelessWidget {
  final GlobalKey<FormState> formKey;
  final TextEditingController fullNameController;
  final TextEditingController contactNumberController;
  final TextEditingController passportNumberController;
  final TextEditingController addressController;
  final FocusNode fullNameFocus;
  final FocusNode contactNumberFocus;
  final FocusNode passportNumberFocus;
  final FocusNode addressFocus;
  final bool isSaving;
  final bool isEditing;
  final VoidCallback onSave;
  
  const CreateEditClientDialogMobile({
    Key? key,
    required this.formKey,
    required this.fullNameController,
    required this.contactNumberController,
    required this.passportNumberController,
    required this.addressController,
    required this.fullNameFocus,
    required this.contactNumberFocus,
    required this.passportNumberFocus,
    required this.addressFocus,
    required this.isSaving,
    required this.isEditing,
    required this.onSave,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final mediaQuery = MediaQuery.of(context);
    final screenWidth = mediaQuery.size.width;
    
    return Dialog(
      backgroundColor: AppTheme.surfaceColor,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
      // Take up most of the screen width on mobile
      child: Container(
        width: screenWidth * 0.9,
        padding: const EdgeInsets.all(20),
        child: Form(
          key: formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header
              Row(
                children: [
                  Expanded(
                    child: Text(
                      isEditing 
                          ? (l10n?.editClient ?? 'Edit Client')
                          : (l10n?.addClient ?? 'Add Client'),
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
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
              const SizedBox(height: 20),
              
              // Form Fields - Stacked layout for mobile
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
                validator: (value) => value?.isEmpty == true ? l10n?.enterContactNumber ?? 'Enter contact number' : null,
              ),
              const SizedBox(height: 16),
              
              _buildTextField(
                context: context,
                controller: passportNumberController,
                focusNode: passportNumberFocus,
                nextFocusNode: addressFocus,
                label: l10n?.passportNumber ?? 'Passport Number',
                validator: (value) => value?.isEmpty == true ? l10n?.enterPassportNumber ?? 'Enter passport number' : null,
              ),
              const SizedBox(height: 16),
              
              _buildTextField(
                context: context,
                controller: addressController,
                focusNode: addressFocus,
                label: l10n?.address ?? 'Address (Optional)',
                isLast: true,
                onSubmit: onSave,
              ),
              const SizedBox(height: 24),
              
              // Actions - Full width buttons for mobile
              Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  CustomButton(
                    text: l10n?.save ?? 'Save',
                    onPressed: isSaving ? null : onSave,
                    showIcon: false,
                    height: 48,
                  ),
                  const SizedBox(height: 12),
                  TextButton(
                    onPressed: isSaving ? null : () => Navigator.of(context).pop(),
                    child: Text(
                      l10n?.cancel ?? 'Cancel',
                      style: TextStyle(color: AppTheme.textSecondary),
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