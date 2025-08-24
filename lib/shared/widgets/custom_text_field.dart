import 'package:flutter/material.dart';
import '../../core/theme/app_theme.dart';

class CustomTextField extends StatelessWidget {
  final TextEditingController controller;
  final FocusNode? focusNode;
  final String label;
  final String? hintText;
  final TextInputType? keyboardType;
  final TextInputAction? textInputAction;
  final String? Function(String?)? validator;
  final IconData? prefixIcon;
  final IconData? suffixIcon;
  final VoidCallback? onSuffixIconPressed;
  final bool obscureText;
  final int maxLines;
  final bool enabled;
  final Function(String)? onChanged;
  final Function(String)? onFieldSubmitted;

  const CustomTextField({
    super.key,
    required this.controller,
    this.focusNode,
    required this.label,
    this.hintText,
    this.keyboardType,
    this.textInputAction,
    this.validator,
    this.prefixIcon,
    this.suffixIcon,
    this.onSuffixIconPressed,
    this.obscureText = false,
    this.maxLines = 1,
    this.enabled = true,
    this.onChanged,
    this.onFieldSubmitted,
  });

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      controller: controller,
      focusNode: focusNode,
      keyboardType: keyboardType,
      textInputAction: textInputAction,
      maxLines: maxLines,
      obscureText: obscureText,
      enabled: enabled,
      onChanged: onChanged,
      onFieldSubmitted: onFieldSubmitted,
      style: TextStyle(
        fontSize: 14,
        fontWeight: FontWeight.w400,
        color: AppTheme.textPrimary,
      ),
      decoration: InputDecoration(
        labelText: label,
        hintText: hintText,
        labelStyle: TextStyle(
          color: AppTheme.textSecondary,
          fontSize: 14,
          fontWeight: FontWeight.w400,
        ),
        hintStyle: TextStyle(
          color: AppTheme.textHint,
          fontSize: 14,
          fontWeight: FontWeight.w400,
        ),
        prefixIcon: prefixIcon != null 
            ? Icon(prefixIcon, color: AppTheme.textSecondary, size: 20) 
            : null,
        suffixIcon: suffixIcon != null 
            ? IconButton(
                icon: Icon(suffixIcon, color: AppTheme.textSecondary, size: 20),
                onPressed: onSuffixIconPressed,
              )
            : null,
        filled: true,
        fillColor: Colors.white,
        hoverColor: Color.lerp(AppTheme.surfaceColor, AppTheme.backgroundColor, 0.6),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: AppTheme.borderColor),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: AppTheme.borderColor),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: AppTheme.primaryColor, width: 2),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: AppTheme.errorColor),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: AppTheme.errorColor, width: 2),
        ),
        disabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: AppTheme.borderColor.withOpacity(0.5)),
        ),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      ),
      validator: validator,
    );
  }
} 