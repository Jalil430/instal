import 'package:flutter/material.dart';
import '../../core/theme/app_theme.dart';

class AppLogo extends StatelessWidget {
  final double size;
  final bool showBackground;
  final Color? backgroundColor;
  final double borderRadius;

  const AppLogo({
    Key? key,
    this.size = 80,
    this.showBackground = true,
    this.backgroundColor,
    this.borderRadius = 16,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final Widget logoImage = ClipRRect(
      borderRadius: BorderRadius.circular(borderRadius),
      child: Image.asset(
        'assets/icons/instal-app-logo-rounded.png',
        width: size,
        height: size,
        fit: BoxFit.cover,
        errorBuilder: (context, error, stackTrace) {
          // Fallback to wallet icon if image fails to load
          return Container(
            width: size,
            height: size,
            decoration: BoxDecoration(
              color: backgroundColor ?? AppTheme.primaryColor,
              borderRadius: BorderRadius.circular(borderRadius),
            ),
            child: Icon(
              Icons.account_balance_wallet_rounded,
              color: Colors.white,
              size: size * 0.5,
            ),
          );
        },
      ),
    );

    if (!showBackground) {
      return logoImage;
    }

    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: backgroundColor ?? AppTheme.primaryColor,
        borderRadius: BorderRadius.circular(borderRadius),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: logoImage,
    );
  }
}