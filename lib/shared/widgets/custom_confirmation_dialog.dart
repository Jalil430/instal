import 'package:flutter/material.dart';
import '../../core/theme/app_theme.dart';
import 'custom_button.dart';
import '../../core/localization/app_localizations.dart';
import 'responsive_layout.dart';
import 'dialogs/desktop/custom_confirmation_dialog_desktop.dart';
import 'dialogs/mobile/custom_confirmation_dialog_mobile.dart';

class CustomConfirmationDialog extends StatelessWidget {
  final String title;
  final String content;
  final String confirmText;
  final String cancelText;
  final Color confirmColor;
  final IconData confirmIcon;
  final VoidCallback? onConfirmed;
  final VoidCallback? onCancelled;

  const CustomConfirmationDialog({
    super.key,
    required this.title,
    required this.content,
    this.confirmText = 'Удалить',
    this.cancelText = 'Отмена',
    this.confirmColor = AppTheme.errorColor,
    this.confirmIcon = Icons.keyboard_return_rounded,
    this.onConfirmed,
    this.onCancelled,
  });

  @override
  Widget build(BuildContext context) {
    return ResponsiveLayout(
      desktop: CustomConfirmationDialogDesktop(
        title: title,
        content: content,
        confirmText: confirmText,
        cancelText: cancelText,
        confirmColor: confirmColor,
        confirmIcon: confirmIcon,
        onConfirmed: onConfirmed,
        onCancelled: onCancelled,
      ),
      mobile: CustomConfirmationDialogMobile(
        title: title,
        content: content,
        confirmText: confirmText,
        cancelText: cancelText,
        confirmColor: confirmColor,
        confirmIcon: confirmIcon,
        onConfirmed: onConfirmed,
        onCancelled: onCancelled,
      ),
    );
  }
}

Future<bool?> showCustomConfirmationDialog({
  required BuildContext context,
  required String title,
  required String content,
  String? confirmText,
  String? cancelText,
  Color confirmColor = AppTheme.errorColor,
  IconData confirmIcon = Icons.keyboard_return_rounded,
}) {
  final l10n = AppLocalizations.of(context)!;
  return showDialog<bool>(
    context: context,
    builder: (context) => CustomConfirmationDialog(
      title: title,
      content: content,
      confirmText: confirmText ?? l10n.delete,
      cancelText: cancelText ?? l10n.cancel,
      confirmColor: confirmColor,
      confirmIcon: confirmIcon,
    ),
  );
} 