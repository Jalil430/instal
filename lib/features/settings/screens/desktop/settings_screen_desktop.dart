import 'package:flutter/material.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/localization/app_localizations.dart';
import '../../../../shared/widgets/custom_button.dart';
import '../../../../shared/widgets/custom_dropdown.dart';
import '../../../auth/domain/entities/user.dart';
import '../../presentation/widgets/whatsapp_integration_section.dart';
import '../../../../core/services/update_service.dart';

class SettingsScreenDesktop extends StatelessWidget {
  final User? currentUser;
  final bool loadingUser;
  final String selectedLanguage;
  final bool isWhatsAppConfigured;
  final bool isWhatsAppLoading;
  final VoidCallback onEditProfilePressed;
  final VoidCallback onLogoutPressed;
  final Function(String) onLanguageChanged;
  final VoidCallback onSetupPressed;
  final VoidCallback onCredentialsPressed;
  final VoidCallback onTemplatesPressed;

  const SettingsScreenDesktop({
    Key? key,
    required this.currentUser,
    required this.loadingUser,
    required this.selectedLanguage,
    required this.isWhatsAppConfigured,
    required this.isWhatsAppLoading,
    required this.onEditProfilePressed,
    required this.onLogoutPressed,
    required this.onLanguageChanged,
    required this.onSetupPressed,
    required this.onCredentialsPressed,
    required this.onTemplatesPressed,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;

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
                  l10n.settings,
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
                  // Updates Section
                  Text(
                    'Updates',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w500,
                      color: AppTheme.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 12),
                  SizedBox(
                    width: 250,
                    child: CustomButton(
                      onPressed: () async {
                        await UpdateService.checkForUpdates();
                      },
                      text: 'Check for updates',
                      icon: Icons.system_update,
                      showIcon: true,
                      height: 44,
                    ),
                  ),
                  const SizedBox(height: 32),
                  // Profile Section
                  Text(
                    l10n.profile,
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w500,
                      color: AppTheme.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 16),
                  if (loadingUser)
                    const SizedBox(
                      height: 100,
                      child: Center(
                        child: CircularProgressIndicator(),
                      ),
                    )
                  else if (currentUser != null)
                    _buildProfileView(context, currentUser!)
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
                                l10n.unableToLoadProfileInfo,
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
                            onPressed: onLogoutPressed,
                            text: l10n.logout,
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
                    l10n.language,
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w500,
                      color: AppTheme.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 16),
                  CustomDropdown<String>(
                    value: selectedLanguage,
                    items: {
                      'ru': l10n.languageRussian,
                      'en': l10n.languageEnglish,
                    },
                    onChanged: (String? newValue) {
                      if (newValue != null) {
                        onLanguageChanged(newValue);
                      }
                    },
                    width: 250,
                  ),
                  const SizedBox(height: 32),
                  
                  // WhatsApp Integration Section
                  WhatsAppIntegrationSection(
                    isConfigured: isWhatsAppConfigured,
                    isLoading: isWhatsAppLoading,
                    onSetupPressed: onSetupPressed,
                    onCredentialsPressed: onCredentialsPressed,
                    onTemplatesPressed: onTemplatesPressed,
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

  Widget _buildProfileView(BuildContext context, User user) {
    final l10n = AppLocalizations.of(context)!;
    
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
            onPressed: onEditProfilePressed,
            text: l10n.editProfile,
            icon: Icons.edit,
            showIcon: true,
            height: 44, // Same height as WhatsApp buttons
          ),
        ),
        const SizedBox(height: 12),
        SizedBox(
          width: 350, // Same width as language dropdown and WhatsApp buttons
          child: CustomButton(
            onPressed: onLogoutPressed,
            text: l10n.logout,
            icon: Icons.logout,
            showIcon: true,
            color: AppTheme.errorColor,
            height: 44, // Same height as WhatsApp buttons
          ),
        ),
      ],
    );
  }
} 