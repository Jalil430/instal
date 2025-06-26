import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../core/widgets/main_layout.dart';
import '../../features/installments/presentation/pages/installments_page.dart';
import '../../features/installments/presentation/screens/add_installment_screen.dart';
import '../../features/installments/presentation/screens/installment_details_screen.dart';
import '../../features/clients/presentation/pages/clients_page.dart';
import '../../features/clients/presentation/screens/add_client_screen.dart';
import '../../features/clients/presentation/screens/client_details_screen.dart';
import '../../features/investors/presentation/pages/investors_page.dart';
import '../../features/investors/presentation/screens/add_investor_screen.dart';
import '../../features/investors/presentation/screens/investor_details_screen.dart';

class AppRouter {
  static final GoRouter router = GoRouter(
    initialLocation: '/installments',
    routes: [
      ShellRoute(
        builder: (context, state, child) {
          return MainLayout(child: child);
        },
        routes: [
          // Installments routes
          GoRoute(
            path: '/installments',
            name: 'installments',
            pageBuilder: (context, state) => CustomTransitionPage(
              key: state.pageKey,
              child: const InstallmentsPage(),
              transitionsBuilder: (context, animation, secondaryAnimation, child) {
                return FadeTransition(
                  opacity: CurveTween(curve: Curves.easeInOut).animate(animation),
                  child: child,
                );
              },
            ),
            routes: [
              GoRoute(
                path: 'add',
                name: 'add-installment',
                builder: (context, state) => const AddInstallmentScreen(),
              ),
              GoRoute(
                path: ':id',
                name: 'installment-details',
                builder: (context, state) {
                  final installmentId = state.pathParameters['id']!;
                  return InstallmentDetailsScreen(installmentId: installmentId);
                },
              ),
            ],
          ),
          
          // Clients routes
          GoRoute(
            path: '/clients',
            name: 'clients',
            pageBuilder: (context, state) => CustomTransitionPage(
              key: state.pageKey,
              child: const ClientsPage(),
              transitionsBuilder: (context, animation, secondaryAnimation, child) {
                return FadeTransition(
                  opacity: CurveTween(curve: Curves.easeInOut).animate(animation),
                  child: child,
                );
              },
            ),
            routes: [
              GoRoute(
                path: 'add',
                name: 'add-client',
                builder: (context, state) => const AddClientScreen(),
              ),
              GoRoute(
                path: ':id',
                name: 'client-details',
                builder: (context, state) {
                  final clientId = state.pathParameters['id']!;
                  return ClientDetailsScreen(clientId: clientId);
                },
              ),
              GoRoute(
                path: ':id/edit',
                name: 'edit-client',
                builder: (context, state) {
                  // Pass the client ID to the AddClientScreen in edit mode
                  // The screen will fetch the client data and populate the form
                  final clientId = state.pathParameters['id']!;
                  return AddClientScreen(
                    initialClient: null, // Will be fetched inside the screen
                  );
                },
              ),
            ],
          ),
          
          // Investors routes
          GoRoute(
            path: '/investors',
            name: 'investors',
            pageBuilder: (context, state) => CustomTransitionPage(
              key: state.pageKey,
              child: const InvestorsPage(),
              transitionsBuilder: (context, animation, secondaryAnimation, child) {
                return FadeTransition(
                  opacity: CurveTween(curve: Curves.easeInOut).animate(animation),
                  child: child,
                );
              },
            ),
            routes: [
              GoRoute(
                path: 'add',
                name: 'add-investor',
                builder: (context, state) => const AddInvestorScreen(),
              ),
              GoRoute(
                path: ':id',
                name: 'investor-details',
                builder: (context, state) {
                  final investorId = state.pathParameters['id']!;
                  return InvestorDetailsScreen(investorId: investorId);
                },
              ),
              GoRoute(
                path: ':id/edit',
                name: 'edit-investor',
                builder: (context, state) {
                  // Pass the investor ID to the AddInvestorScreen in edit mode
                  // The screen will fetch the investor data and populate the form
                  final investorId = state.pathParameters['id']!;
                  return AddInvestorScreen(
                    initialInvestor: null, // Will be fetched inside the screen
                  );
                },
              ),
            ],
          ),
        ],
      ),
    ],
  );
} 