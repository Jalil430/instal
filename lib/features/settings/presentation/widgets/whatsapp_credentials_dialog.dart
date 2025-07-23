import 'package:flutter/material.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/localization/app_localizations.dart';
import '../../../../shared/widgets/custom_button.dart';
import '../../../../shared/widgets/custom_text_field.dart';
import '../../../settings/data/services/whatsapp_api_service.dart';

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
                  
                  CustomTextField(
                    controller: _instanceIdController,
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
                    controller: _tokenController,
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
                    onPressed: _isSaving ? null : _saveCredentials,
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