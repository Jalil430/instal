import 'package:flutter/material.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/localization/app_localizations.dart';
import '../../../../shared/widgets/custom_button.dart';
import '../../../../shared/widgets/custom_text_field.dart';
import '../../../settings/data/services/whatsapp_api_service.dart';
import 'whatsapp_template_editor.dart';

enum SetupStep { credentials, templates }

class WhatsAppSetupDialog extends StatefulWidget {
  final VoidCallback onSetupComplete;

  const WhatsAppSetupDialog({
    super.key,
    required this.onSetupComplete,
  });

  @override
  State<WhatsAppSetupDialog> createState() => _WhatsAppSetupDialogState();
}

class _WhatsAppSetupDialogState extends State<WhatsAppSetupDialog> {
  SetupStep _currentStep = SetupStep.credentials;
  final _formKey = GlobalKey<FormState>();
  
  // Controllers for credentials
  final _instanceIdController = TextEditingController();
  final _tokenController = TextEditingController();
  
  // Controllers for templates
  final _template7DaysController = TextEditingController();
  final _templateDueTodayController = TextEditingController();
  final _templateManualController = TextEditingController();
  
  // State variables
  bool _isTesting = false;
  bool _isSaving = false;
  bool _connectionTested = false;
  bool _connectionSuccess = false;

  @override
  void initState() {
    super.initState();
    _setDefaultTemplates();
  }

  @override
  void dispose() {
    _instanceIdController.dispose();
    _tokenController.dispose();
    _template7DaysController.dispose();
    _templateDueTodayController.dispose();
    _templateManualController.dispose();
    super.dispose();
  }

  void _setDefaultTemplates() {
    _template7DaysController.text = 'Здравствуйте, {client_name}! Напоминаем, что ваш платеж по рассрочке в размере {installment_amount} руб. за {product_name} должен быть внесен через {days_remaining} дней ({due_date}). Пожалуйста, подготовьте средства для оплаты.';
    _templateDueTodayController.text = 'Здравствуйте, {client_name}! Ваш платеж по рассрочке в размере {installment_amount} руб. за {product_name} должен быть внесен сегодня ({due_date}). Пожалуйста, произведите оплату.';
    _templateManualController.text = 'Здравствуйте, {client_name}! Напоминаем о вашем платеже по рассрочке в размере {installment_amount} руб. за {product_name}. Дата платежа: {due_date}.';
  }

