import 'package:fluent_ui/fluent_ui.dart';

class AppTheme {
  static const Color primaryColor = Color(0xFF1A73E8);
  static const Color successColor = Color(0xFF34A853);
  static const Color warningColor = Color(0xFFFBBC04);
  static const Color errorColor = Color(0xFFEA4335);
  static const Color backgroundColor = Color(0xFFF8F9FA);
  static const Color surfaceColor = Color(0xFFFFFFFF);
  static const Color textPrimaryColor = Color(0xFF202124);
  static const Color textSecondaryColor = Color(0xFF5F6368);
  static const Color borderColor = Color(0xFFE8EAED);

  static FluentThemeData lightTheme = FluentThemeData(
    brightness: Brightness.light,
    accentColor: AccentColor('normal', {
      'normal': primaryColor,
      'hot': primaryColor.withOpacity(0.8),
      'disabled': primaryColor.withOpacity(0.4),
    }),
    scaffoldBackgroundColor: backgroundColor,
    cardColor: surfaceColor,
    fontFamily: 'Inter',
    typography: Typography.raw(
      body: TextStyle(
        fontFamily: 'Inter',
        fontSize: 14,
        color: textPrimaryColor,
        fontWeight: FontWeight.normal,
      ),
      bodyStrong: TextStyle(
        fontFamily: 'Inter',
        fontSize: 14,
        color: textPrimaryColor,
        fontWeight: FontWeight.w600,
      ),
      title: TextStyle(
        fontFamily: 'Inter',
        fontSize: 28,
        color: textPrimaryColor,
        fontWeight: FontWeight.w600,
      ),
      subtitle: TextStyle(
        fontFamily: 'Inter',
        fontSize: 20,
        color: textPrimaryColor,
        fontWeight: FontWeight.w500,
      ),
      bodyLarge: TextStyle(
        fontFamily: 'Inter',
        fontSize: 16,
        color: textPrimaryColor,
        fontWeight: FontWeight.normal,
      ),
      caption: TextStyle(
        fontFamily: 'Inter',
        fontSize: 12,
        color: textSecondaryColor,
        fontWeight: FontWeight.normal,
      ),
    ),
  );

  static BoxDecoration cardDecoration = BoxDecoration(
    color: surfaceColor,
    borderRadius: BorderRadius.circular(8),
    border: Border.all(color: borderColor, width: 1),
    boxShadow: [
      BoxShadow(
        color: Colors.black.withOpacity(0.04),
        blurRadius: 8,
        offset: const Offset(0, 2),
      ),
    ],
  );

  static BoxDecoration elevatedCardDecoration = BoxDecoration(
    color: surfaceColor,
    borderRadius: BorderRadius.circular(8),
    boxShadow: [
      BoxShadow(
        color: Colors.black.withOpacity(0.08),
        blurRadius: 16,
        offset: const Offset(0, 4),
      ),
    ],
  );

  static ButtonStyle primaryButtonStyle = ButtonStyle(
    padding: ButtonState.all(const EdgeInsets.symmetric(horizontal: 24, vertical: 12)),
    backgroundColor: ButtonState.resolveWith((states) {
      if (states.isDisabled) return primaryColor.withOpacity(0.4);
      if (states.isPressing) return primaryColor.withOpacity(0.8);
      if (states.isHovering) return primaryColor.withOpacity(0.9);
      return primaryColor;
    }),
    foregroundColor: ButtonState.all(Colors.white),
    textStyle: ButtonState.all(const TextStyle(
      fontWeight: FontWeight.w500,
      fontSize: 14,
    )),
  );

  static ButtonStyle secondaryButtonStyle = ButtonStyle(
    padding: ButtonState.all(const EdgeInsets.symmetric(horizontal: 24, vertical: 12)),
    backgroundColor: ButtonState.resolveWith((states) {
      if (states.isDisabled) return Colors.transparent;
      if (states.isPressing) return borderColor;
      if (states.isHovering) return borderColor.withOpacity(0.5);
      return Colors.transparent;
    }),
    foregroundColor: ButtonState.all(textPrimaryColor),
    textStyle: ButtonState.all(const TextStyle(
      fontWeight: FontWeight.w500,
      fontSize: 14,
    )),
  );

  static TextStyle get headlineStyle => const TextStyle(
    fontSize: 24,
    fontWeight: FontWeight.w600,
    color: textPrimaryColor,
  );

  static TextStyle get subtitleStyle => const TextStyle(
    fontSize: 16,
    fontWeight: FontWeight.w500,
    color: textPrimaryColor,
  );

  static TextStyle get bodyStyle => const TextStyle(
    fontSize: 14,
    fontWeight: FontWeight.normal,
    color: textPrimaryColor,
  );

  static TextStyle get captionStyle => const TextStyle(
    fontSize: 12,
    fontWeight: FontWeight.normal,
    color: textSecondaryColor,
  );

  static Color getStatusColor(String status) {
    switch (status) {
      case 'оплачено':
        return successColor;
      case 'к оплате':
        return warningColor;
      case 'просрочено':
        return errorColor;
      default:
        return textSecondaryColor;
    }
  }
} 