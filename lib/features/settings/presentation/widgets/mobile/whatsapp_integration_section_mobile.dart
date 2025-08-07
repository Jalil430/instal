import 'package:flutter/material.dart';
import '../../../../../core/theme/app_theme.dart';
import '../../../../../core/localization/app_localizations.dart';
import '../../../../../shared/widgets/custom_button.dart';

class WhatsAppIntegrationSectionMobile extends StatelessWidget {
  final bool isConfigured;
  final bool isLoading;
  final VoidCallback onSetupPressed;
  final VoidCallback onCredentialsPressed;
  final VoidCallback onTemplatesPressed;

  const WhatsAppIntegrationSectionMobile({
    super.key,
    required this.isConfigured,
    this.isLoading = false,
    required this.onSetupPressed,
    required this.onCredentialsPressed,
    required this.onTemplatesPressed,
  });

  @override
  Widget build(BuildContext context) {
    if (isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Title
        Text(
          AppLocalizations.of(context)?.whatsAppIntegration ?? 'WhatsApp Integration',
          style: TextStyle(
            fontSize: 15, // Slightly smaller for mobile
            fontWeight: FontWeight.w500,
            color: AppTheme.textPrimary,
          ),
        ),
        const SizedBox(height: 12), // Less space for mobile
        
        // Conditional content based on configuration status
        if (!isConfigured) 
          // Full width button for mobile
          CustomButton(
            onPressed: onSetupPressed,
            text: AppLocalizations.of(context)?.setUpWhatsAppIntegration ?? 'Set Up WhatsApp Integration',
            icon: Icons.settings,
            showIcon: true,
            height: 44,
            width: double.infinity,
          )
        else ...[
          // Vertical stacked buttons for mobile
          CustomButton(
            onPressed: onCredentialsPressed,
            text: AppLocalizations.of(context)?.changeCredentials ?? 'Change Credentials',
            icon: Icons.key,
            showIcon: true,
            height: 44,
            width: double.infinity,
          ),
          const SizedBox(height: 12), // Spacing between buttons
          CustomButton(
            onPressed: onTemplatesPressed,
            text: AppLocalizations.of(context)?.changeTemplates ?? 'Change Templates',
            icon: Icons.message,
            showIcon: true,
            height: 44,
            width: double.infinity,
          ),
        ],
      ],
    );
  }
} 