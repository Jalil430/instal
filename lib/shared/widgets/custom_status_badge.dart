import 'package:flutter/material.dart';
import '../../core/theme/app_theme.dart';
import '../../core/localization/app_localizations.dart';

class CustomStatusBadge extends StatelessWidget {
  final String status;
  final double? width;
  final EdgeInsetsGeometry? padding;
  final double fontSize;
  final FontWeight fontWeight;

  const CustomStatusBadge({
    super.key,
    required this.status,
    this.width,
    this.padding,
    this.fontSize = 11,
    this.fontWeight = FontWeight.w400,
  });

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    
    String label;
    Color color;
    Color backgroundColor;

    switch (status) {
      case 'оплачено':
        label = l10n?.paid ?? 'Оплачено';
        color = AppTheme.successColor;
        backgroundColor = AppTheme.successColor.withOpacity(0.1);
        break;
      case 'предстоящий':
        label = l10n?.upcoming ?? 'Предстоящий';
        color = AppTheme.pendingColor;
        backgroundColor = AppTheme.pendingColor.withOpacity(0.1);
        break;
      case 'к оплате':
        label = l10n?.dueToPay ?? 'К оплате';
        color = AppTheme.warningColor;
        backgroundColor = AppTheme.warningColor.withOpacity(0.1);
        break;
      case 'просрочено':
        label = l10n?.overdue ?? 'Просрочено';
        color = AppTheme.errorColor;
        backgroundColor = AppTheme.errorColor.withOpacity(0.1);
        break;
      default:
        label = status;
        color = AppTheme.textSecondary;
        backgroundColor = AppTheme.textSecondary.withOpacity(0.1);
    }

    return Container(
      width: width ?? 110,
      padding: padding ?? const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: color.withOpacity(0.2),
          width: 1,
        ),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: color,
          fontWeight: fontWeight,
          fontSize: fontSize,
        ),
        overflow: TextOverflow.ellipsis,
        textAlign: TextAlign.center,
      ),
    );
  }
}