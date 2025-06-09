import 'package:go_router/go_router.dart';
import 'package:flutter/material.dart';
import '../../shared/navigation/main_layout.dart';
import '../../features/installments/screens/installments_list_screen.dart';
import '../../features/installments/screens/installment_details_screen.dart';
import '../../features/installments/screens/add_installment_screen.dart';
import '../../features/clients/screens/clients_list_screen.dart';
import '../../features/clients/screens/client_details_screen.dart';
import '../../features/clients/screens/add_edit_client_screen.dart';
import '../../features/investors/screens/investors_list_screen.dart';
import '../../features/investors/screens/investor_details_screen.dart';
import '../../features/investors/screens/add_edit_investor_screen.dart';
import '../../features/settings/settings_screen.dart';

class AppRouter {
  static final router = GoRouter(
    initialLocation: '/installments',
    routes: [
      // Home route - redirect to installments
      GoRoute(
        path: '/',
        name: 'home',
        redirect: (context, state) => '/installments',
      ),
      
      // Installments routes
      GoRoute(
        path: '/installments',
        name: 'installments',
        pageBuilder: (context, state) => MaterialPage(
          child: MainLayout(child: const InstallmentsListScreen()),
        ),
      ),
      GoRoute(
        path: '/installments/add',
        name: 'add-installment',
        pageBuilder: (context, state) => MaterialPage(
          child: MainLayout(child: const AddInstallmentScreen()),
        ),
      ),
      GoRoute(
        path: '/installments/:id',
        name: 'installment-details',
        pageBuilder: (context, state) {
          final id = state.pathParameters['id']!;
          return MaterialPage(
            child: MainLayout(child: InstallmentDetailsScreen(installmentId: id)),
          );
        },
      ),
      
      // Clients routes
      GoRoute(
        path: '/clients',
        name: 'clients',
        pageBuilder: (context, state) => MaterialPage(
          child: MainLayout(child: const ClientsListScreen()),
        ),
      ),
      GoRoute(
        path: '/clients/add',
        name: 'add-client',
        pageBuilder: (context, state) => MaterialPage(
          child: MainLayout(child: const AddEditClientScreen()),
        ),
      ),
      GoRoute(
        path: '/clients/:id',
        name: 'client-details',
        pageBuilder: (context, state) {
          final id = state.pathParameters['id']!;
          return MaterialPage(
            child: MainLayout(child: ClientDetailsScreen(clientId: id)),
          );
        },
      ),
      GoRoute(
        path: '/clients/:id/edit',
        name: 'edit-client',
        pageBuilder: (context, state) {
          final id = state.pathParameters['id']!;
          return MaterialPage(
            child: MainLayout(child: AddEditClientScreen(clientId: id)),
          );
        },
      ),
      
      // Investors routes
      GoRoute(
        path: '/investors',
        name: 'investors',
        pageBuilder: (context, state) => MaterialPage(
          child: MainLayout(child: const InvestorsListScreen()),
        ),
      ),
      GoRoute(
        path: '/investors/add',
        name: 'add-investor',
        pageBuilder: (context, state) => MaterialPage(
          child: MainLayout(child: const AddEditInvestorScreen()),
        ),
      ),
      GoRoute(
        path: '/investors/:id',
        name: 'investor-details',
        pageBuilder: (context, state) {
          final id = state.pathParameters['id']!;
          return MaterialPage(
            child: MainLayout(child: InvestorDetailsScreen(investorId: id)),
          );
        },
      ),
      GoRoute(
        path: '/investors/:id/edit',
        name: 'edit-investor',
        pageBuilder: (context, state) {
          final id = state.pathParameters['id']!;
          return MaterialPage(
            child: MainLayout(child: AddEditInvestorScreen(investorId: id)),
          );
        },
      ),
      // Settings route
      GoRoute(
        path: '/settings',
        name: 'settings',
        pageBuilder: (context, state) => MaterialPage(
          child: MainLayout(child: const SettingsScreen()),
        ),
      ),
    ],
  );
} 