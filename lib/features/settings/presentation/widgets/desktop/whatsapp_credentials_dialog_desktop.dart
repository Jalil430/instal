import 'package:flutter/material.dart';
import '../../../../../core/theme/app_theme.dart';
import '../../../../../core/localization/app_localizations.dart';
import '../../../../../shared/widgets/custom_button.dart';
import '../../../../../shared/widgets/custom_text_field.dart';

class WhatsAppCredentialsDialogDesktop extends StatelessWidget {
  final GlobalKey<FormState> formKey;
  final TextEditingController instanceIdController;
  final TextEditingController tokenController;
  final String? errorMessage;
  final bool isSaving;
  final VoidCallback onCancel;
  final VoidCallback onSave;

  const WhatsAppCredentialsDialogDesktop({
    super.key,
    required this.formKey,
    required this.instanceIdController,
    required this.tokenController,
    this.errorMessage,
    required this.isSaving,
    required this.onCancel,
    required this.onSave,
  });

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
      child: Container(
        width: 450,
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Simple header
            Row(
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: const Color(0xFF25D366),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(
                    Icons.key,
                    color: Colors.white,
                    size: 20,
                  ),
                ),
                const SizedBox(width: 16),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      AppLocalizations.of(context)?.updateCredentials ?? 'Update Credentials',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w600,
                        color: AppTheme.textPrimary,
                      ),
                    ),
                    Text(
                      AppLocalizations.of(context)?.updateGreenApiCredentials ?? 'Update your Green API credentials',
                      style: TextStyle(
                        fontSize: 14,
                        color: AppTheme.textSecondary,
                      ),
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 24),

            // Info tip
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.blue.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.info_outline,
                    color: Colors.blue,
                    size: 18,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      AppLocalizations.of(context)?.findCredentialsInfo ?? 'Find your credentials at green-api.com in your instance dashboard',
                      style: TextStyle(
                        fontSize: 13,
                        color: Colors.blue,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),

            // Form
            Form(
              key: formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Error message if present
                  if (errorMessage != null) ...[
                    Container(
                      padding: const EdgeInsets.all(12),
                      margin: const EdgeInsets.only(bottom: 16),
                      decoration: BoxDecoration(
                        color: Colors.red.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Colors.red.withOpacity(0.3)),
                      ),
                      child: Row(
                        children: [
                          const Icon(
                            Icons.error_outline,
                            color: Colors.red,
                            size: 20,
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              errorMessage!,
                              style: const TextStyle(
                                color: Colors.red,
                                fontSize: 14,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                  
                  CustomTextField(
                    controller: instanceIdController,
                    label: AppLocalizations.of(context)?.instanceId ?? 'Instance ID',
                    hintText: AppLocalizations.of(context)?.enterInstanceId ?? 'Enter your Green API instance ID',
                    keyboardType: TextInputType.number,
                    prefixIcon: Icons.tag,
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return AppLocalizations.of(context)?.instanceIdRequired ?? 'Instance ID is required';
                      }
                      if (!RegExp(r'^\d+$').hasMatch(value)) {
                        return AppLocalizations.of(context)?.instanceIdNumeric ?? 'Instance ID must be numeric';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 16),

                  CustomTextField(
                    controller: tokenController,
                    label: AppLocalizations.of(context)?.apiToken ?? 'API Token',
                    hintText: AppLocalizations.of(context)?.enterApiToken ?? 'Enter your Green API token',
                    prefixIcon: Icons.key,
                    obscureText: true,
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return AppLocalizations.of(context)?.apiTokenRequired ?? 'API Token is required';
                      }
                      if (value.length < 10) {
                        return AppLocalizations.of(context)?.apiTokenTooShort ?? 'API Token appears to be too short';
                      }
                      return null;
                    },
                  ),
                ],
              ),
            ),
            const SizedBox(height: 32),

            // Buttons
            Row(
              children: [
                Expanded(
                  flex: 2,
                  child: CustomButton(
                    onPressed: onCancel,
                    text: AppLocalizations.of(context)?.cancel ?? 'Cancel',
                    icon: Icons.close,
                    showIcon: true,
                    color: Colors.white,
                    textColor: AppTheme.textPrimary,
                    height: 44,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  flex: 3,
                  child: CustomButton(
                    onPressed: isSaving ? null : onSave,
                    text: isSaving 
                        ? AppLocalizations.of(context)?.saving ?? 'Saving...' 
                        : AppLocalizations.of(context)?.saveChanges ?? 'Save Changes',
                    icon: isSaving ? Icons.hourglass_empty : Icons.save,
                    showIcon: true,
                    height: 44,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
} 