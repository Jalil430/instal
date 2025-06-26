import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../themes/app_theme.dart';

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
  String? hoveredItem;

  @override
  Widget build(BuildContext context) {
    final currentLocation = GoRouterState.of(context).uri.path;

    return Scaffold(
      backgroundColor: AppTheme.backgroundColor,
      body: Row(
        children: [
          // Sidebar Navigation
          Container(
            width: 80,
            decoration: const BoxDecoration(
              color: AppTheme.surfaceColor,
              border: Border(
                right: BorderSide(
                  color: AppTheme.dividerColor,
                  width: 1,
                ),
              ),
            ),
            child: Column(
              children: [
                // App Logo/Title
                Container(
                  height: 80,
                  padding: const EdgeInsets.all(16),
                  child: Center(
                    child: Container(
                      width: 48,
                      height: 48,
                      decoration: BoxDecoration(
                        color: AppTheme.primaryColor,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Icon(
                        Icons.account_balance_wallet,
                        color: Colors.white,
                        size: 24,
                      ),
                    ),
                  ),
                ),
                
                // Navigation Items
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    child: Column(
                      children: [
                        _buildNavItem(
                          icon: Icons.receipt_long,
                          label: 'Рассрочки',
                          path: '/installments',
                          currentPath: currentLocation,
                        ),
                        const SizedBox(height: 8),
                        _buildNavItem(
                          icon: Icons.people,
                          label: 'Клиенты',
                          path: '/clients',
                          currentPath: currentLocation,
                        ),
                        const SizedBox(height: 8),
                        _buildNavItem(
                          icon: Icons.business,
                          label: 'Инвесторы',
                          path: '/investors',
                          currentPath: currentLocation,
                        ),
                      ],
                    ),
                  ),
                ),
                
                // Bottom section
                Container(
                  height: 80,
                  padding: const EdgeInsets.all(16),
                  child: Center(
                    child: IconButton(
                      onPressed: () {},
                      icon: const Icon(
                        Icons.settings,
                        color: AppTheme.textSecondary,
                        size: 24,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          
          // Main Content Area with animation
          Expanded(
            child: AnimatedSwitcher(
              duration: const Duration(milliseconds: 300),
              transitionBuilder: (child, animation) {
                return SlideTransition(
                  position: Tween<Offset>(
                    begin: const Offset(0.1, 0.0),
                    end: Offset.zero,
                  ).animate(CurvedAnimation(
                    parent: animation,
                    curve: Curves.easeOutCubic,
                  )),
                  child: FadeTransition(
                    opacity: Tween<double>(
                      begin: 0.0,
                      end: 1.0,
                    ).animate(CurvedAnimation(
                      parent: animation,
                      curve: const Interval(0.0, 0.8, curve: Curves.easeOut),
                    )),
                    child: child,
                  ),
                );
              },
              child: widget.child,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildNavItem({
    required IconData icon,
    required String label,
    required String path,
    required String currentPath,
  }) {
    final isActive = currentPath == path;
    final isHovered = hoveredItem == path;

    return MouseRegion(
      onEnter: (_) => setState(() => hoveredItem = path),
      onExit: (_) => setState(() => hoveredItem = null),
      child: Stack(
        children: [
          GestureDetector(
            onTap: () => context.go(path),
            child: Container(
              width: 48,
              height: 48,
              margin: const EdgeInsets.symmetric(horizontal: 16),
              decoration: BoxDecoration(
                color: isActive
                    ? AppTheme.primaryColor.withValues(alpha: 0.1)
                    : isHovered
                        ? AppTheme.primaryColor.withValues(alpha: 0.05)
                        : Colors.transparent,
                borderRadius: BorderRadius.circular(12),
                border: isActive
                    ? Border.all(
                        color: AppTheme.primaryColor.withValues(alpha: 0.2),
                        width: 1,
                      )
                    : null,
              ),
              child: Icon(
                icon,
                color: isActive
                    ? AppTheme.primaryColor
                    : isHovered
                        ? AppTheme.primaryColor
                        : AppTheme.textSecondary,
                size: 24,
              ),
            ),
          ),
          
          // Tooltip on hover
          if (isHovered)
            Positioned(
              left: 88,
              top: 8,
              child: Material(
                elevation: 8,
                borderRadius: BorderRadius.circular(8),
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 8,
                  ),
                  decoration: BoxDecoration(
                    color: AppTheme.textPrimary,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    label,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
} 