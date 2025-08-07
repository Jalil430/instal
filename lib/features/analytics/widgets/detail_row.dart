import 'package:flutter/material.dart';
import '../../../core/theme/app_theme.dart';

class DetailRow extends StatelessWidget {
  final String label;
  final String value;
  final bool isCompact;

  const DetailRow({
    super.key,
    required this.label,
    required this.value,
    this.isCompact = false,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: isCompact ? 12 : 14,
            color: AppTheme.textSecondary,
          ),
        ),
        Text(
          value,
          style: TextStyle(
            fontSize: isCompact ? 13 : 15,
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }
} 