import 'package:flutter/material.dart';
import '../../core/theme/app_theme.dart';

class CustomAddButton extends StatelessWidget {
  final String text;
  final VoidCallback onPressed;
  final IconData icon;
  final double? width;
  final double height;
  final double fontSize;
  final FontWeight fontWeight;
  final EdgeInsetsGeometry padding;

  const CustomAddButton({
    super.key,
    required this.text,
    required this.onPressed,
    this.icon = Icons.add_rounded,
    this.width,
    this.height = 44,
    this.fontSize = 14,
    this.fontWeight = FontWeight.w500,
    this.padding = const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: width,
      height: height,
      child: ElevatedButton.icon(
        onPressed: onPressed,
        icon: Icon(icon, size: fontSize == 16 ? 20 : 18),
        label: Text(text),
        style: ElevatedButton.styleFrom(
          backgroundColor: AppTheme.brightPrimaryColor,
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
      ),
    );
  }
} 