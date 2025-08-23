import 'package:flutter/material.dart';

class AppTheme {
  // Colors
  static const Color primaryColor = Color(0xFF2196F3); // Modern blue
  static const Color primaryDark = Color(0xFF1976D2);
  static const Color primaryLight = Color(0xFF64B5F6);
  static const Color accentColor = Color(0xFF00BCD4); // Cyan accent
  
  // Background colors
  static const Color backgroundColor = Color(0xFFF5F7FA);
  static const Color surfaceColor = Colors.white;
  static const Color cardColor = Colors.white;
  
  // Text colors
  static const Color textPrimary = Color(0xFF1A1A1A);
  static const Color textSecondary = Color(0xFF6B7280);
  static const Color textHint = Color(0xFF9CA3AF);
  
  // Status colors
  static const Color successColor = Color(0xFF10B981);
  static const Color warningColor = Color(0xFFF59E0B);
  static const Color errorColor = Color(0xFFEF4444);
  static const Color infoColor = Color(0xFF3B82F6); // Blue for information
  static const Color pendingColor = primaryColor; // Use primary color for consistent blue
  
  // Border and divider colors
  static const Color borderColor = Color(0xFFE5E7EB);
  static const Color dividerColor = Color(0xFFF3F4F6);
  
  // Subtle Element Design Pattern
  // Use these for consistent styling of interactive elements like search bars, 
  // dropdowns, buttons, and table headers that need subtle primary color styling
  static Color get subtleBackgroundColor => primaryColor.withOpacity(0.04);
  static Color get subtleBorderColor => primaryColor.withOpacity(0.1);
  
  // Alternative for hover states and more emphasis
  static Color get subtleHoverColor => primaryColor.withOpacity(0.08);
  static Color get subtleAccentColor => primaryColor.withOpacity(0.15);
  
  // Bright and Standing Out Elements Design Pattern
  // Use these for elements that need to draw attention and stand out prominently
  static Color get brightPrimaryColor => primaryColor; // Full intensity primary color
  static Color get brightSecondaryColor => primaryDark; // Darker variant for depth
  static Color get brightAccentColor => accentColor; // Accent color for special highlights
  
  // Interactive bright elements (buttons, links, CTAs)
  static Color get interactiveBrightColor => primaryColor;
  static Color get interactiveBrightHover => primaryDark;
  static Color get interactiveBrightShadow => primaryColor.withOpacity(0.3);
  
  // Sidebar colors
  static const Color sidebarBackground = Color(0xFF1F2937);
  static const Color sidebarIconColor = Color(0xFF9CA3AF);
  static const Color sidebarIconActiveColor = Colors.white;
  static const Color sidebarHoverColor = Color(0xFF374151);
  
  // Table and List row colors
  static Color get tableHeaderBackground => subtleBackgroundColor;
  static Color get tableRowHoverBackground => backgroundColor.withOpacity(0.6);
  static Color get tableRowExpandedBackground => const Color(0xFFF8F9FA);
  static Color get tableRowBorderColor => borderColor.withOpacity(0.3);
  
  // Typography sizes based on design patterns
  static const double fontSizeLarge = 16.0;
  static const double fontSizeMedium = 14.0;
  static const double fontSizeMiddle = 13.0;
  static const double fontSizeSmall = 12.0;
  
  // Font weights based on design patterns
  static const FontWeight fontWeightRegular = FontWeight.w400;
  static const FontWeight fontWeightMedium = FontWeight.w500;
  static const FontWeight fontWeightSemiBold = FontWeight.w600;
  
  // Standard spacing values (8px grid)
  static const double spacingXxs = 4.0;
  static const double spacingXs = 8.0;
  static const double spacingSm = 12.0;
  static const double spacingMd = 16.0;
  static const double spacingLg = 20.0;
  static const double spacingXl = 24.0;
  static const double spacingXxl = 28.0;
  static const double spacingHuge = 32.0;
  
  // Standard border radius values
  static const double borderRadiusSmall = 6.0;
  static const double borderRadiusMedium = 8.0;
  static const double borderRadiusLarge = 12.0;
  static const double borderRadiusLg = 16.0;
  
  // Animation durations
  static const Duration animationQuick = Duration(milliseconds: 150);
  static const Duration animationStandard = Duration(milliseconds: 200);
  static const Duration animationLong = Duration(milliseconds: 300);
  
  // Fixed element sizes
  static const double statusBadgeWidth = 110.0;
  static const double searchBarWidth = 320.0;
  static const double dropdownWidth = 200.0;
  static const double smallButtonSize = 28.0;
  
  // Standard shadows
  static List<BoxShadow> get subtleShadow => [
    BoxShadow(
      color: Colors.black.withOpacity(0.02),
      offset: const Offset(0, 1),
      blurRadius: 3,
      spreadRadius: 0,
    ),
  ];
  
  static List<BoxShadow> get mediumShadow => [
    BoxShadow(
      color: Colors.black.withOpacity(0.05),
      offset: const Offset(0, 2),
      blurRadius: 8,
      spreadRadius: 0,
    ),
  ];
  
