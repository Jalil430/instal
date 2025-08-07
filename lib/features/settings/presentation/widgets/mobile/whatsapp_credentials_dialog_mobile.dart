import 'package:flutter/material.dart';
import '../../../../../core/theme/app_theme.dart';
import '../../../../../core/localization/app_localizations.dart';
import '../../../../../shared/widgets/custom_button.dart';
import '../../../../../shared/widgets/custom_text_field.dart';

class WhatsAppCredentialsDialogMobile extends StatelessWidget {
  final GlobalKey<FormState> formKey;
  final TextEditingController instanceIdController;
  final TextEditingController tokenController;
  final String? errorMessage;
  final bool isSaving;
  final VoidCallback onCancel;
  final VoidCallback onSave;

  const WhatsAppCredentialsDialogMobile({
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
      // Adjust inset padding for mobile
      insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(16), // Less padding for mobile
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header with close button
            Row(
              children: [
                Container(
                  width: 36, // Smaller for mobile
                  height: 36,
                  decoration: BoxDecoration(
                    color: const Color(0xFF25D366),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(
                    Icons.key,
                    color: Colors.white,
                    size: 18,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        AppLocalizations.of(context)?.updateCredentials ?? 'Update Credentials',
                        style: TextStyle(
                          fontSize: 16, // Smaller for mobile
                          fontWeight: FontWeight.w600,
                          color: AppTheme.textPrimary,
                        ),
                      ),
                      Text(
                        AppLocalizations.of(context)?.updateGreenApiCredentials ?? 'Update API credentials',
                        style: TextStyle(
                          fontSize: 12, // Smaller for mobile
                          color: AppTheme.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
                // Close button in header for mobile
                IconButton(
                  icon: const Icon(Icons.close, size: 20),
                  onPressed: onCancel,
                  style: IconButton.styleFrom(
                    padding: const EdgeInsets.all(8),
                    foregroundColor: AppTheme.textSecondary,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // Info tip - more compact for mobile
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: Colors.blue.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.info_outline,
                    color: Colors.blue,
                    size: 16,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      AppLocalizations.of(context)?.findCredentialsInfo ?? 'Find credentials at green-api.com',
                      style: TextStyle(
                        fontSize: 12, // Smaller for mobile
                        color: Colors.blue,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // Form
            Form(
              key: formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Error message if present
                  if (errorMessage != null) ...[
                    Container(
                      padding: const EdgeInsets.all(10),
                      margin: const EdgeInsets.only(bottom: 16),
                      decoration: BoxDecoration(
                        color: Colors.red.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Colors.red.withOpacity(0.3)),
                      ),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Icon(
                            Icons.error_outline,
                            color: Colors.red,
                            size: 16,
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              errorMessage!,
                              style: const TextStyle(
                                color: Colors.red,
                                fontSize: 12,
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
                    hintText: AppLocalizations.of(context)?.enterInstanceId ?? 'Enter Green API instance ID',
                    keyboardType: TextInputType.number,
                    prefixIcon: Icons.tag,
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return AppLocalizations.of(context)?.instanceIdRequired ?? 'Instance ID required';
                      }
                      if (!RegExp(r'^\d+$').hasMatch(value)) {
                        return AppLocalizations.of(context)?.instanceIdNumeric ?? 'Must be numeric';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 16),

                  CustomTextField(
                    controller: tokenController,
                    label: AppLocalizations.of(context)?.apiToken ?? 'API Token',
                    hintText: AppLocalizations.of(context)?.enterApiToken ?? 'Enter Green API token',
                    prefixIcon: Icons.key,
                    obscureText: true,
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return AppLocalizations.of(context)?.apiTokenRequired ?? 'API Token required';
                      }
                      if (value.length < 10) {
                        return AppLocalizations.of(context)?.apiTokenTooShort ?? 'Token too short';
                      }
                      return null;
                    },
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),

            // Single save button for mobile (cancel button is in header)
            CustomButton(
              onPressed: isSaving ? null : onSave,
              text: isSaving 
                  ? AppLocalizations.of(context)?.saving ?? 'Saving...' 
                  : AppLocalizations.of(context)?.saveChanges ?? 'Save Changes',
              icon: isSaving ? Icons.hourglass_empty : Icons.save,
              showIcon: true,
              height: 44,
              width: double.infinity,
            ),
          ],
        ),
      ),
    );
  }
} 