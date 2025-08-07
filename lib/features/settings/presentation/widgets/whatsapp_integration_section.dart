import 'package:flutter/material.dart';
import '../../../../shared/widgets/responsive_layout.dart';
import 'desktop/whatsapp_integration_section_desktop.dart';
import 'mobile/whatsapp_integration_section_mobile.dart';

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
    return ResponsiveLayout(
      desktop: WhatsAppIntegrationSectionDesktop(
        isConfigured: isConfigured,
        isLoading: isLoading,
        onSetupPressed: onSetupPressed,
        onCredentialsPressed: onCredentialsPressed,
        onTemplatesPressed: onTemplatesPressed,
      ),
      mobile: WhatsAppIntegrationSectionMobile(
        isConfigured: isConfigured,
        isLoading: isLoading,
        onSetupPressed: onSetupPressed,
        onCredentialsPressed: onCredentialsPressed,
        onTemplatesPressed: onTemplatesPressed,
      ),
    );
  }
}
