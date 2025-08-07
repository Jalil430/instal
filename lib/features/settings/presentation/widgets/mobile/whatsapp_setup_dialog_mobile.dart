import 'package:flutter/material.dart';
import '../../../../../core/theme/app_theme.dart';
import '../../../../../core/localization/app_localizations.dart';
import '../../../../../shared/widgets/custom_button.dart';
import '../../../../../shared/widgets/custom_text_field.dart';
import '../../../../settings/data/services/whatsapp_api_service.dart';
import '../whatsapp_template_editor.dart';

enum SetupStep { credentials, templates }

class WhatsAppSetupDialogMobile extends StatelessWidget {
  final GlobalKey<FormState> formKey;
  
  // Controllers
  final TextEditingController instanceIdController;
  final TextEditingController tokenController;
  final TextEditingController template7DaysController;
  final TextEditingController templateDueTodayController;
  final TextEditingController templateManualController;
  
  // State
  final bool isTesting;
  final bool isSaving;
  final bool connectionTested;
  final bool connectionSuccess;
  final SetupStep currentStep;
  final String? setupErrorMessage;
  
  // Callbacks
  final VoidCallback onCancel;
  final VoidCallback onTestConnection;
  final VoidCallback onNextStep;
  final VoidCallback onPreviousStep;
  final VoidCallback onSave;

