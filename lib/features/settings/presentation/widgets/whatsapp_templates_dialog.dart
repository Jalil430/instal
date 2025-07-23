import 'package:flutter/material.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/localization/app_localizations.dart';
import '../../../../shared/widgets/custom_button.dart';
import '../../../settings/data/services/whatsapp_api_service.dart';
import 'whatsapp_template_editor.dart';

class WhatsAppTemplatesDialog extends StatefulWidget {
  final String initialTemplate7Days;
  final String initialTemplateDueToday;
  final String initialTemplateManual;
  final VoidCallback onSaved;

  const WhatsAppTemplatesDialog({
    super.key,
    required this.initialTemplate7Days,
    required this.initialTemplateDueToday,
    required this.initialTemplateManual,
    required this.onSaved,
  });

  @override
  State<WhatsAppTemplatesDialog> createState() => _WhatsAppTemplatesDialogState();
}

class _WhatsAppTemplatesDialogState extends State<WhatsAppTemplatesDialog> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _template7DaysController;
  late final TextEditingController _templateDueTodayController;
  late final TextEditingController _templateManualController;
  
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _template7DaysController = TextEditingController(text: widget.initialTemplate7Days);
    _templateDueTodayController = TextEditingController(text: widget.initialTemplateDueToday);
    _templateManualController = TextEditingController(text: widget.initialTemplateManual);
  }

  @override
  void dispose() {
    _template7DaysController.dispose();
    _templateDueTodayController.dispose();
    _templateManualController.dispose();
    super.dispose();
  }

  // Error state
  String? _errorMessage;

  Future<void> _saveTemplates() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isSaving = true;
      _errorMessage = null;
    });

    try {
      // First get current settings to preserve existing values
      final currentSettings = await WhatsAppApiService.getSettings();
      
      // Update only the template fields while preserving other settings
      await WhatsAppApiService.updateSettings(
        // Preserve existing credentials
        greenApiInstanceId: currentSettings['green_api_instance_id'],
        greenApiToken: currentSettings['green_api_token'],
        // Update templates
        reminderTemplate7Days: _template7DaysController.text.trim(),
        reminderTemplateDueToday: _templateDueTodayController.text.trim(),
        reminderTemplateManual: _templateManualController.text.trim(),
        // Preserve enabled status
        isEnabled: currentSettings['is_enabled'],
      );

      setState(() {
        _isSaving = false;
      });

      // Show success message in dialog and then close it
      _showSuccessSnackBar(AppLocalizations.of(context)?.templatesUpdated ?? 'Templates updated successfully!');
      Navigator.of(context).pop();
      widget.onSaved();
      
    } catch (e) {
      // Show error message in the dialog
      setState(() {
        _isSaving = false;
        _errorMessage = '${AppLocalizations.of(context)?.failedToSaveTemplates ?? 'Failed to save templates'}: $e';
      });
    }
  }

  void _showSuccessSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: AppTheme.successColor,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

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
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Error message if present
                      if (_errorMessage != null) ...[
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
                                  _errorMessage!,
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
                        template7DaysController: _template7DaysController,
                        templateDueTodayController: _templateDueTodayController,
                        templateManualController: _templateManualController,
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
                    onPressed: () => Navigator.of(context).pop(),
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
                    onPressed: _isSaving ? null : _saveTemplates,
                    text: _isSaving 
                        ? AppLocalizations.of(context)?.saving ?? 'Saving...' 
                        : AppLocalizations.of(context)?.saveChanges ?? 'Save Changes',
                    icon: _isSaving ? Icons.hourglass_empty : Icons.save,
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