import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../core/theme/app_theme.dart';
import 'custom_button.dart';
import '../../core/localization/app_localizations.dart';

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
    bool enterPressed = false;
    return RawKeyboardListener(
      autofocus: true,
      focusNode: FocusNode(),
      onKey: (event) {
        if (event is RawKeyDownEvent && event.logicalKey == LogicalKeyboardKey.enter && !enterPressed) {
          enterPressed = true;
          Navigator.of(context).pop(true);
          onConfirmed?.call();
        }
      },
      child: AlertDialog(
        title: Text(
          title,
          style: const TextStyle(
            fontSize: 20,
            fontWeight: AppTheme.fontWeightSemiBold,
          ),
        ),
        content: Text(
          content,
          style: const TextStyle(
            fontSize: AppTheme.fontSizeMedium,
            color: AppTheme.textPrimary,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.of(context).pop(false);
              onCancelled?.call();
            },
            style: TextButton.styleFrom(
              foregroundColor: AppTheme.textSecondary,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            ),
            child: Text(
              cancelText,
              style: const TextStyle(
                fontSize: AppTheme.fontSizeMedium,
                fontWeight: AppTheme.fontWeightMedium,
              ),
            ),
          ),
          CustomButton(
            onPressed: () {
              Navigator.of(context).pop(true);
              onConfirmed?.call();
            },
            text: confirmText,
            icon: confirmIcon,
            iconRight: true,
            showIcon: true,
            fontSize: AppTheme.fontSizeMedium,
            fontWeight: AppTheme.fontWeightMedium,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            color: confirmColor,
          ),
        ],
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppTheme.borderRadiusMedium),
        ),
        contentPadding: const EdgeInsets.fromLTRB(24, 20, 24, 24),
        titlePadding: const EdgeInsets.fromLTRB(24, 24, 24, 0),
        actionsPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
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