import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../core/theme/app_theme.dart';
import '../../core/localization/app_localizations.dart';
import '../widgets/responsive_layout.dart';
import 'main_layout.dart';

class ResponsiveMainLayout extends StatefulWidget {
  final Widget child;

  const ResponsiveMainLayout({
    super.key,
    required this.child,
  });

  @override
  State<ResponsiveMainLayout> createState() => _ResponsiveMainLayoutState();
}

class _ResponsiveMainLayoutState extends State<ResponsiveMainLayout> {
  @override
  Widget build(BuildContext context) {
    return ResponsiveLayout(
      mobile: _MobileMainLayout(child: widget.child),
      desktop: MainLayout(child: widget.child),
    );
  }
}

class _MobileMainLayout extends StatefulWidget {
  final Widget child;

  const _MobileMainLayout({
    required this.child,
  });

  @override
  State<_MobileMainLayout> createState() => _MobileMainLayoutState();
}

class _MobileMainLayoutState extends State<_MobileMainLayout> {
  @override
  Widget build(BuildContext context) {
    final currentRoute = GoRouterState.of(context).uri.toString();
    final l10n = AppLocalizations.of(context);

    return Scaffold(
      body: widget.child,
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          color: AppTheme.surfaceColor,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.05),
              blurRadius: 5,
              offset: const Offset(0, -1),
            ),
          ],
          border: Border(
            top: BorderSide(
              color: AppTheme.borderColor,
              width: 0.5,
            ),
          ),
        ),
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _buildNavItem(
                  icon: Icons.description_outlined,
                  label: l10n?.installments ?? 'Рассрочки',
                  route: '/installments',
                  currentRoute: currentRoute,
                ),
                _buildNavItem(
                  icon: Icons.person_outline,
                  label: l10n?.clients ?? 'Клиенты',
                  route: '/clients',
                  currentRoute: currentRoute,
                ),
                _buildNavItem(
                  icon: Icons.attach_money_outlined,
                  label: l10n?.investors ?? 'Инвесторы',
                  route: '/investors',
                  currentRoute: currentRoute,
                ),
                _buildNavItem(
                  icon: Icons.account_balance_wallet_outlined,
                  label: l10n?.wallets ?? 'Кошельки',
                  route: '/wallets',
                  currentRoute: currentRoute,
                ),
                _buildNavItem(
                  icon: Icons.analytics_outlined,
                  label: l10n?.analytics ?? 'Аналитика',
                  route: '/analytics',
                  currentRoute: currentRoute,
                ),
                _buildNavItem(
                  icon: Icons.settings_outlined,
                  label: l10n?.settings ?? 'Настройки',
                  route: '/settings',
                  currentRoute: currentRoute,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildNavItem({
    required IconData icon,
    required String label,
    required String route,
    required String currentRoute,
  }) {
    final isActive = currentRoute.startsWith(route);

    return InkWell(
      onTap: () => context.go(route),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            icon,
            size: 24,
            color: isActive ? AppTheme.primaryColor : AppTheme.textSecondary,
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: TextStyle(
              fontSize: 10,
              color: isActive ? AppTheme.primaryColor : AppTheme.textSecondary,
              fontWeight: isActive ? FontWeight.w500 : FontWeight.normal,
            ),
          ),
        ],
      ),
    );
  }
} 