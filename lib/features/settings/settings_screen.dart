import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../core/theme/app_theme.dart';
import '../../core/localization/app_localizations.dart';
import '../../main.dart';
import '../../shared/widgets/custom_button.dart';
import '../../shared/widgets/custom_text_field.dart';
import '../../shared/widgets/custom_dropdown.dart';
import '../auth/presentation/widgets/auth_service_provider.dart';
import '../auth/domain/entities/user.dart';
import 'presentation/profile_edit_screen.dart';
import 'data/services/whatsapp_api_service.dart';
import 'presentation/widgets/whatsapp_connection_status.dart';
import 'presentation/widgets/whatsapp_template_editor.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  String _selectedLanguage = 'ru';
  User? _currentUser;
  bool _loadingUser = true;
  bool _isInitialized = false;
  
  // WhatsApp settings
  final _formKey = GlobalKey<FormState>();
  final _instanceIdController = TextEditingController();
  final _tokenController = TextEditingController();
  final _template7DaysController = TextEditingController();
  final _templateDueTodayController = TextEditingController();
  final _templateManualController = TextEditingController();
  
  bool _isWhatsAppEnabled = false;
  bool _isWhatsAppLoading = true;
  bool _isWhatsAppSaving = false;
  bool _isWhatsAppTesting = false;
  bool _isWhatsAppConfigured = false;
  Map<String, dynamic>? _connectionTestResult;

  @override
  void initState() {
    super.initState();
    _loadWhatsAppSettings();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_isInitialized) {
      _loadLanguage();
      _loadCurrentUser();
      _isInitialized = true;
    }
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

  void _loadLanguage() {
    final locale = AppLocalizations.of(context)?.locale;
    if (locale != null) {
      if (_selectedLanguage != locale.languageCode) {
        setState(() {
          _selectedLanguage = locale.languageCode;
        });
      }
    }
  }

  Future<void> _loadWhatsAppSettings() async {
    setState(() {
      _isWhatsAppLoading = true;
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
        _isWhatsAppEnabled = settings['is_enabled'] ?? false;
        _isWhatsAppConfigured = settings['is_configured'] ?? false;
        _isWhatsAppLoading = false;
      });
      
      // If templates are empty, set defaults
      if (_template7DaysController.text.isEmpty || 
          _templateDueTodayController.text.isEmpty || 
          _templateManualController.text.isEmpty) {
        _setDefaultTemplates();
      }
      
    } catch (e) {
      print('Error loading WhatsApp settings: $e');
      
      setState(() {
        _isWhatsAppLoading = false;
        // Set empty values to allow user to configure from scratch
        _instanceIdController.text = '';
        _tokenController.text = '';
        _isWhatsAppEnabled = false;
        _isWhatsAppConfigured = false;
      });
      
      // Set default templates on error
      _setDefaultTemplates();
      
      // Show more user-friendly error message
      String errorMessage;
      if (e.toString().contains('502') || e.toString().contains('Bad Gateway')) {
        errorMessage = 'Сервер WhatsApp временно недоступен. Вы можете настроить интеграцию, но сохраненные настройки будут доступны позже.';
      } else if (e.toString().contains('404') || e.toString().contains('Not Found')) {
        errorMessage = 'Настройки WhatsApp еще не созданы. Вы можете настроить их сейчас.';
      } else {
        errorMessage = 'Не удалось загрузить настройки WhatsApp. Вы можете настроить их заново.';
      }
      
      _showErrorSnackBar(errorMessage);
    }
  }
  
  void _setDefaultTemplates() {
    _template7DaysController.text = 'Здравствуйте, {client_name}! Напоминаем, что ваш платеж по рассрочке в размере {installment_amount} руб. за {product_name} должен быть внесен через {days_remaining} дней ({due_date}). Пожалуйста, подготовьте средства для оплаты.';
    _templateDueTodayController.text = 'Здравствуйте, {client_name}! Ваш платеж по рассрочке в размере {installment_amount} руб. за {product_name} должен быть внесен сегодня ({due_date}). Пожалуйста, произведите оплату.';
    _templateManualController.text = 'Здравствуйте, {client_name}! Напоминаем о вашем платеже по рассрочке в размере {installment_amount} руб. за {product_name}. Дата платежа: {due_date}.';
  }
  
  Future<void> _testWhatsAppConnection() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }
    
    setState(() {
      _isWhatsAppTesting = true;
      _connectionTestResult = null;
    });
    
    try {
      final result = await WhatsAppApiService.testConnection(
        greenApiInstanceId: _instanceIdController.text.trim(),
        greenApiToken: _tokenController.text.trim(),
      );
      
      setState(() {
        _connectionTestResult = result;
        _isWhatsAppTesting = false;
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
        _isWhatsAppTesting = false;
      });
      
      _showErrorSnackBar('Connection test failed: $e');
    }
  }
  
  Future<void> _saveWhatsAppSettings() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }
    
    setState(() {
      _isWhatsAppSaving = true;
    });
    
    try {
      final result = await WhatsAppApiService.updateSettings(
        greenApiInstanceId: _instanceIdController.text.trim(),
        greenApiToken: _tokenController.text.trim(),
        reminderTemplate7Days: _template7DaysController.text.trim(),
        reminderTemplateDueToday: _templateDueTodayController.text.trim(),
        reminderTemplateManual: _templateManualController.text.trim(),
        isEnabled: _isWhatsAppEnabled,
        testConnection: false, // Don't test connection during save
      );
      
      setState(() {
        _isWhatsAppSaving = false;
        _isWhatsAppConfigured = result['is_configured'] ?? false;
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
        _isWhatsAppSaving = false;
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

  Future<void> _loadCurrentUser() async {
    try {
      final authService = AuthServiceProvider.of(context);
      
      // First check if user is authenticated
      final isAuthenticated = await authService.isAuthenticated();
      if (!isAuthenticated) {
        if (mounted) {
          setState(() {
            _currentUser = null;
            _loadingUser = false;
          });
        }
        return;
      }
      
      // Try to get fresh user data from server
      final user = await authService.getCurrentUserFromServer();
      
      if (mounted) {
        setState(() {
          _currentUser = user;
          _loadingUser = false;
        });
      }
    } catch (e) {
      print('Error loading user data: $e');
      if (mounted) {
        setState(() {
          _loadingUser = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error loading user data: $e'),
            backgroundColor: AppTheme.errorColor,
          ),
        );
      }
    }
  }

  Future<void> _logout() async {
    try {
      final authService = AuthServiceProvider.of(context);
      await authService.logout();
      
      // Navigate to login screen after logout
      if (mounted) {
        context.go('/auth/login');
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error during logout: $e'),
            backgroundColor: AppTheme.errorColor,
          ),
        );
      }
    }
  }

  void _navigateToEditProfile() {
    if (_currentUser == null) return;
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => ProfileEditScreen(user: _currentUser!),
      ),
    ).then((_) {
      // Refresh user data when returning from edit screen
      _loadCurrentUser();
    });
  }

  void _changeLanguage(String langCode) {
    final locale = Locale(langCode);
    final localeSetter = LocaleSetter.of(context);
    localeSetter?.setLocale(locale);
  }

  String _formatDate(DateTime date) {
    final months = [
      'January', 'February', 'March', 'April', 'May', 'June',
      'July', 'August', 'September', 'October', 'November', 'December'
    ];
    return '${months[date.month - 1]} ${date.year}';
  }

  Widget _buildProfileView(User user) {
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
          // User Avatar and Name Row
          Row(
            children: [
              // Avatar placeholder
              Container(
                width: 64,
                height: 64,
                decoration: BoxDecoration(
                  color: AppTheme.primaryColor.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(32),
                ),
                child: Icon(
                  Icons.person,
                  size: 32,
                  color: AppTheme.primaryColor,
                ),
              ),
              const SizedBox(width: 16),
              // User info
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      user.fullName,
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      user.email,
                      style: TextStyle(
                        fontSize: 14,
                        color: AppTheme.textSecondary,
                      ),
                    ),
                    if (user.phone != null) ...[
                      const SizedBox(height: 2),
                      Text(
                        user.phone!,
                        style: TextStyle(
                          fontSize: 14,
                          color: AppTheme.textSecondary,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          
          // Action buttons
          Row(
            children: [
              Expanded(
                child: CustomButton(
                  onPressed: _navigateToEditProfile,
                  text: AppLocalizations.of(context)?.editProfile ?? 'Edit Profile',
                  icon: Icons.edit,
                  showIcon: true,
                  height: 40,
                  fontSize: 14,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: CustomButton(
                  onPressed: _logout,
                  text: AppLocalizations.of(context)?.logout ?? 'Logout',
                  icon: Icons.logout,
                  showIcon: true,
                  color: AppTheme.errorColor,
                  height: 40,
                  fontSize: 14,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: Column(
        children: [
          // Header
          Container(
            padding: const EdgeInsets.fromLTRB(32, 28, 32, 20),
            color: AppTheme.surfaceColor,
            child: Row(
              children: [
                const SizedBox(width: 4),
                Text(
                  AppLocalizations.of(context)?.settings ?? 'Настройки',
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w600,
                    letterSpacing: -0.5,
                  ),
                ),
                const Spacer(),
              ],
            ),
          ),
          // Content
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(32),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Profile Section
                  Text(
                    AppLocalizations.of(context)?.profile ?? 'Profile',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w500,
                      color: AppTheme.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 16),
                  if (_loadingUser)
                    Container(
                      padding: const EdgeInsets.all(24),
                      decoration: BoxDecoration(
                        color: AppTheme.surfaceColor,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: AppTheme.borderColor),
                      ),
                      child: const Center(
                        child: CircularProgressIndicator(),
                      ),
                    )
                  else if (_currentUser != null)
                    _buildProfileView(_currentUser!)
                  else ...[
                    Container(
                      padding: const EdgeInsets.all(24),
                      decoration: BoxDecoration(
                        color: AppTheme.surfaceColor,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: AppTheme.borderColor),
                      ),
                      child: Center(
                        child: Column(
                          children: [
                            Icon(
                              Icons.error_outline,
                              size: 48,
                              color: AppTheme.textSecondary,
                            ),
                            const SizedBox(height: 12),
                            Text(
                              'Unable to load profile information',
                              style: TextStyle(
                                color: AppTheme.textSecondary,
                              ),
                            ),
                            const SizedBox(height: 16),
                            CustomButton(
                              onPressed: _logout,
                              text: AppLocalizations.of(context)?.logout ?? 'Logout',
                              icon: Icons.logout,
                              showIcon: true,
                              color: AppTheme.errorColor,
                              height: 40,
                              fontSize: 14,
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                  const SizedBox(height: 32),
                  
                  // Language Section
                  Text(
                    AppLocalizations.of(context)?.language ?? 'Language',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w500,
                      color: AppTheme.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 16),
                  CustomDropdown<String>(
                    value: _selectedLanguage,
                    items: {
                      'ru': AppLocalizations.of(context)?.languageRussian ?? 'Русский',
                      'en': AppLocalizations.of(context)?.languageEnglish ?? 'English',
                    },
                    onChanged: (String? newValue) {
                      if (newValue != null) {
                        _changeLanguage(newValue);
                      }
                    },
                    width: 250,
                  ),
                  const SizedBox(height: 32),
                  
                  // WhatsApp Settings Section
                  Text(
                    'WhatsApp Integration',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w500,
                      color: AppTheme.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 16),
                  
                  // WhatsApp Settings Form
                  Form(
                    key: _formKey,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Credentials section
                        _buildWhatsAppCredentialsSection(),
                        const SizedBox(height: 24),
                        
                        // Enable/disable section
                        _buildWhatsAppEnableSection(),
                        const SizedBox(height: 24),
                        
                        // Template editor section
                        WhatsAppTemplateEditor(
                          template7DaysController: _template7DaysController,
                          templateDueTodayController: _templateDueTodayController,
                          templateManualController: _templateManualController,
                        ),
                        
                        // Save button
                        const SizedBox(height: 24),
                        Row(
                          children: [
                            Expanded(
                              child: CustomButton(
                                onPressed: _isWhatsAppSaving ? null : _saveWhatsAppSettings,
                                text: _isWhatsAppSaving ? 'Saving...' : 'Save WhatsApp Settings',
                                icon: _isWhatsAppSaving ? Icons.hourglass_empty : Icons.save,
                                showIcon: true,
                                height: 48,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 32),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
  
  Widget _buildWhatsAppCredentialsSection() {
    if (_isWhatsAppLoading) {
      return Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: AppTheme.surfaceColor,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppTheme.borderColor),
        ),
        child: const Center(
          child: CircularProgressIndicator(),
        ),
      );
    }
    
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
              if (!RegExp(r'^\d+$').hasMatch(value)) {
                return 'Instance ID must be numeric';
              }
              return null;
            },
            onChanged: (value) {
              setState(() {
                _isWhatsAppConfigured = value.isNotEmpty && _tokenController.text.isNotEmpty;
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
                _isWhatsAppConfigured = _instanceIdController.text.isNotEmpty && value.isNotEmpty;
              });
            },
          ),
          const SizedBox(height: 20),
          
          // Test connection button
          Row(
            children: [
              Expanded(
                child: CustomButton(
                  onPressed: _isWhatsAppConfigured && !_isWhatsAppTesting ? _testWhatsAppConnection : null,
                  text: _isWhatsAppTesting ? 'Testing...' : 'Test Connection',
                  icon: _isWhatsAppTesting ? Icons.hourglass_empty : Icons.wifi_find,
                  showIcon: true,
                  color: _isWhatsAppConfigured ? AppTheme.primaryColor : AppTheme.textSecondary,
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
  
  Widget _buildWhatsAppEnableSection() {
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
                value: _isWhatsAppEnabled,
                onChanged: _isWhatsAppConfigured && _connectionTestResult?['success'] == true 
                    ? (value) {
                        setState(() {
                          _isWhatsAppEnabled = value;
                        });
                      }
                    : null,
                activeColor: AppTheme.primaryColor,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  _isWhatsAppEnabled ? 'WhatsApp reminders are enabled' : 'WhatsApp reminders are disabled',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                    color: _isWhatsAppEnabled ? AppTheme.successColor : AppTheme.textSecondary,
                  ),
                ),
              ),
            ],
          ),
          
          if (!_isWhatsAppConfigured || _connectionTestResult?['success'] != true) ...[
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
} 