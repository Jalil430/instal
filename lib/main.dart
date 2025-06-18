import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'core/theme/app_theme.dart';
import 'core/routes/app_router.dart';
import 'core/localization/app_localizations.dart';
import 'shared/database/database_helper.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // Initialize database
  await DatabaseHelper.instance.database;
  
  final prefs = await SharedPreferences.getInstance();
  final languageCode = prefs.getString('languageCode') ?? 'ru';

  runApp(InstalApp(
    initialLocale: Locale(languageCode),
  ));
}

class InstalApp extends StatefulWidget {
  final Locale initialLocale;
  const InstalApp({super.key, required this.initialLocale});

  @override
  State<InstalApp> createState() => _InstalAppState();
}

class _InstalAppState extends State<InstalApp> {
  late Locale _locale;

  @override
  void initState() {
    super.initState();
    _locale = widget.initialLocale;
  }

  Future<void> setLocale(Locale locale) async {
    setState(() {
      _locale = locale;
    });
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('languageCode', locale.languageCode);
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp.router(
      title: 'Instal',
      theme: AppTheme.lightTheme,
      debugShowCheckedModeBanner: false,
      routerConfig: AppRouter.router,
      locale: _locale,
      supportedLocales: AppLocalizations.supportedLocales,
      localizationsDelegates: const [
        AppLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      builder: (context, child) {
        // Pass setLocale down via InheritedWidget or directly if needed
        return LocaleSetter(
          setLocale: setLocale,
          child: child!,
        );
      },
    );
  }
}

class LocaleSetter extends InheritedWidget {
  final Future<void> Function(Locale) setLocale;
  const LocaleSetter({required this.setLocale, required Widget child})
      : super(child: child);

  static LocaleSetter? of(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<LocaleSetter>();

  @override
  bool updateShouldNotify(LocaleSetter oldWidget) => setLocale != oldWidget.setLocale;
}