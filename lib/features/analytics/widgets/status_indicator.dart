import 'package:flutter/material.dart';

import '../../../core/theme/app_theme.dart';

class StatusIndicator extends StatelessWidget {
  final Color color;
  final String text;
  final String countText;

  const StatusIndicator({
    super.key,
    required this.color,
    required this.text,
    required this.countText,
  });

  @override
  Widget build(BuildContext context) {
    final statusText = text.substring(0, text.indexOf('(') - 1);
    final percentageText = text.substring(text.indexOf('('));

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Row(
        children: [
          Container(
            width: 10,
            height: 10,
            decoration: BoxDecoration(
              color: color.withOpacity(0.15),
              shape: BoxShape.circle,
              border: Border.all(
                color: color,
                width: 1.5,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              RichText(
                text: TextSpan(
                  style: const TextStyle(
                    fontSize: 14,
                    color: AppTheme.textPrimary,
                    fontFamily: 'Inter',
                  ),
                  children: [
                    TextSpan(text: '$statusText '),
                    TextSpan(
                      text: percentageText,
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w400,
                        color: color,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 2),
              Text(
                countText,
                style: const TextStyle(
                  fontSize: 12,
                  color: AppTheme.textSecondary,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
} 