  static List<BoxShadow> get hoverShadow => [
    BoxShadow(
      color: primaryColor.withOpacity(0.08),
      offset: const Offset(0, 2),
      blurRadius: 8,
      spreadRadius: 0,
    ),
  ];
  
  static ThemeData lightTheme = ThemeData(
    useMaterial3: true,
    colorScheme: ColorScheme.fromSeed(
      seedColor: primaryColor,
      primary: primaryColor,
      secondary: accentColor,
      surface: surfaceColor,
      background: backgroundColor,
      error: errorColor,
    ),
    scaffoldBackgroundColor: backgroundColor,
    appBarTheme: const AppBarTheme(
      backgroundColor: surfaceColor,
      elevation: 0,
      centerTitle: false,
      iconTheme: IconThemeData(color: textPrimary),
      titleTextStyle: TextStyle(
        color: textPrimary,
        fontSize: 20,
        fontWeight: FontWeight.w600,
        fontFamily: 'Inter',
      ),
    ),
    cardTheme: CardThemeData(
      color: cardColor,
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(borderRadiusLarge),
        side: const BorderSide(color: borderColor, width: 1),
      ),
    ),
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        backgroundColor: primaryColor,
        foregroundColor: Colors.white,
        elevation: 0,
        padding: const EdgeInsets.symmetric(horizontal: spacingXl, vertical: spacingSm),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(borderRadiusMedium),
        ),
        textStyle: const TextStyle(
          fontSize: fontSizeLarge,
          fontWeight: fontWeightMedium,
          fontFamily: 'Inter',
        ),
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        foregroundColor: primaryColor,
        side: const BorderSide(color: primaryColor),
        padding: const EdgeInsets.symmetric(horizontal: spacingXl, vertical: spacingSm),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(borderRadiusMedium),
        ),
        textStyle: const TextStyle(
          fontSize: fontSizeLarge,
          fontWeight: fontWeightMedium,
          fontFamily: 'Inter',
        ),
      ),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: Colors.white,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(borderRadiusMedium),
        borderSide: const BorderSide(color: borderColor),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(borderRadiusMedium),
        borderSide: const BorderSide(color: borderColor),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(borderRadiusMedium),
        borderSide: const BorderSide(color: primaryColor, width: 2),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(borderRadiusMedium),
        borderSide: const BorderSide(color: errorColor),
      ),
      contentPadding: const EdgeInsets.symmetric(horizontal: spacingMd, vertical: spacingSm),
      hintStyle: const TextStyle(color: textHint),
    ),
    dividerTheme: const DividerThemeData(
      color: dividerColor,
      thickness: 1,
    ),
    textTheme: const TextTheme(
      headlineLarge: TextStyle(
        fontSize: 32,
        fontWeight: fontWeightSemiBold,
        color: textPrimary,
        fontFamily: 'Inter',
      ),
      headlineMedium: TextStyle(
        fontSize: 24,
        fontWeight: fontWeightSemiBold,
        color: textPrimary,
        fontFamily: 'Inter',
      ),
      headlineSmall: TextStyle(
        fontSize: 20,
        fontWeight: fontWeightSemiBold,
        color: textPrimary,
        fontFamily: 'Inter',
      ),
      titleLarge: TextStyle(
        fontSize: 18,
        fontWeight: fontWeightSemiBold,
        color: textPrimary,
        fontFamily: 'Inter',
      ),
      titleMedium: TextStyle(
        fontSize: fontSizeLarge,
        fontWeight: fontWeightMedium,
        color: textPrimary,
        fontFamily: 'Inter',
      ),
      titleSmall: TextStyle(
        fontSize: fontSizeMedium,
        fontWeight: fontWeightMedium,
        color: textPrimary,
        fontFamily: 'Inter',
      ),
      bodyLarge: TextStyle(
        fontSize: fontSizeLarge,
        fontWeight: fontWeightRegular,
        color: textPrimary,
        fontFamily: 'Inter',
      ),
      bodyMedium: TextStyle(
        fontSize: fontSizeMedium,
        fontWeight: fontWeightRegular,
        color: textPrimary,
        fontFamily: 'Inter',
      ),
      bodySmall: TextStyle(
        fontSize: fontSizeSmall,
        fontWeight: fontWeightRegular,
        color: textSecondary,
        fontFamily: 'Inter',
      ),
      labelLarge: TextStyle(
        fontSize: fontSizeMedium,
        fontWeight: fontWeightMedium,
        color: textPrimary,
        fontFamily: 'Inter',
      ),
      labelMedium: TextStyle(
        fontSize: fontSizeSmall,
        fontWeight: fontWeightMedium,
        color: textSecondary,
        fontFamily: 'Inter',
      ),
      labelSmall: TextStyle(
        fontSize: 11,
        fontWeight: fontWeightMedium,
        color: textSecondary,
        fontFamily: 'Inter',
      ),
    ),
  );
} 