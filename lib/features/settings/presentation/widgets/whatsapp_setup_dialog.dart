import 'package:flutter/material.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/localization/app_localizations.dart';
import '../../../../shared/widgets/responsive_layout.dart';
import '../../../settings/data/services/whatsapp_api_service.dart';
import 'desktop/whatsapp_setup_dialog_desktop.dart' as desktop;
import 'mobile/whatsapp_setup_dialog_mobile.dart' as mobile;

// Local enum for state management
enum LocalSetupStep { credentials, templates }

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
  LocalSetupStep _currentStep = LocalSetupStep.credentials;
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
    if (_currentStep == LocalSetupStep.credentials) {
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
            _currentStep = LocalSetupStep.templates;
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
    if (_currentStep == LocalSetupStep.templates) {
      setState(() {
        _currentStep = LocalSetupStep.credentials;
      });
    }
  }

  void _onCancel() {
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    return ResponsiveLayout(
      desktop: desktop.WhatsAppSetupDialogDesktop(
        formKey: _formKey,
        instanceIdController: _instanceIdController,
        tokenController: _tokenController,
        template7DaysController: _template7DaysController,
        templateDueTodayController: _templateDueTodayController,
        templateManualController: _templateManualController,
        isTesting: _isTesting,
        isSaving: _isSaving,
        connectionTested: _connectionTested,
        connectionSuccess: _connectionSuccess,
        currentStep: _currentStep == LocalSetupStep.credentials ? 
                    desktop.SetupStep.credentials : 
                    desktop.SetupStep.templates,
        setupErrorMessage: _setupErrorMessage,
        onCancel: _onCancel,
        onTestConnection: _testConnection,
        onNextStep: _nextStep,
        onPreviousStep: _previousStep,
        onSave: _saveSettings,
      ),
      mobile: mobile.WhatsAppSetupDialogMobile(
        formKey: _formKey,
        instanceIdController: _instanceIdController,
        tokenController: _tokenController,
        template7DaysController: _template7DaysController,
        templateDueTodayController: _templateDueTodayController,
        templateManualController: _templateManualController,
        isTesting: _isTesting,
        isSaving: _isSaving,
        connectionTested: _connectionTested,
        connectionSuccess: _connectionSuccess,
        currentStep: _currentStep == LocalSetupStep.credentials ? 
                    mobile.SetupStep.credentials : 
                    mobile.SetupStep.templates,
        setupErrorMessage: _setupErrorMessage,
        onCancel: _onCancel,
        onTestConnection: _testConnection,
        onNextStep: _nextStep,
        onPreviousStep: _previousStep,
        onSave: _saveSettings,
      ),
    );
  }
}