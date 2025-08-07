import 'package:flutter/material.dart';
import '../../../core/theme/app_theme.dart';

class StatusIndicator extends StatelessWidget {
  final Color color;
  final String text;
  final String countText;
  final bool isCompact;

  const StatusIndicator({
    super.key,
    required this.color,
    required this.text,
    required this.countText,
    this.isCompact = false,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.symmetric(vertical: isCompact ? 2.0 : 4.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Container(
            width: isCompact ? 9 : 10,
            height: isCompact ? 9 : 10,
            decoration: BoxDecoration(
              color: color,
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: color.withOpacity(0.3),
                  blurRadius: 4,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
          ),
          SizedBox(width: isCompact ? 6 : 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  text,
                  style: TextStyle(
                    fontSize: isCompact ? 11 : 14,
                    fontWeight: FontWeight.w500,
                    height: isCompact ? 1.1 : 1.2,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                if (!isCompact) const SizedBox(height: 2),
                Text(
                  countText,
                  style: TextStyle(
                    fontSize: isCompact ? 10 : 12,
                    color: Colors.grey[600],
                    height: isCompact ? 1.0 : 1.2,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
} 