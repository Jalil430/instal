import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../core/theme/app_theme.dart';
import '../../core/localization/app_localizations.dart';

class MainLayout extends StatefulWidget {
  final Widget child;

  const MainLayout({
    super.key,
    required this.child,
  });

  @override
  State<MainLayout> createState() => _MainLayoutState();
}

class _MainLayoutState extends State<MainLayout> {
  String? _hoveredRoute;

  @override
  Widget build(BuildContext context) {
    final currentRoute = GoRouterState.of(context).uri.toString();
    final l10n = AppLocalizations.of(context);

    return Scaffold(
      body: Row(
        children: [
          Container(
            width: 72,
            decoration: const BoxDecoration(
              color: AppTheme.sidebarBackground,
              boxShadow: [
                BoxShadow(
                  color: Colors.black12,
                  blurRadius: 4,
                  offset: Offset(2, 0),
                ),
              ],
            ),
            child: Column(
              children: [
                const SizedBox(height: 24),
                // Logo/App Name
                Container(
                  height: 48,
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: AppTheme.primaryColor,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Center(
                      child: Text(
                        'I',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 32),
                // Navigation Items
                _buildNavItem(
                  icon: Icons.receipt_long_outlined,
                  label: l10n?.installments ?? 'Рассрочки',
                  route: '/installments',
                  currentRoute: currentRoute,
                ),
                _buildNavItem(
                  icon: Icons.people_outline,
                  label: l10n?.clients ?? 'Клиенты',
                  route: '/clients',
                  currentRoute: currentRoute,
                ),
                _buildNavItem(
                  icon: Icons.account_balance_wallet_outlined,
                  label: l10n?.investors ?? 'Инвесторы',
                  route: '/investors',
                  currentRoute: currentRoute,
                ),
                const Spacer(),
                // Settings at bottom
                const Divider(
                  color: AppTheme.sidebarHoverColor,
                  height: 1,
                ),
                _buildNavItem(
                  icon: Icons.settings_outlined,
                  label: 'Настройки',
                  route: '/settings',
                  currentRoute: currentRoute,
                ),
                const SizedBox(height: 16),
              ],
            ),
          ),
          // Main Content
          Expanded(
            child: widget.child,
          ),
        ],
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
    final isHovered = _hoveredRoute == route;

    return Tooltip(
      message: label,
      preferBelow: false,
      verticalOffset: 0,
      margin: const EdgeInsets.only(left: 72),
      decoration: BoxDecoration(
        color: AppTheme.sidebarBackground,
        borderRadius: BorderRadius.circular(4),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.2),
            blurRadius: 8,
            offset: const Offset(2, 2),
          ),
        ],
      ),
      textStyle: const TextStyle(
        color: Colors.white,
        fontSize: 12,
      ),
      child: MouseRegion(
        onEnter: (_) => setState(() => _hoveredRoute = route),
        onExit: (_) => setState(() => _hoveredRoute = null),
        cursor: SystemMouseCursors.click,
        child: GestureDetector(
          onTap: () => context.go(route),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 150),
            height: 48,
            margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
            decoration: BoxDecoration(
              color: isActive
                  ? AppTheme.primaryColor.withOpacity(0.1)
                  : isHovered
                      ? AppTheme.sidebarHoverColor
                      : Colors.transparent,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Center(
              child: Icon(
                icon,
                size: 24,
                color: isActive
                    ? AppTheme.primaryColor
                    : isHovered
                        ? Colors.white
                        : AppTheme.sidebarIconColor,
              ),
            ),
          ),
        ),
      ),
    );
  }
} 