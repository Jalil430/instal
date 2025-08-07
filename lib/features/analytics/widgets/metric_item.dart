import 'package:flutter/material.dart';

import '../../../core/localization/app_localizations.dart';
import '../../../core/theme/app_theme.dart';

class MetricItem extends StatelessWidget {
  final String title;
  final String value;
  final double? change;
  final bool higherIsBetter;
  final bool isCompact;

  const MetricItem({
    super.key,
    required this.title,
    required this.value,
    this.change,
    this.higherIsBetter = true,
    this.isCompact = false,
  });

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    
    final hasChange = change != null;

    bool isGood;
    if (hasChange) {
      if (higherIsBetter) {
        isGood = change! >= 0;
      } else {
        isGood = change! <= 0;
      }
    } else {
      isGood = higherIsBetter;
    }

    final changeText = hasChange ? '${change!.abs().toStringAsFixed(1)}%' : '— %';
    final color = isGood ? AppTheme.successColor : AppTheme.errorColor;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Text(
          title,
          style: const TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w400,
            color: AppTheme.textSecondary,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          value,
          style: TextStyle(
            fontSize: isCompact ? 22 : 27,
            fontWeight: FontWeight.w600,
          ),
        ),
        SizedBox(height: isCompact ? 8 : 16),
        Row(
          children: [
            if (hasChange)
              Icon(
                change! >= 0 ? Icons.arrow_upward : Icons.arrow_downward,
                color: color,
                size: 14,
              ),
            if (hasChange) const SizedBox(width: 4),
            Text(
              changeText,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w400,
                color: hasChange ? color : AppTheme.textSecondary,
              ),
            ),
            if (hasChange) const SizedBox(width: 4),
            Flexible(
              child: Text(
                l10n.vsPreview28days,
                style: const TextStyle(
                  fontSize: 11,
                  color: AppTheme.textSecondary,
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      ],
    );
  }
} 