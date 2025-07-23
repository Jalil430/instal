import 'package:flutter/material.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/localization/app_localizations.dart';
import '../../../../shared/widgets/custom_button.dart';

class WhatsAppIntegrationSection extends StatelessWidget {
  final bool isConfigured;
  final bool isLoading;
  final VoidCallback onSetupPressed;
  final VoidCallback onCredentialsPressed;
  final VoidCallback onTemplatesPressed;

  const WhatsAppIntegrationSection({
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
        // Title - matching the style from language section
        Text(
          AppLocalizations.of(context)?.whatsAppIntegration ?? 'WhatsApp Integration',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w500,
            color: AppTheme.textPrimary,
          ),
        ),
        const SizedBox(height: 16),
        
        // Conditional content based on configuration status
        if (!isConfigured) 
          SizedBox(
            width: 350, // Same width as language dropdown
            child: CustomButton(
              onPressed: onSetupPressed,
              text: AppLocalizations.of(context)?.setUpWhatsAppIntegration ?? 'Set Up WhatsApp Integration',
              icon: Icons.settings,
              showIcon: true,
              height: 44,
            ),
          )
        else ...[
          // Buttons - same width and style
          SizedBox(
            width: 350, // Same width as language dropdown
            child: CustomButton(
              onPressed: onCredentialsPressed,
              text: AppLocalizations.of(context)?.changeCredentials ?? 'Change Credentials',
              icon: Icons.key,
              showIcon: true,
              height: 44,
            ),
          ),
          const SizedBox(height: 12),
          SizedBox(
            width: 350, // Same width as language dropdown
            child: CustomButton(
              onPressed: onTemplatesPressed,
              text: AppLocalizations.of(context)?.changeTemplates ?? 'Change Templates',
              icon: Icons.message,
              showIcon: true,
              height: 44,
            ),
          ),
          // No switch section
        ],
      ],
    );
  }
}
