import 'package:flutter/material.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/localization/app_localizations.dart';
import '../../../../shared/widgets/responsive_layout.dart';
import '../../../settings/data/services/whatsapp_api_service.dart';
import 'desktop/whatsapp_templates_dialog_desktop.dart';
import 'mobile/whatsapp_templates_dialog_mobile.dart';

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

  void _handleCancel() {
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    return ResponsiveLayout(
      desktop: WhatsAppTemplatesDialogDesktop(
        formKey: _formKey,
        template7DaysController: _template7DaysController,
        templateDueTodayController: _templateDueTodayController,
        templateManualController: _templateManualController,
        errorMessage: _errorMessage,
        isSaving: _isSaving,
        onCancel: _handleCancel,
        onSave: _saveTemplates,
      ),
      mobile: WhatsAppTemplatesDialogMobile(
        formKey: _formKey,
        template7DaysController: _template7DaysController,
        templateDueTodayController: _templateDueTodayController,
        templateManualController: _templateManualController,
        errorMessage: _errorMessage,
        isSaving: _isSaving,
        onCancel: _handleCancel,
        onSave: _saveTemplates,
      ),
    );
  }
}