  Future<void> _testConnection() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isTesting = true;
      _connectionTested = false;
      _connectionSuccess = false;
    });

    try {
      final result = await WhatsAppApiService.testConnection(
        greenApiInstanceId: _instanceIdController.text.trim(),
        greenApiToken: _tokenController.text.trim(),
      );

      setState(() {
        _connectionTested = true;
        _connectionSuccess = result['success'] == true;
        _isTesting = false;
      });

      if (_connectionSuccess) {
        _showSuccessSnackBar(AppLocalizations.of(context)?.connectionSuccess ?? 'Connection successful!');
      } else {
        _showErrorSnackBar('${AppLocalizations.of(context)?.connectionFailed ?? 'Connection failed'}: ${result['message']}');
      }
    } catch (e) {
      setState(() {
        _connectionTested = true;
        _connectionSuccess = false;
        _isTesting = false;
      });
      _showErrorSnackBar('${AppLocalizations.of(context)?.connectionFailed ?? 'Connection failed'}: $e');
    }
  }

  // Error state for templates step
  String? _setupErrorMessage;

  Future<void> _saveSettings() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isSaving = true;
      _setupErrorMessage = null;
    });

    try {
      await WhatsAppApiService.updateSettings(
        greenApiInstanceId: _instanceIdController.text.trim(),
        greenApiToken: _tokenController.text.trim(),
        reminderTemplate7Days: _template7DaysController.text.trim(),
        reminderTemplateDueToday: _templateDueTodayController.text.trim(),
        reminderTemplateManual: _templateManualController.text.trim(),
        isEnabled: true,
      );

      setState(() {
        _isSaving = false;
      });

      _showSuccessSnackBar(AppLocalizations.of(context)?.whatsAppSetupCompleted ?? 'WhatsApp integration setup completed!');
      Navigator.of(context).pop();
      widget.onSetupComplete();
      
    } catch (e) {
      setState(() {
        _isSaving = false;
        _setupErrorMessage = '${AppLocalizations.of(context)?.failedToSaveSettings ?? 'Failed to save settings'}: $e';
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

  void _showErrorSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: AppTheme.errorColor,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  void _nextStep() {
  if (_currentStep == SetupStep.credentials) {
    if (!_formKey.currentState!.validate()) return;
    
    // Test connection before proceeding
    setState(() {
      _isTesting = true;
    });
    
    WhatsAppApiService.testConnection(
      greenApiInstanceId: _instanceIdController.text.trim(),
      greenApiToken: _tokenController.text.trim(),
    ).then((result) {
      setState(() {
        _isTesting = false;
        _connectionTested = true;
        _connectionSuccess = result['success'] == true;
      });
      
      if (_connectionSuccess) {
        _showSuccessSnackBar(AppLocalizations.of(context)?.connectionSuccess ?? 'Connection successful!');
        // Proceed to next step
        setState(() {
          _currentStep = SetupStep.templates;
        });
      } else {
        _showErrorSnackBar('${AppLocalizations.of(context)?.connectionFailed ?? 'Connection failed'}: ${result['message']}');
      }
    }).catchError((e) {
      setState(() {
        _isTesting = false;
        _connectionTested = true;
        _connectionSuccess = false;
      });
      _showErrorSnackBar('${AppLocalizations.of(context)?.connectionFailed ?? 'Connection failed'}: $e');
    });
  }
}


  void _previousStep() {
    if (_currentStep == SetupStep.templates) {
      setState(() {
        _currentStep = SetupStep.credentials;
      });
    }
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
                  step: 1,
                  title: AppLocalizations.of(context)?.credentials ?? 'Credentials',
                  isActive: _currentStep == SetupStep.credentials,
                  isCompleted: _currentStep == SetupStep.templates,
                ),
                Expanded(
                  child: Container(
                    height: 2,
                    color: _currentStep == SetupStep.templates
                        ? const Color(0xFF25D366)
                        : Colors.grey.shade300,
                  ),
                ),
                _buildStepIndicator(
                  step: 2,
                  title: AppLocalizations.of(context)?.templates ?? 'Templates',
                  isActive: _currentStep == SetupStep.templates,
                  isCompleted: false,
                ),
              ],
            ),
            const SizedBox(height: 24),
            
            // Content
            Flexible(
              child: Form(
                key: _formKey,
                child: SingleChildScrollView(
                  child: _currentStep == SetupStep.credentials
                      ? _buildCredentialsStep()
                      : _buildTemplatesStep(),
                ),
              ),
            ),
            const SizedBox(height: 24),
            
            // Footer buttons
Row(
  children: [
    if (_currentStep == SetupStep.templates) ...[
      Expanded(
        flex: 2, // Smaller flex for back button
        child: CustomButton(
          onPressed: _previousStep,
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
        onPressed: _currentStep == SetupStep.credentials 
            ? _nextStep 
            : (_isSaving ? null : _saveSettings),
        text: _currentStep == SetupStep.credentials 
            ? AppLocalizations.of(context)?.continue_ ?? 'Continue' 
            : (_isSaving 
                ? AppLocalizations.of(context)?.settingUp ?? 'Setting up...' 
                : AppLocalizations.of(context)?.completeSetup ?? 'Complete Setup'),
        icon: _currentStep == SetupStep.credentials 
            ? Icons.arrow_forward 
            : (_isSaving ? Icons.hourglass_empty : Icons.check_circle),
        showIcon: true,
        iconRight: _currentStep == SetupStep.credentials,
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

  Widget _buildCredentialsStep() {
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
        const SizedBox(height: 16),

        // Connection status
        if (_connectionTested) ...[
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: _connectionSuccess ? Colors.green.withOpacity(0.1) : Colors.red.withOpacity(0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              children: [
                Icon(
                  _connectionSuccess ? Icons.check_circle : Icons.error,
                  color: _connectionSuccess ? Colors.green : Colors.red,
                  size: 18,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    _connectionSuccess 
                        ? AppLocalizations.of(context)?.connectionSuccess ?? 'Connection successful! You can continue.' 
                        : AppLocalizations.of(context)?.connectionFailed ?? 'Connection failed. Please check your credentials.',
                    style: TextStyle(
                      fontSize: 13,
                      color: _connectionSuccess ? Colors.green.shade700 : Colors.red.shade700,
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

  Widget _buildTemplatesStep() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Error message if present
        if (_setupErrorMessage != null) ...[
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
                    _setupErrorMessage!,
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
    );
  }
}