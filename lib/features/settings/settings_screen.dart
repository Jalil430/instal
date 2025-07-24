import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../core/theme/app_theme.dart';
import '../../core/localization/app_localizations.dart';
import '../../main.dart';
import '../../shared/widgets/custom_button.dart';
import '../../shared/widgets/custom_dropdown.dart';
import '../auth/presentation/widgets/auth_service_provider.dart';
import '../auth/domain/entities/user.dart';
import '../../shared/widgets/edit_profile_dialog.dart';
import 'data/services/whatsapp_api_service.dart';
import 'presentation/widgets/whatsapp_integration_section.dart';
import 'presentation/widgets/whatsapp_setup_dialog.dart';
import 'presentation/widgets/whatsapp_credentials_dialog.dart';
import 'presentation/widgets/whatsapp_templates_dialog.dart';

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
  
  // WhatsApp settings state - CLEAN AND SIMPLE
  bool _isWhatsAppEnabled = false;
  bool _isWhatsAppLoading = true;
  bool _isWhatsAppConfigured = false;
  String _instanceId = '';
  String _token = '';
  String _template7Days = '';
  String _templateDueToday = '';
  String _templateManual = '';

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
      
      setState(() {
        _instanceId = settings['green_api_instance_id'] ?? '';
        _token = settings['green_api_token'] ?? '';
        _template7Days = settings['reminder_template_7_days'] ?? '';
        _templateDueToday = settings['reminder_template_due_today'] ?? '';
        _templateManual = settings['reminder_template_manual'] ?? '';
        _isWhatsAppEnabled = settings['is_enabled'] ?? false;
        _isWhatsAppConfigured = settings['is_configured'] ?? false;
        _isWhatsAppLoading = false;
      });
      
    } catch (e) {
      print('${AppLocalizations.of(context)?.errorLoadingWhatsAppSettings ?? 'Error loading WhatsApp settings'}: $e');
      
      setState(() {
        _isWhatsAppLoading = false;
        _instanceId = '';
        _token = '';
        _template7Days = '';
        _templateDueToday = '';
        _templateManual = '';
        _isWhatsAppEnabled = false;
        _isWhatsAppConfigured = false;
      });
    }
  }

  Future<void> _updateWhatsAppEnabled(bool enabled) async {
    try {
      await WhatsAppApiService.updateSettings(isEnabled: enabled);
      setState(() {
        _isWhatsAppEnabled = enabled;
      });
      _showSuccessSnackBar(enabled 
          ? AppLocalizations.of(context)?.whatsAppRemindersEnabled ?? 'WhatsApp reminders enabled' 
          : AppLocalizations.of(context)?.whatsAppRemindersDisabled ?? 'WhatsApp reminders disabled');
    } catch (e) {
      _showErrorSnackBar('${AppLocalizations.of(context)?.failedToUpdateSettings ?? 'Failed to update reminder settings'}: $e');
    }
  }

  void _showSetupDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => WhatsAppSetupDialog(
        onSetupComplete: _loadWhatsAppSettings,
      ),
    );
  }

  void _showCredentialsDialog() {
    showDialog(
      context: context,
      builder: (context) => WhatsAppCredentialsDialog(
        initialInstanceId: _instanceId,
        initialToken: _token,
        onSaved: _loadWhatsAppSettings,
      ),
    );
  }

  void _showTemplatesDialog() {
    showDialog(
      context: context,
      builder: (context) => WhatsAppTemplatesDialog(
        initialTemplate7Days: _template7Days,
        initialTemplateDueToday: _templateDueToday,
        initialTemplateManual: _templateManual,
        onSaved: _loadWhatsAppSettings,
      ),
    );
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
      
      final user = await authService.getCurrentUserFromServer();
      
      if (mounted) {
        setState(() {
          _currentUser = user;
          _loadingUser = false;
        });
      }
    } catch (e) {
      print('${AppLocalizations.of(context)?.errorLoadingUserData ?? 'Error loading user data'}: $e');
      if (mounted) {
        setState(() {
          _loadingUser = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('${AppLocalizations.of(context)?.errorLoadingUserData ?? 'Error loading user data'}: $e'),
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
      
      if (mounted) {
        context.go('/auth/login');
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('${AppLocalizations.of(context)?.errorDuringLogout ?? 'Error during logout'}: $e'),
            backgroundColor: AppTheme.errorColor,
          ),
        );
      }
    }
  }

  void _showEditProfileDialog() {
    if (_currentUser == null) return;
    showDialog(
      context: context,
      builder: (context) => EditProfileDialog(
        user: _currentUser!,
        onSuccess: _loadCurrentUser,
      ),
    );
  }

  void _changeLanguage(String langCode) {
    final locale = Locale(langCode);
    final localeSetter = LocaleSetter.of(context);
    localeSetter?.setLocale(locale);
  }

  Widget _buildProfileView(User user) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
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
        
        // Buttons - same style as WhatsApp integration section
        SizedBox(
          width: 350, // Same width as language dropdown and WhatsApp buttons
          child: CustomButton(
            onPressed: _showEditProfileDialog,
            text: AppLocalizations.of(context)?.editProfile ?? 'Edit Profile',
            icon: Icons.edit,
            showIcon: true,
            height: 44, // Same height as WhatsApp buttons
          ),
        ),
        const SizedBox(height: 12),
        SizedBox(
          width: 350, // Same width as language dropdown and WhatsApp buttons
          child: CustomButton(
            onPressed: _logout,
            text: AppLocalizations.of(context)?.logout ?? 'Logout',
            icon: Icons.logout,
            showIcon: true,
            color: AppTheme.errorColor,
            height: 44, // Same height as WhatsApp buttons
          ),
        ),
      ],
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
                    const SizedBox(
                      height: 100,
                      child: Center(
                        child: CircularProgressIndicator(),
                      ),
                    )
                  else if (_currentUser != null)
                    _buildProfileView(_currentUser!)
                  else ...[
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Icon(
                              Icons.error_outline,
                              size: 48,
                              color: AppTheme.textSecondary,
                            ),
                            const SizedBox(width: 16),
                            Expanded(
                              child: Text(
                                AppLocalizations.of(context)?.unableToLoadProfileInfo ?? 'Unable to load profile information',
                                style: TextStyle(
                                  color: AppTheme.textSecondary,
                                  fontSize: 16,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),
                        SizedBox(
                          width: 300, // Same width as other buttons
                          child: CustomButton(
                            onPressed: _logout,
                            text: AppLocalizations.of(context)?.logout ?? 'Logout',
                            icon: Icons.logout,
                            showIcon: true,
                            color: AppTheme.errorColor,
                            height: 44, // Same height as WhatsApp buttons
                          ),
                        ),
                      ],
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
                  
                  // WhatsApp Integration Section - COMPLETELY CLEAN
                  WhatsAppIntegrationSection(
                    isConfigured: _isWhatsAppConfigured,
                    isLoading: _isWhatsAppLoading,
                    onSetupPressed: _showSetupDialog,
                    onCredentialsPressed: _showCredentialsDialog,
                    onTemplatesPressed: _showTemplatesDialog,
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
}
