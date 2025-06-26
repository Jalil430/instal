// This is a basic Flutter widget test.
//
// To perform an interaction with a widget in your test, use the WidgetTester
// utility in the flutter_test package. For example, you can send tap and scroll
// gestures. You can also use WidgetTester to find child widgets in the widget
// tree, read text, and verify that the values of widget properties are correct.

import 'package:flutter_test/flutter_test.dart';
import 'package:instal_app/main.dart';
import 'package:instal_app/core/di/injection_container.dart';

void main() {
  testWidgets('App loads and shows installments page', (WidgetTester tester) async {
    // Initialize dependency injection for testing
    final injectionContainer = InjectionContainer();
    injectionContainer.init();
    
    // Build our app and trigger a frame.
    await tester.pumpWidget(InstalApp(injectionContainer: injectionContainer));

    // Verify that the app loads and shows the installments page
    expect(find.text('Рассрочки'), findsOneWidget);
    expect(find.text('Рассрочки не найдены'), findsOneWidget);
  });
}
