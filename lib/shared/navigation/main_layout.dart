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
          // Modern, redesigned sidebar
          AnimatedContainer(
            duration: AppTheme.animationStandard,
            width: 64,
            decoration: BoxDecoration(
              color: AppTheme.surfaceColor,
              border: Border(
                right: BorderSide(
                  color: AppTheme.borderColor,
                  width: 1,
                ),
              ),
            ),
            child: Column(
              children: [
                const SizedBox(height: AppTheme.spacingLg),
                // App Logo
                Container(
                  height: 42,
                  padding: const EdgeInsets.symmetric(horizontal: AppTheme.spacingMd),
                  child: Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [
                          AppTheme.primaryColor,
                          AppTheme.primaryDark,
                        ],
                      ),
                      borderRadius: BorderRadius.circular(AppTheme.borderRadiusMedium),
                      boxShadow: [
                        BoxShadow(
                          color: AppTheme.primaryColor.withOpacity(0.3),
                          blurRadius: 8,
                          offset: const Offset(0, 3),
                        ),
                      ],
                    ),
                    child: const Center(
                      child: Text(
                        'I',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: AppTheme.spacingLg),
                
                // Navigation Items with updated icons
                _buildNavItem(
                  icon: Icons.description_outlined, // Document icon for installments
                  label: l10n?.installments ?? 'Рассрочки',
                  route: '/installments',
                  currentRoute: currentRoute,
                ),
                _buildNavItem(
                  icon: Icons.person_outline, // Keep clients icon
                  label: l10n?.clients ?? 'Клиенты',
                  route: '/clients',
                  currentRoute: currentRoute,
                ),
                _buildNavItem(
                  icon: Icons.attach_money_outlined, // Better paper-money icon for investors
                  label: l10n?.investors ?? 'Инвесторы',
                  route: '/investors',
                  currentRoute: currentRoute,
                ),
                _buildNavItem(
                  icon: Icons.analytics_outlined,
                  label: l10n?.analytics ?? 'Аналитика',
                  route: '/analytics',
                  currentRoute: currentRoute,
                ),
                const Spacer(),
              
                // Settings at the very bottom corner
                _buildNavItem(
                  icon: Icons.settings_outlined, // Settings gear icon
                  label: l10n?.settings ?? 'Настройки',
                  route: '/settings',
                  currentRoute: currentRoute,
                ),
                const SizedBox(height: AppTheme.spacingXs), // Match horizontal spacing
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

    // Removed Tooltip widget
    return MouseRegion(
      onEnter: (_) => setState(() => _hoveredRoute = route),
      onExit: (_) => setState(() => _hoveredRoute = null),
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTap: () => context.go(route),
        child: AnimatedContainer(
          duration: AppTheme.animationQuick,
          height: 48,
          margin: const EdgeInsets.symmetric(
            horizontal: AppTheme.spacingXs,
            vertical: AppTheme.spacingXxs,
          ),
          decoration: BoxDecoration(
            color: isActive
                ? AppTheme.subtleBackgroundColor
                : isHovered
                    ? AppTheme.subtleHoverColor
                    : Colors.transparent,
            borderRadius: BorderRadius.circular(AppTheme.borderRadiusMedium),
            border: isActive
                ? Border.all(
                    color: AppTheme.subtleBorderColor,
                    width: 1,
                  )
                : null,
            boxShadow: isActive ? AppTheme.subtleShadow : null,
          ),
          child: Center(
            child: Icon(
              icon,
              size: 20,
              color: isActive
                  ? AppTheme.primaryColor
                  : isHovered
                      ? AppTheme.textPrimary
                      : AppTheme.textSecondary,
            ),
          ),
        ),
      ),
    );
  }
} 