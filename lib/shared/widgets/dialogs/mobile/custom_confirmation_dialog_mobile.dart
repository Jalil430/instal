import 'package:flutter/material.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../widgets/custom_button.dart';

class CustomConfirmationDialogMobile extends StatelessWidget {
  final String title;
  final String content;
  final String confirmText;
  final String cancelText;
  final Color confirmColor;
  final IconData confirmIcon;
  final VoidCallback? onConfirmed;
  final VoidCallback? onCancelled;

  const CustomConfirmationDialogMobile({
    super.key,
    required this.title,
    required this.content,
    required this.confirmText,
    required this.cancelText,
    required this.confirmColor,
    required this.confirmIcon,
    this.onConfirmed,
    this.onCancelled,
  });

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(
        title,
        style: const TextStyle(
          fontSize: 18, // Smaller font for mobile
          fontWeight: AppTheme.fontWeightSemiBold,
        ),
      ),
      content: Text(
        content,
        style: const TextStyle(
          fontSize: AppTheme.fontSizeSmall, // Smaller font for mobile
          color: AppTheme.textPrimary,
        ),
      ),
      // Column layout for mobile to stack buttons vertically
      actions: [
        SizedBox(
          width: double.infinity,
          child: CustomButton(
            onPressed: () {
              Navigator.of(context).pop(true);
              onConfirmed?.call();
            },
            text: confirmText,
            icon: confirmIcon,
            iconRight: true,
            showIcon: true,
            fontSize: AppTheme.fontSizeSmall,
            fontWeight: AppTheme.fontWeightMedium,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            color: confirmColor,
          ),
        ),
        const SizedBox(height: 8),
        SizedBox(
          width: double.infinity,
          child: TextButton(
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
                fontSize: AppTheme.fontSizeSmall,
                fontWeight: AppTheme.fontWeightMedium,
              ),
            ),
          ),
        ),
      ],
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppTheme.borderRadiusSmall),
      ),
      contentPadding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
      titlePadding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
      // Wider padding for mobile to accommodate the column layout
      actionsPadding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
      // Adapt to mobile screen size
      insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
    );
  }
} 