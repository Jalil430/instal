import 'package:flutter/material.dart';
import '../../core/theme/app_theme.dart';

class CustomButton extends StatelessWidget {
  final String text;
  final VoidCallback? onPressed;
  final IconData icon;
  final double? width;
  final double height;
  final double fontSize;
  final FontWeight fontWeight;
  final EdgeInsetsGeometry padding;
  final bool showIcon;
  final bool iconRight;
  final Color? color;

  const CustomButton({
    super.key,
    required this.text,
    required this.onPressed,
    this.icon = Icons.add_rounded,
    this.width,
    this.height = 40,
    this.fontSize = 14,
    this.fontWeight = FontWeight.w500,
    this.padding = const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
    this.showIcon = true,
    this.iconRight = false,
    this.color,
  });

  @override
  Widget build(BuildContext context) {
    final iconWidget = Icon(icon, size: fontSize == 16 ? 20 : 18);
    final textWidget = Text(text);
    final backgroundColor = color ?? AppTheme.brightPrimaryColor;
    return SizedBox(
      width: width,
      height: height,
      child: showIcon
          ? ElevatedButton(
              onPressed: onPressed,
              style: ElevatedButton.styleFrom(
                backgroundColor: backgroundColor,
                foregroundColor: Colors.white,
                elevation: 0,
                shadowColor: Colors.transparent,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                padding: padding,
                textStyle: TextStyle(
                  fontSize: fontSize,
                  fontWeight: fontWeight,
                ),
              ),
              child: iconRight
                  ? Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        textWidget,
                        const SizedBox(width: 8),
                        iconWidget,
                      ],
                    )
                  : Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        iconWidget,
                        const SizedBox(width: 8),
                        textWidget,
                      ],
                    ),
            )
          : ElevatedButton(
              onPressed: onPressed,
              style: ElevatedButton.styleFrom(
                backgroundColor: backgroundColor,
                foregroundColor: Colors.white,
                elevation: 0,
                shadowColor: Colors.transparent,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                padding: padding,
                textStyle: TextStyle(
                  fontSize: fontSize,
                  fontWeight: fontWeight,
                ),
              ),
              child: textWidget,
            ),
    );
  }
} 