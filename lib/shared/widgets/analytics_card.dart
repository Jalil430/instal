import 'package:flutter/material.dart';
import '../../core/theme/app_theme.dart';

class AnalyticsCard extends StatelessWidget {
  final Widget child;
  final String? title;
  final Widget? header;
  final double? height;
  final EdgeInsetsGeometry? padding;

  const AnalyticsCard({
    super.key,
    required this.child,
    this.title,
    this.header,
    this.height,
    this.padding,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      height: height,
      decoration: BoxDecoration(
        color: AppTheme.surfaceColor,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: AppTheme.subtleBorderColor,
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.03),
            blurRadius: 10,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (title != null)
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 15, 20, 2),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    title!,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  if (header != null) header!,
                ],
              ),
            ),
          Expanded(
            child: Padding(
              padding: padding ??
                  (title == null
                      ? const EdgeInsets.all(20)
                      : const EdgeInsets.fromLTRB(20, 0, 20, 20)),
              child: child,
            ),
          ),
        ],
      ),
    );
  }
} 