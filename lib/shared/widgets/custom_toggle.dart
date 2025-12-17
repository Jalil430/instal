import 'package:flutter/material.dart';

import '../../core/theme/app_theme.dart';

class CustomToggleOption<T> {
  final T value;
  final String label;
  final IconData? icon;

  const CustomToggleOption({
    required this.value,
    required this.label,
    this.icon,
  });
}

/// Lightweight toggle control used across filter sheets. Inspired by the
/// analytics section tabs but slimmer for compact layouts.
class CustomToggle<T> extends StatelessWidget {
  final List<CustomToggleOption<T>> options;
  final T value;
  final ValueChanged<T> onChanged;
  final double height;

  const CustomToggle({
    super.key,
    required this.options,
    required this.value,
    required this.onChanged,
    this.height = 32,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppTheme.subtleBackgroundColor,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppTheme.subtleBorderColor),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: options.asMap().entries.map((entry) {
          final index = entry.key;
          final opt = entry.value;
          final isSelected = opt.value == value;
          final radius = BorderRadius.horizontal(
            left: index == 0 ? const Radius.circular(10) : Radius.zero,
            right: index == options.length - 1 ? const Radius.circular(10) : Radius.zero,
          );

          return SizedBox(
            height: height,
            child: TextButton(
              onPressed: () => onChanged(opt.value),
              style: TextButton.styleFrom(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                backgroundColor:
                    isSelected ? AppTheme.subtleAccentColor : Colors.transparent,
                foregroundColor: isSelected ? AppTheme.textPrimary : AppTheme.textSecondary,
                shape: RoundedRectangleBorder(borderRadius: radius),
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                overlayColor: AppTheme.subtleHoverColor,
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (opt.icon != null) ...[
                    Icon(opt.icon, size: 14),
                    const SizedBox(width: 6),
                  ],
                  Text(
                    opt.label,
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                      letterSpacing: 0.1,
                    ),
                  ),
                ],
              ),
            ),
          );
        }).toList(),
      ),
    );
  }
}
