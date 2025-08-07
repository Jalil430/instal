import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../auth/presentation/widgets/auth_service_provider.dart';
import '../auth/domain/entities/user.dart';
import '../../shared/widgets/edit_profile_dialog.dart';
import '../../shared/widgets/responsive_layout.dart';
import 'data/services/whatsapp_api_service.dart';
import 'presentation/widgets/whatsapp_setup_dialog.dart';
import 'presentation/widgets/whatsapp_credentials_dialog.dart';
import 'presentation/widgets/whatsapp_templates_dialog.dart';
import '../../main.dart';
import '../../core/localization/app_localizations.dart';
import 'screens/desktop/settings_screen_desktop.dart';
import 'screens/mobile/settings_screen_mobile.dart';

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
  
  // WhatsApp settings state
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
        backgroundColor: Colors.green,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }
  
  void _showErrorSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red,
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
            backgroundColor: Colors.red,
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
            backgroundColor: Colors.red,
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

  @override
  Widget build(BuildContext context) {
    return ResponsiveLayout(
      mobile: SettingsScreenMobile(
        currentUser: _currentUser,
        loadingUser: _loadingUser,
        selectedLanguage: _selectedLanguage,
        isWhatsAppConfigured: _isWhatsAppConfigured,
        isWhatsAppLoading: _isWhatsAppLoading,
        onEditProfilePressed: _showEditProfileDialog,
        onLogoutPressed: _logout,
        onLanguageChanged: _changeLanguage,
        onSetupPressed: _showSetupDialog,
        onCredentialsPressed: _showCredentialsDialog,
        onTemplatesPressed: _showTemplatesDialog,
      ),
      desktop: SettingsScreenDesktop(
        currentUser: _currentUser,
        loadingUser: _loadingUser,
        selectedLanguage: _selectedLanguage,
        isWhatsAppConfigured: _isWhatsAppConfigured,
        isWhatsAppLoading: _isWhatsAppLoading,
        onEditProfilePressed: _showEditProfileDialog,
        onLogoutPressed: _logout,
        onLanguageChanged: _changeLanguage,
        onSetupPressed: _showSetupDialog,
        onCredentialsPressed: _showCredentialsDialog,
        onTemplatesPressed: _showTemplatesDialog,
      ),
    );
  }
}
