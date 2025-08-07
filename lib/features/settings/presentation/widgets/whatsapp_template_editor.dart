import 'package:flutter/material.dart';
import '../../../../shared/widgets/responsive_layout.dart';
import 'desktop/whatsapp_template_editor_desktop.dart';
import 'mobile/whatsapp_template_editor_mobile.dart';

class WhatsAppTemplateEditor extends StatelessWidget {
  final TextEditingController template7DaysController;
  final TextEditingController templateDueTodayController;
  final TextEditingController templateManualController;

  const WhatsAppTemplateEditor({
    super.key,
    required this.template7DaysController,
    required this.templateDueTodayController,
    required this.templateManualController,
  });

  @override
  Widget build(BuildContext context) {
    return ResponsiveLayout(
      desktop: WhatsAppTemplateEditorDesktop(
        template7DaysController: template7DaysController,
        templateDueTodayController: templateDueTodayController,
        templateManualController: templateManualController,
      ),
      mobile: WhatsAppTemplateEditorMobile(
        template7DaysController: template7DaysController,
        templateDueTodayController: templateDueTodayController,
        templateManualController: templateManualController,
      ),
    );
  }
}