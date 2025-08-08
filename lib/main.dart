import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'core/theme/app_theme.dart';
import 'core/routes/app_router.dart';
import 'core/localization/app_localizations.dart';

import 'shared/database/database_helper.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'features/auth/presentation/widgets/auth_service_provider.dart';
import 'features/subscription/presentation/widgets/subscription_service_provider.dart';
import 'features/subscription/presentation/providers/subscription_provider.dart';
import 'core/services/update_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // Initialize database
  await DatabaseHelper.instance.database;
  
  final prefs = await SharedPreferences.getInstance();
  final languageCode = prefs.getString('languageCode') ?? 'ru';

  // Initialize services
  final subscriptionProvider = await SubscriptionServiceFactory.create();

  // Initialize auto-updater (feeds to be hosted on your website)
  await UpdateService.initialize(
    macOsFeedUrl: 'https://jalil430.github.io/instal/downloads/mac/appcast-macos.xml',
    windowsFeedUrl: 'https://jalil430.github.io/instal/downloads/win/appcast-windows.xml',
    scheduledCheckInterval: const Duration(hours: 24),
  );
  // Quick startup: rely on scheduled checks; no popup unless Settings triggers

  runApp(InstalApp(
    initialLocale: Locale(languageCode),
    subscriptionProvider: subscriptionProvider,
  ));
}

class InstalApp extends StatefulWidget {
  final Locale initialLocale;
  final SubscriptionProvider subscriptionProvider;
  
  const InstalApp({
    super.key, 
    required this.initialLocale,
    required this.subscriptionProvider,
  });

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
    // Create authentication service
    final authService = AuthServiceFactory.create();

    return AuthServiceProvider(
      authService: authService,
      child: SubscriptionServiceProvider(
        subscriptionProvider: widget.subscriptionProvider,
        child: MaterialApp.router(
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
        ),
      ),
    );
  }
}

class LocaleSetter extends InheritedWidget {
  final Future<void> Function(Locale) setLocale;
  const LocaleSetter({super.key, required this.setLocale, required super.child});

  static LocaleSetter? of(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<LocaleSetter>();

  @override
  bool updateShouldNotify(LocaleSetter oldWidget) => setLocale != oldWidget.setLocale;
}