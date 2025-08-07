import 'package:flutter/material.dart';
import '../../../../shared/widgets/responsive_layout.dart';
import 'desktop/whatsapp_connection_status_desktop.dart';
import 'mobile/whatsapp_connection_status_mobile.dart';

class WhatsAppConnectionStatus extends StatelessWidget {
  final Map<String, dynamic> testResult;

  const WhatsAppConnectionStatus({
    super.key,
    required this.testResult,
  });

  @override
  Widget build(BuildContext context) {
    return ResponsiveLayout(
      desktop: WhatsAppConnectionStatusDesktop(testResult: testResult),
      mobile: WhatsAppConnectionStatusMobile(testResult: testResult),
    );
  }
}