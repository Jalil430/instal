import 'package:flutter/material.dart';
import '../../core/theme/app_theme.dart';

class CustomSearchBar extends StatefulWidget {
  final String value;
  final ValueChanged<String> onChanged;
  final String hintText;
  final double? width;
  final double height;
  final IconData? icon;
  final TextEditingController? controller;

  const CustomSearchBar({
    super.key,
    required this.value,
    required this.onChanged,
    required this.hintText,
    this.width,
    this.height = 44,
    this.icon,
    this.controller,
  });

  @override
  State<CustomSearchBar> createState() => _CustomSearchBarState();
}

class _CustomSearchBarState extends State<CustomSearchBar> {
  bool _isHovered = false;
  late TextEditingController _controller;

  @override
  void initState() {
    super.initState();
    _controller = widget.controller ?? TextEditingController(text: widget.value);
  }

  @override
  void dispose() {
    if (widget.controller == null) {
      _controller.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        width: widget.width ?? 320,
        height: widget.height,
        child: TextField(
          controller: _controller,
          onChanged: widget.onChanged,
          decoration: InputDecoration(
            hintText: widget.hintText,
            hintStyle: TextStyle(
              color: AppTheme.textHint,
              fontSize: 14,
            ),
            prefixIcon: Container(
              padding: const EdgeInsets.all(12),
              child: Icon(
                widget.icon ?? Icons.search_rounded,
                size: 20,
                color: AppTheme.textHint,
              ),
            ),
            filled: true,
            fillColor: _isHovered 
                ? AppTheme.subtleHoverColor
                : AppTheme.subtleBackgroundColor,
            hoverColor: Colors.transparent, // Disable built-in hover
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(
                color: _isHovered 
                    ? AppTheme.subtleAccentColor
                    : AppTheme.subtleBorderColor,
                width: 1,
              ),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(
                color: _isHovered 
                    ? AppTheme.subtleAccentColor
                    : AppTheme.subtleBorderColor,
                width: 1,
              ),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(
                color: AppTheme.primaryColor,
                width: 2,
              ),
            ),
            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          ),
        ),
      ),
    );
  }
} 