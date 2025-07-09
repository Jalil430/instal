import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../core/theme/app_theme.dart';
import '../../core/localization/app_localizations.dart';
import '../../main.dart';
import '../../shared/widgets/custom_button.dart';
import '../../shared/widgets/custom_dropdown.dart';
import '../auth/presentation/widgets/auth_service_provider.dart';
import '../auth/domain/entities/user.dart';
import 'presentation/profile_edit_screen.dart';

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

  @override
  void initState() {
    super.initState();
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
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
} 