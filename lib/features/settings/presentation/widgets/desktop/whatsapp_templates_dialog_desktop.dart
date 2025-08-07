import 'package:flutter/material.dart';
import '../../../../../core/theme/app_theme.dart';
import '../../../../../core/localization/app_localizations.dart';
import '../../../../../shared/widgets/custom_button.dart';
import '../whatsapp_template_editor.dart';

class WhatsAppTemplatesDialogDesktop extends StatelessWidget {
  final GlobalKey<FormState> formKey;
  final TextEditingController template7DaysController;
  final TextEditingController templateDueTodayController;
  final TextEditingController templateManualController;
  final String? errorMessage;
  final bool isSaving;
  final VoidCallback onCancel;
  final VoidCallback onSave;

  const WhatsAppTemplatesDialogDesktop({
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
      child: Container(
        width: 600,
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
                    Icons.message,
                    color: Colors.white,
                    size: 20,
                  ),
                ),
                const SizedBox(width: 16),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      AppLocalizations.of(context)?.messageTemplates ?? 'Message Templates',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w600,
                        color: AppTheme.textPrimary,
                      ),
                    ),
                    Text(
                      AppLocalizations.of(context)?.customizeMessages ?? 'Customize your WhatsApp reminder messages',
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
            const SizedBox(height: 24),

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