import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../core/theme/app_theme.dart';

class CustomIconButton extends StatefulWidget {
  final VoidCallback? onPressed;
  final String? routePath;
  final double size;
  final IconData icon;
  final Color? backgroundColor;
  final Color? hoverBackgroundColor;
  final Color? iconColor;
  final Color? hoverIconColor;
  final Color? borderColor;
  final Color? hoverBorderColor;
  final double rotation;
  final bool animate;
  final Duration animationDuration;
  final bool forceHover;
  final bool interactive;

  const CustomIconButton({
    super.key,
    this.onPressed,
    this.routePath,
    this.size = 40,
    this.icon = Icons.arrow_back_rounded,
    this.backgroundColor,
    this.hoverBackgroundColor,
    this.iconColor,
    this.hoverIconColor,
    this.borderColor,
    this.hoverBorderColor,
    this.rotation = 0.0,
    this.animate = true,
    this.animationDuration = const Duration(milliseconds: 200),
    this.forceHover = false,
    this.interactive = true,
  });

  @override
  State<CustomIconButton> createState() => _CustomIconButtonState();
}

class _CustomIconButtonState extends State<CustomIconButton> {
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    final bool isEffectivelyHovered = widget.forceHover || _isHovered;

    // Default colors
    final defaultBackgroundColor = AppTheme.backgroundColor;
    final defaultHoverBackgroundColor = AppTheme.subtleHoverColor;
    final defaultIconColor = AppTheme.textSecondary;
    final defaultHoverIconColor = AppTheme.primaryColor;
    final defaultBorderColor = AppTheme.borderColor.withOpacity(0.5);
    final defaultHoverBorderColor = AppTheme.subtleAccentColor;

    final iconChild = Icon(
      widget.icon,
      color: isEffectivelyHovered
          ? widget.hoverIconColor ?? defaultHoverIconColor
          : widget.iconColor ?? defaultIconColor,
      size: widget.size * 0.5,
    );

    return MouseRegion(
      onEnter: (_) {
        if (widget.interactive) setState(() => _isHovered = true);
      },
      onExit: (_) {
        if (widget.interactive) setState(() => _isHovered = false);
      },
      child: Container(
        width: widget.size,
        height: widget.size,
        decoration: BoxDecoration(
          color: isEffectivelyHovered
              ? widget.hoverBackgroundColor ?? defaultHoverBackgroundColor
              : widget.backgroundColor ?? defaultBackgroundColor,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: isEffectivelyHovered
                ? widget.hoverBorderColor ?? defaultHoverBorderColor
                : widget.borderColor ?? defaultBorderColor,
            width: 1,
          ),
        ),
        child: IgnorePointer(
          ignoring: !widget.interactive,
          child: IconButton(
            icon: widget.animate
                ? TweenAnimationBuilder<double>(
                    tween: Tween(end: widget.rotation),
                    duration: widget.animationDuration,
                    curve: Curves.easeInOut,
                    builder: (context, turns, child) {
                      return Transform.rotate(
                        angle: turns * 2 * math.pi, // Convert turns to radians
                        child: child,
                      );
                    },
                    child: iconChild,
                  )
                : Transform.rotate(
                    angle: widget.rotation * 2 * math.pi,
                    child: iconChild,
                  ),
            onPressed: widget.onPressed ??
                () {
                  if (widget.routePath != null) {
                    context.go(widget.routePath!);
                  }
                },
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(),
            hoverColor: Colors.transparent,
            splashColor: Colors.transparent,
            highlightColor: Colors.transparent,
          ),
        ),
      ),
    );
  }
}