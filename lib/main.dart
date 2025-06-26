import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'core/themes/app_theme.dart';
import 'core/di/injection_container.dart';
import 'shared/navigation/app_router.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // Initialize locale data for date formatting
  await initializeDateFormatting('ru', null);
  Intl.defaultLocale = 'ru';
  
  // Initialize dependency injection
  final injectionContainer = InjectionContainer();
  injectionContainer.init();
  
  runApp(InstalApp(injectionContainer: injectionContainer));
}

class InstalApp extends StatelessWidget {
  final InjectionContainer injectionContainer;
  
  const InstalApp({super.key, required this.injectionContainer});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: injectionContainer.providers,
      child: MaterialApp.router(
        title: 'Instal - Islamic Installments Tracker',
        theme: AppTheme.lightTheme,
        routerConfig: AppRouter.router,
        debugShowCheckedModeBanner: false,
      ),
    );
  }
}
