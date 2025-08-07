import 'package:flutter/material.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/localization/app_localizations.dart';
import '../../../../shared/widgets/responsive_layout.dart';
import '../../../settings/data/services/whatsapp_api_service.dart';
import 'desktop/whatsapp_credentials_dialog_desktop.dart';
import 'mobile/whatsapp_credentials_dialog_mobile.dart';

class WhatsAppCredentialsDialog extends StatefulWidget {
  final String initialInstanceId;
  final String initialToken;
  final VoidCallback onSaved;

  const WhatsAppCredentialsDialog({
    super.key,
    required this.initialInstanceId,
    required this.initialToken,
    required this.onSaved,
  });

  @override
  State<WhatsAppCredentialsDialog> createState() => _WhatsAppCredentialsDialogState();
}

class _WhatsAppCredentialsDialogState extends State<WhatsAppCredentialsDialog> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _instanceIdController;
  late final TextEditingController _tokenController;
  
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _instanceIdController = TextEditingController(text: widget.initialInstanceId);
    _tokenController = TextEditingController(text: widget.initialToken);
  }

  @override
  void dispose() {
    _instanceIdController.dispose();
    _tokenController.dispose();
    super.dispose();
  }

  // Error state
  String? _errorMessage;

  Future<void> _saveCredentials() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isSaving = true;
      _errorMessage = null;
    });

    try {
      // First test the connection
      final testResult = await WhatsAppApiService.testConnection(
        greenApiInstanceId: _instanceIdController.text.trim(),
        greenApiToken: _tokenController.text.trim(),
      );
      
      if (testResult['success'] != true) {
        setState(() {
          _isSaving = false;
          _errorMessage = '${AppLocalizations.of(context)?.connectionTestFailed ?? 'Connection test failed'}: ${testResult['message']}';
        });
        return;
      }
      
      // First get current settings to preserve existing values
      final currentSettings = await WhatsAppApiService.getSettings();
      
      // If test successful, save the credentials while preserving other settings
      await WhatsAppApiService.updateSettings(
        greenApiInstanceId: _instanceIdController.text.trim(),
        greenApiToken: _tokenController.text.trim(),
        // Preserve template settings
        reminderTemplate7Days: currentSettings['reminder_template_7_days'],
        reminderTemplateDueToday: currentSettings['reminder_template_due_today'],
        reminderTemplateManual: currentSettings['reminder_template_manual'],
        // Preserve enabled status
        isEnabled: currentSettings['is_enabled'],
      );

      _showSuccessSnackBar(AppLocalizations.of(context)?.credentialsUpdated ?? 'Credentials updated successfully!');
      if (mounted) {
        Navigator.of(context).pop();
        widget.onSaved();
      }
    } catch (e) {
      setState(() {
        _isSaving = false;
        _errorMessage = '${AppLocalizations.of(context)?.failedToSaveCredentials ?? 'Failed to save credentials'}: $e';
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
      desktop: WhatsAppCredentialsDialogDesktop(
        formKey: _formKey,
        instanceIdController: _instanceIdController,
        tokenController: _tokenController,
        errorMessage: _errorMessage,
        isSaving: _isSaving,
        onCancel: _handleCancel,
        onSave: _saveCredentials,
      ),
      mobile: WhatsAppCredentialsDialogMobile(
        formKey: _formKey,
        instanceIdController: _instanceIdController,
        tokenController: _tokenController,
        errorMessage: _errorMessage,
        isSaving: _isSaving,
        onCancel: _handleCancel,
        onSave: _saveCredentials,
      ),
    );
  }
}