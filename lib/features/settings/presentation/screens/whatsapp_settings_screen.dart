import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/localization/app_localizations.dart';
import '../../../../shared/widgets/custom_button.dart';
import '../../../../shared/widgets/custom_text_field.dart';
import '../../../auth/presentation/widgets/auth_service_provider.dart';
import '../widgets/whatsapp_connection_status.dart';
import '../widgets/whatsapp_template_editor.dart';
import '../../data/services/whatsapp_api_service.dart';

class WhatsAppSettingsScreen extends StatefulWidget {
  const WhatsAppSettingsScreen({super.key});

  @override
  State<WhatsAppSettingsScreen> createState() => _WhatsAppSettingsScreenState();
}

class _WhatsAppSettingsScreenState extends State<WhatsAppSettingsScreen> {
  // Form controllers
  final _instanceIdController = TextEditingController();
  final _tokenController = TextEditingController();
  
  // Form key for validation
  final _formKey = GlobalKey<FormState>();
  
  // State variables
  bool _isEnabled = false;
  bool _isLoading = true;
  bool _isSaving = false;
  bool _isTesting = false;
  bool _isConfigured = false;
  
  // Connection test result
  Map<String, dynamic>? _connectionTestResult;
  
  // Template controllers
  final _template7DaysController = TextEditingController();
  final _templateDueTodayController = TextEditingController();
  final _templateManualController = TextEditingController();
  
  @override
  void initState() {
    super.initState();
    _loadSettings();
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
  
  Future<void> _loadSettings() async {
    setState(() {
      _isLoading = true;
    });
    
    try {
      final settings = await WhatsAppApiService.getSettings();
      
      // Update form fields with loaded settings
      _instanceIdController.text = settings['green_api_instance_id'] ?? '';
      _tokenController.text = settings['green_api_token'] ?? '';
      _template7DaysController.text = settings['reminder_template_7_days'] ?? '';
      _templateDueTodayController.text = settings['reminder_template_due_today'] ?? '';
      _templateManualController.text = settings['reminder_template_manual'] ?? '';
      
      setState(() {
        _isEnabled = settings['is_enabled'] ?? false;
        _isConfigured = settings['is_configured'] ?? false;
        _isLoading = false;
      });
      
      // If templates are empty, set defaults
      if (_template7DaysController.text.isEmpty || 
          _templateDueTodayController.text.isEmpty || 
          _templateManualController.text.isEmpty) {
        _setDefaultTemplates();
      }
      
    } catch (e) {
      setState(() {
        _isLoading = false;
      });
      
      // Set default templates on error
      _setDefaultTemplates();
      _showErrorSnackBar('Failed to load WhatsApp settings: $e');
    }
  }
  
  void _setDefaultTemplates() {
    _template7DaysController.text = 'Здравствуйте, {client_name}! Напоминаем, что ваш платеж по рассрочке в размере {installment_amount} руб. за {product_name} должен быть внесен через {days_remaining} дней ({due_date}). Пожалуйста, подготовьте средства для оплаты.';
    _templateDueTodayController.text = 'Здравствуйте, {client_name}! Ваш платеж по рассрочке в размере {installment_amount} руб. за {product_name} должен быть внесен сегодня ({due_date}). Пожалуйста, произведите оплату.';
    _templateManualController.text = 'Здравствуйте, {client_name}! Напоминаем о вашем платеже по рассрочке в размере {installment_amount} руб. за {product_name}. Дата платежа: {due_date}.';
  }
  
  Future<void> _testConnection() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }
    
    setState(() {
      _isTesting = true;
      _connectionTestResult = null;
    });
    
