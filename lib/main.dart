import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'core/theme/app_theme.dart';
import 'core/routes/app_router.dart';
import 'core/localization/app_localizations.dart';
import 'shared/database/database_helper.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // Initialize database
  await DatabaseHelper.instance.database;
  
  runApp(InstalApp());
}

class InstalApp extends StatefulWidget {
  const InstalApp({super.key});

  @override
  State<InstalApp> createState() => _InstalAppState();
}

class _InstalAppState extends State<InstalApp> {
  Locale _locale = const Locale('ru');

  void setLocale(Locale locale) {
    setState(() {
      _locale = locale;
    });
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp.router(
      title: 'Instal - Islamic Installments Tracker',
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
  final void Function(Locale) setLocale;
  const LocaleSetter({required this.setLocale, required Widget child}) : super(child: child);

  static LocaleSetter? of(BuildContext context) => context.dependOnInheritedWidgetOfExactType<LocaleSetter>();

  @override
  bool updateShouldNotify(LocaleSetter oldWidget) => setLocale != oldWidget.setLocale;
}