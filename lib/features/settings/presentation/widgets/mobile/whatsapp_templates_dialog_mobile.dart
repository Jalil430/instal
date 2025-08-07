import 'package:flutter/material.dart';
import '../../../../../core/theme/app_theme.dart';
import '../../../../../core/localization/app_localizations.dart';
import '../../../../../shared/widgets/custom_button.dart';
import '../whatsapp_template_editor.dart';

class WhatsAppTemplatesDialogMobile extends StatelessWidget {
  final GlobalKey<FormState> formKey;
  final TextEditingController template7DaysController;
  final TextEditingController templateDueTodayController;
  final TextEditingController templateManualController;
  final String? errorMessage;
  final bool isSaving;
  final VoidCallback onCancel;
  final VoidCallback onSave;

  const WhatsAppTemplatesDialogMobile({
    super.key,
    required this.formKey,
    required this.template7DaysController,
    required this.templateDueTodayController,
    required this.templateManualController,
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
            // Simple header - more compact for mobile
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
                    Icons.message,
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
                        AppLocalizations.of(context)?.messageTemplates ?? 'Message Templates',
                        style: TextStyle(
                          fontSize: 16, // Smaller for mobile
                          fontWeight: FontWeight.w600,
                          color: AppTheme.textPrimary,
                        ),
                      ),
                      Text(
                        AppLocalizations.of(context)?.customizeMessages ?? 'Customize reminders',
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

            // Template editor
            Flexible(
              child: SingleChildScrollView(
                child: Form(
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
                                    fontSize: 12, // Smaller for mobile
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                      
                      // Direct template editor without card or additional titles
                      WhatsAppTemplateEditor(
                        template7DaysController: template7DaysController,
                        templateDueTodayController: templateDueTodayController,
                        templateManualController: templateManualController,
                      ),
                    ],
                  ),
                ),
              ),
            ),
            const SizedBox(height: 16),

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