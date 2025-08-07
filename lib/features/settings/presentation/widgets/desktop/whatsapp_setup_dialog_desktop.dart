import 'package:flutter/material.dart';
import '../../../../../core/theme/app_theme.dart';
import '../../../../../core/localization/app_localizations.dart';
import '../../../../../shared/widgets/custom_button.dart';
import '../../../../../shared/widgets/custom_text_field.dart';
import '../../../../settings/data/services/whatsapp_api_service.dart';
import '../whatsapp_template_editor.dart';

enum SetupStep { credentials, templates }

class WhatsAppSetupDialogDesktop extends StatelessWidget {
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

  const WhatsAppSetupDialogDesktop({
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
      child: Container(
        width: 600,
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header with title and step indicator
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
                    Icons.chat_bubble,
                    color: Colors.white,
                    size: 20,
                  ),
                ),
                const SizedBox(width: 16),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      AppLocalizations.of(context)?.whatsAppSetup ?? 'WhatsApp Setup',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w600,
                        color: AppTheme.textPrimary,
                      ),
                    ),
                    Text(
                      AppLocalizations.of(context)?.connectWhatsApp ?? 'Connect your WhatsApp for automated reminders',
                      style: TextStyle(
                        fontSize: 14,
                        color: AppTheme.textSecondary,
                      ),
                    ),
                  ],
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
            const SizedBox(height: 24),
            
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
            const SizedBox(height: 24),
            
            // Footer buttons
            Row(
              children: [
                // Cancel button (always visible)
                Expanded(
                  flex: 2,
                  child: CustomButton(
                    onPressed: onCancel,
                    text: AppLocalizations.of(context)?.cancel ?? 'Cancel',
                    icon: Icons.close,
                    showIcon: true,
                    color: Colors.white,
                    textColor: AppTheme.textSecondary,
                    height: 44,
                  ),
                ),
                const SizedBox(width: 12),
                
                if (currentStep == SetupStep.templates) ...[
                  Expanded(
                    flex: 2, // Smaller flex for back button
                    child: CustomButton(
                      onPressed: onPreviousStep,
                      text: AppLocalizations.of(context)?.back ?? 'Back',
                      icon: Icons.arrow_back,
                      showIcon: true,
                      color: Colors.white,
                      textColor: AppTheme.textPrimary,
                      height: 44,
                    ),
                  ),
                  const SizedBox(width: 12),
                ],
                Expanded(
                  flex: 3, // Larger flex for continue/complete button
                  child: CustomButton(
                    onPressed: currentStep == SetupStep.credentials 
                        ? onNextStep 
                        : (isSaving ? null : onSave),
                    text: currentStep == SetupStep.credentials 
                        ? AppLocalizations.of(context)?.continue_ ?? 'Continue' 
                        : (isSaving 
                            ? AppLocalizations.of(context)?.settingUp ?? 'Setting up...' 
                            : AppLocalizations.of(context)?.completeSetup ?? 'Complete Setup'),
                    icon: currentStep == SetupStep.credentials 
                        ? Icons.arrow_forward 
                        : (isSaving ? Icons.hourglass_empty : Icons.check_circle),
                    showIcon: true,
                    iconRight: currentStep == SetupStep.credentials,
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
          width: 28,
          height: 28,
          decoration: BoxDecoration(
            color: isActive || isCompleted ? const Color(0xFF25D366) : Colors.white,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: isActive || isCompleted ? const Color(0xFF25D366) : Colors.grey.shade300,
              width: 2,
            ),
          ),
          child: Center(
            child: isCompleted
                ? const Icon(Icons.check, size: 16, color: Colors.white)
                : Text(
                    step.toString(),
                    style: TextStyle(
                      fontSize: 14,
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
            fontSize: 12,
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
                    size: 18,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    AppLocalizations.of(context)?.howToGetCredentials ?? 'How to get Green API credentials',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                      color: Colors.blue,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                AppLocalizations.of(context)?.credentialsSteps ?? 
                '1. Visit green-api.com and create account\n'
                '2. Create new instance in dashboard\n'
                '3. Copy Instance ID and API Token\n'
                '4. Scan QR code with WhatsApp',
                style: TextStyle(
                  fontSize: 13,
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
        const SizedBox(height: 16),

        // Connection status
        if (connectionTested) ...[
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: connectionSuccess ? Colors.green.withOpacity(0.1) : Colors.red.withOpacity(0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              children: [
                Icon(
                  connectionSuccess ? Icons.check_circle : Icons.error,
                  color: connectionSuccess ? Colors.green : Colors.red,
                  size: 18,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    connectionSuccess 
                        ? AppLocalizations.of(context)?.connectionSuccess ?? 'Connection successful! You can continue.' 
                        : AppLocalizations.of(context)?.connectionFailed ?? 'Connection failed. Please check your credentials.',
                    style: TextStyle(
                      fontSize: 13,
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
              children: [
                const Icon(
                  Icons.error_outline,
                  color: Colors.red,
                  size: 20,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    setupErrorMessage!,
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
    );
  }
} 