  const WhatsAppSetupDialogMobile({
    super.key,
    required this.formKey,
    required this.instanceIdController,
    required this.tokenController,
    required this.template7DaysController,
    required this.templateDueTodayController,
    required this.templateManualController,
    required this.isTesting,
    required this.isSaving,
    required this.connectionTested,
    required this.connectionSuccess,
    required this.currentStep,
    this.setupErrorMessage,
    required this.onCancel,
    required this.onTestConnection,
    required this.onNextStep,
    required this.onPreviousStep,
    required this.onSave,
  });

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
      // Adjust padding for mobile screens
      insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(16), // Less padding for mobile
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header with title, step indicator, and cancel button
            Row(
              children: [
                Container(
                  width: 36, // Slightly smaller for mobile
                  height: 36,
                  decoration: BoxDecoration(
                    color: const Color(0xFF25D366),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(
                    Icons.chat_bubble,
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
                        AppLocalizations.of(context)?.whatsAppSetup ?? 'WhatsApp Setup',
                        style: TextStyle(
                          fontSize: 16, // Smaller for mobile
                          fontWeight: FontWeight.w600,
                          color: AppTheme.textPrimary,
                        ),
                      ),
                      Text(
                        AppLocalizations.of(context)?.connectWhatsApp ?? 'Connect WhatsApp',
                        style: TextStyle(
                          fontSize: 12, // Smaller for mobile
                          color: AppTheme.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
                // Cancel button
                IconButton(
                  onPressed: onCancel,
                  icon: Icon(Icons.close, color: AppTheme.textSecondary),
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                  tooltip: AppLocalizations.of(context)?.cancel ?? 'Cancel',
                ),
              ],
            ),
            const SizedBox(height: 16),
            
            // Simple step indicator
            Row(
              children: [
                _buildStepIndicator(
                  context: context,
                  step: 1,
                  title: AppLocalizations.of(context)?.credentials ?? 'Credentials',
                  isActive: currentStep == SetupStep.credentials,
                  isCompleted: currentStep == SetupStep.templates,
                ),
                Expanded(
                  child: Container(
                    height: 2,
                    color: currentStep == SetupStep.templates
                        ? const Color(0xFF25D366)
                        : Colors.grey.shade300,
                  ),
                ),
                _buildStepIndicator(
                  context: context,
                  step: 2,
                  title: AppLocalizations.of(context)?.templates ?? 'Templates',
                  isActive: currentStep == SetupStep.templates,
                  isCompleted: false,
                ),
              ],
            ),
            const SizedBox(height: 16), // Less space for mobile
            
            // Content
            Flexible(
              child: Form(
                key: formKey,
                child: SingleChildScrollView(
                  child: currentStep == SetupStep.credentials
                      ? _buildCredentialsStep(context)
                      : _buildTemplatesStep(context),
                ),
              ),
            ),
            const SizedBox(height: 16),
            
            // Footer buttons - stacked for mobile
            if (currentStep == SetupStep.templates) ...[
              CustomButton(
                onPressed: isSaving ? null : onSave,
                text: isSaving 
                    ? AppLocalizations.of(context)?.settingUp ?? 'Setting up...' 
                    : AppLocalizations.of(context)?.completeSetup ?? 'Complete Setup',
                icon: isSaving ? Icons.hourglass_empty : Icons.check_circle,
                showIcon: true,
                height: 44,
                width: double.infinity,
              ),
              const SizedBox(height: 8),
              CustomButton(
                onPressed: onPreviousStep,
                text: AppLocalizations.of(context)?.back ?? 'Back',
                icon: Icons.arrow_back,
                showIcon: true,
                color: Colors.white,
                textColor: AppTheme.textPrimary,
                height: 44,
                width: double.infinity,
              ),
            ] else ...[
              CustomButton(
                onPressed: onNextStep,
                text: AppLocalizations.of(context)?.continue_ ?? 'Continue',
                icon: Icons.arrow_forward,
                showIcon: true,
                iconRight: true,
                height: 44,
                width: double.infinity,
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildStepIndicator({
    required BuildContext context,
    required int step,
    required String title,
    required bool isActive,
    required bool isCompleted,
  }) {
    return Column(
      children: [
        Container(
          width: 24, // Smaller for mobile
          height: 24,
          decoration: BoxDecoration(
            color: isActive || isCompleted ? const Color(0xFF25D366) : Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: isActive || isCompleted ? const Color(0xFF25D366) : Colors.grey.shade300,
              width: 2,
            ),
          ),
          child: Center(
            child: isCompleted
                ? const Icon(Icons.check, size: 14, color: Colors.white)
                : Text(
                    step.toString(),
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: isActive ? Colors.white : Colors.grey.shade600,
                    ),
                  ),
          ),
        ),
        const SizedBox(height: 4),
        Text(
          title,
          style: TextStyle(
            fontSize: 10, // Smaller for mobile
            color: isActive || isCompleted ? const Color(0xFF25D366) : Colors.grey.shade600,
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }

  Widget _buildCredentialsStep(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Info box
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Colors.blue.withOpacity(0.1),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(
                    Icons.info_outline,
                    color: Colors.blue,
                    size: 16,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      AppLocalizations.of(context)?.howToGetCredentials ?? 'How to get Green API credentials',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                        color: Colors.blue,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                AppLocalizations.of(context)?.credentialsSteps ?? 
                '1. Visit green-api.com\n'
                '2. Create new instance\n'
                '3. Copy Instance ID and API Token\n'
                '4. Scan QR code with WhatsApp',
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.blue.shade700,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),

        // Input fields
        CustomTextField(
          controller: instanceIdController,
          label: AppLocalizations.of(context)?.instanceId ?? 'Instance ID',
          hintText: AppLocalizations.of(context)?.enterInstanceId ?? 'Enter Green API instance ID',
          keyboardType: TextInputType.number,
          prefixIcon: Icons.tag,
          validator: (value) {
            if (value == null || value.isEmpty) {
              return AppLocalizations.of(context)?.instanceIdRequired ?? 'Instance ID is required';
            }
            if (!RegExp(r'^\d+$').hasMatch(value)) {
              return AppLocalizations.of(context)?.instanceIdNumeric ?? 'ID must be numeric';
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
              return AppLocalizations.of(context)?.apiTokenRequired ?? 'API Token is required';
            }
            if (value.length < 10) {
              return AppLocalizations.of(context)?.apiTokenTooShort ?? 'Token is too short';
            }
            return null;
          },
        ),
        const SizedBox(height: 16),

        // Connection status
        if (connectionTested) ...[
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: connectionSuccess ? Colors.green.withOpacity(0.1) : Colors.red.withOpacity(0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(
                  connectionSuccess ? Icons.check_circle : Icons.error,
                  color: connectionSuccess ? Colors.green : Colors.red,
                  size: 16,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    connectionSuccess 
                        ? AppLocalizations.of(context)?.connectionSuccess ?? 'Connection successful! Continue.' 
                        : AppLocalizations.of(context)?.connectionFailed ?? 'Connection failed. Check credentials.',
                    style: TextStyle(
                      fontSize: 12,
                      color: connectionSuccess ? Colors.green.shade700 : Colors.red.shade700,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildTemplatesStep(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Error message if present
        if (setupErrorMessage != null) ...[
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
                    setupErrorMessage!,
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
        
        // Direct template editor without card or additional titles
        WhatsAppTemplateEditor(
          template7DaysController: template7DaysController,
          templateDueTodayController: templateDueTodayController,
          templateManualController: templateManualController,
        ),
      ],
    );
  }
} 