    try {
      final result = await WhatsAppApiService.testConnection(
        greenApiInstanceId: _instanceIdController.text.trim(),
        greenApiToken: _tokenController.text.trim(),
      );
      
      setState(() {
        _connectionTestResult = result;
        _isTesting = false;
      });
      
      if (result['success'] == true) {
        _showSuccessSnackBar('Connection test successful!');
      } else {
        _showErrorSnackBar('Connection test failed: ${result['message']}');
      }
    } catch (e) {
      setState(() {
        _connectionTestResult = {
          'success': false,
          'message': 'Connection test failed: $e',
          'recommendations': [
            'Check your internet connection',
            'Verify your Green API credentials are correct',
            'Ensure Green API service is accessible'
          ]
        };
        _isTesting = false;
      });
      
      _showErrorSnackBar('Connection test failed: $e');
    }
  }
  
  Future<void> _saveSettings() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }
    
    setState(() {
      _isSaving = true;
    });
    
    try {
      final result = await WhatsAppApiService.updateSettings(
        greenApiInstanceId: _instanceIdController.text.trim(),
        greenApiToken: _tokenController.text.trim(),
        reminderTemplate7Days: _template7DaysController.text.trim(),
        reminderTemplateDueToday: _templateDueTodayController.text.trim(),
        reminderTemplateManual: _templateManualController.text.trim(),
        isEnabled: _isEnabled,
        testConnection: false, // Don't test connection during save
      );
      
      setState(() {
        _isSaving = false;
        _isConfigured = result['is_configured'] ?? false;
      });
      
      _showSuccessSnackBar('WhatsApp settings saved successfully!');
      
      // If connection test was included in the response, update it
      if (result['connection_test'] != null) {
        setState(() {
          _connectionTestResult = result['connection_test'];
        });
      }
      
    } catch (e) {
      setState(() {
        _isSaving = false;
      });
      _showErrorSnackBar('Failed to save settings: $e');
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
  
  Widget _buildCredentialsSection() {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: AppTheme.surfaceColor,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppTheme.borderColor),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.api,
                color: AppTheme.primaryColor,
                size: 20,
              ),
              const SizedBox(width: 8),
              Text(
                'Green API Credentials',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: AppTheme.textPrimary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          
          // Instance ID field
          CustomTextField(
            controller: _instanceIdController,
            label: 'Instance ID',
            hintText: 'Enter your Green API instance ID',
            keyboardType: TextInputType.number,
            prefixIcon: Icons.numbers,
            validator: (value) {
              if (value == null || value.isEmpty) {
                return 'Instance ID is required';
              }
              if (!RegExp(r'^\d+$')$').hasMatch(value)) {
                return 'Instance ID must be numeric';
              }
              return null;
            },
            onChanged: (value) {
              setState(() {
                _isConfigured = value.isNotEmpty && _tokenController.text.isNotEmpty;
              });
            },
          ),
          const SizedBox(height: 16),
          
          // Token field
          CustomTextField(
            controller: _tokenController,
            label: 'API Token',
            hintText: 'Enter your Green API token',
            prefixIcon: Icons.key,
            obscureText: true,
            validator: (value) {
              if (value == null || value.isEmpty) {
                return 'API Token is required';
              }
              if (value.length < 10) {
                return 'API Token appears to be too short';
              }
              return null;
            },
            onChanged: (value) {
              setState(() {
                _isConfigured = _instanceIdController.text.isNotEmpty && value.isNotEmpty;
              });
            },
          ),
          const SizedBox(height: 20),
          
          // Test connection button
          Row(
            children: [
              Expanded(
                child: CustomButton(
                  onPressed: _isConfigured && !_isTesting ? _testConnection : null,
                  text: _isTesting ? 'Testing...' : 'Test Connection',
                  icon: _isTesting ? Icons.hourglass_empty : Icons.wifi_find,
                  showIcon: true,
                  color: _isConfigured ? AppTheme.primaryColor : AppTheme.textSecondary,
                ),
              ),
            ],
          ),
          
          // Connection status
          if (_connectionTestResult != null) ...[
            const SizedBox(height: 16),
            WhatsAppConnectionStatus(
              testResult: _connectionTestResult!,
            ),
          ],
        ],
      ),
    );
  }
  
  Widget _buildEnableSection() {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: AppTheme.surfaceColor,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppTheme.borderColor),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.notifications_active,
                color: AppTheme.primaryColor,
                size: 20,
              ),
              const SizedBox(width: 8),
              Text(
                'WhatsApp Reminders',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: AppTheme.textPrimary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          
          Text(
            'Enable automatic WhatsApp reminders for installment payments. Reminders will be sent 7 days before due date and on the due date.',
            style: TextStyle(
              fontSize: 14,
              color: AppTheme.textSecondary,
            ),
          ),
          const SizedBox(height: 16),
          
          Row(
            children: [
              Switch(
                value: _isEnabled,
                onChanged: _isConfigured && _connectionTestResult?['success'] == true 
                    ? (value) {
                        setState(() {
                          _isEnabled = value;
                        });
                      }
                    : null,
                activeColor: AppTheme.primaryColor,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  _isEnabled ? 'WhatsApp reminders are enabled' : 'WhatsApp reminders are disabled',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                    color: _isEnabled ? AppTheme.successColor : AppTheme.textSecondary,
                  ),
                ),
              ),
            ],
          ),
          
          if (!_isConfigured || _connectionTestResult?['success'] != true) ...[
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppTheme.warningColor.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: AppTheme.warningColor.withOpacity(0.3)),
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.warning_amber,
                    color: AppTheme.warningColor,
                    size: 16,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Configure credentials and test connection to enable reminders',
                      style: TextStyle(
                        fontSize: 12,
                        color: AppTheme.warningColor,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
  
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.backgroundColor,
      appBar: AppBar(
        title: const Text('WhatsApp Settings'),
        backgroundColor: AppTheme.surfaceColor,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.of(context).pop(),
        ),
        actions: [
          if (!_isLoading)
            Padding(
              padding: const EdgeInsets.only(right: 16),
              child: CustomButton(
                onPressed: _isSaving ? null : _saveSettings,
                text: _isSaving ? 'Saving...' : 'Save',
                icon: _isSaving ? Icons.hourglass_empty : Icons.save,
                showIcon: true,
                height: 36,
                fontSize: 14,
              ),
            ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Form(
              key: _formKey,
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Credentials section
                    _buildCredentialsSection(),
                    const SizedBox(height: 24),
                    
                    // Enable/disable section
                    _buildEnableSection(),
                    const SizedBox(height: 24),
                    
                    // Template editor section
                    WhatsAppTemplateEditor(
                      template7DaysController: _template7DaysController,
                      templateDueTodayController: _templateDueTodayController,
                      templateManualController: _templateManualController,
                    ),
                  ],
                ),
              ),
            ),
    );
  }
}