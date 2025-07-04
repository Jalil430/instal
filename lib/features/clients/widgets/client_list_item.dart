import 'package:flutter/material.dart';
import 'dart:ui' as ui;
import 'package:intl/intl.dart';
import '../../../core/theme/app_theme.dart';
import '../domain/entities/client.dart';
import '../../../shared/widgets/custom_contextual_dialog.dart';
import '../../../core/localization/app_localizations.dart';

class ClientListItem extends StatefulWidget {
  final Client client;
  final VoidCallback onTap;
  final VoidCallback? onEdit;
  final VoidCallback? onDelete;
  final VoidCallback? onSelect;

  const ClientListItem({
    super.key,
    required this.client,
    required this.onTap,
    this.onEdit,
    this.onDelete,
    this.onSelect,
  });

  @override
  State<ClientListItem> createState() => _ClientListItemState();
}

class _ClientListItemState extends State<ClientListItem> with TickerProviderStateMixin {
  bool _isHovered = false;
  bool _isAddressHovered = false;
  
  late AnimationController _hoverController;
  late Animation<double> _hoverAnimation;

  @override
  void initState() {
    super.initState();
    _hoverController = AnimationController(
      duration: const Duration(milliseconds: 200),
      vsync: this,
    );
    
    _hoverAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _hoverController, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _hoverController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final dateFormat = DateFormat('dd.MM.yyyy');

    return MouseRegion(
      onEnter: (_) {
        setState(() => _isHovered = true);
        _hoverController.forward();
      },
      onExit: (_) {
        setState(() => _isHovered = false);
        _hoverController.reverse();
      },
      child: GestureDetector(
        onTap: widget.onTap,
        onSecondaryTapDown: (details) async {
          await CustomContextualDialog.show(
            context: context,
            position: details.globalPosition,
            child: _ClientContextMenu(
              onSelect: widget.onSelect,
              onEdit: widget.onEdit,
              onDelete: widget.onDelete,
            ),
            width: 200,
            estimatedHeight: 140,
          );
        },
        child: AnimatedBuilder(
          animation: _hoverAnimation,
          builder: (context, child) {
            return Container(
              height: 48, // Fixed height to match InstallmentListItem
              margin: const EdgeInsets.symmetric(horizontal: 0, vertical: 0),
              decoration: BoxDecoration(
                color: Color.lerp(
                  AppTheme.surfaceColor,
                  AppTheme.backgroundColor,
                  _hoverAnimation.value * 0.6,
                ),
                border: Border(
                  bottom: BorderSide(
                    color: AppTheme.borderColor.withOpacity(0.3),
                    width: 1,
                  ),
                ),
              ),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 12),
                child: Row(
                  children: [
                    // Full Name
                    Expanded(
                      flex: 3,
                      child: Text(
                        widget.client.fullName,
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          fontWeight: FontWeight.w500,
                          fontSize: 14,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    // Contact Number
                    Expanded(
                      flex: 2,
                      child: Text(
                        widget.client.contactNumber,
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          fontSize: 14,
                          fontWeight: FontWeight.w400,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    // Passport Number
                    Expanded(
                      flex: 2,
                      child: Text(
                        widget.client.passportNumber,
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          fontSize: 14,
                          fontWeight: FontWeight.w400,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    // Address with tooltip - always single line with ellipsis
                    Expanded(
                      flex: 2,
                      child: MouseRegion(
                        onEnter: (_) => setState(() => _isAddressHovered = true),
                        onExit: (_) => setState(() => _isAddressHovered = false),
                        child: Tooltip(
                          message: widget.client.address ?? 'Не указан',
                          waitDuration: const Duration(milliseconds: 500),
                          showDuration: const Duration(seconds: 3),
                          decoration: BoxDecoration(
                            color: AppTheme.textPrimary.withOpacity(0.9),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          textStyle: const TextStyle(
                            color: Colors.white,
                            fontSize: 12,
                          ),
                          child: LayoutBuilder(
                            builder: (context, constraints) {
                              final address = widget.client.address ?? 'Не указан';
                              // Calculate how many characters can fit
                              final TextPainter textPainter = TextPainter(
                                text: TextSpan(
                                  text: address,
                                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                    fontSize: 14, 
                                    fontWeight: FontWeight.w400,
                                  ),
                                ),
                                maxLines: 1,
                                textDirection: ui.TextDirection.ltr,
                              )..layout(maxWidth: constraints.maxWidth);
                              
                              // Always show one line with ellipsis
                              return Text(
                                address,
                                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w400,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              );
                            },
                          ),
                        ),
                      ),
                    ),
                    // Created Date
                    Expanded(
                      child: Text(
                        dateFormat.format(widget.client.createdAt),
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          fontSize: 14,
                          fontWeight: FontWeight.w400,
                          color: AppTheme.textSecondary,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}

class _ClientContextMenu extends StatelessWidget {
  final VoidCallback? onSelect;
  final VoidCallback? onEdit;
  final VoidCallback? onDelete;

  const _ClientContextMenu({this.onSelect, this.onEdit, this.onDelete});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final textStyle = Theme.of(context).textTheme.bodyMedium?.copyWith(
      fontSize: 14,
      fontWeight: FontWeight.w400,
      color: Theme.of(context).colorScheme.onSurface,
    );
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _ContextMenuTile(
            icon: Icons.check_box_outline_blank,
            label: l10n.select,
            onTap: onSelect,
            textStyle: textStyle,
          ),
          _ContextMenuTile(
            icon: Icons.edit_outlined,
            label: l10n.edit,
            onTap: onEdit,
            textStyle: textStyle,
          ),
          _ContextMenuTile(
            icon: Icons.delete_outline,
            label: l10n.deleteAction,
            onTap: onDelete,
            textStyle: textStyle?.copyWith(color: Colors.red),
            iconColor: Colors.red,
          ),
        ],
      ),
    );
  }
}

class _ContextMenuTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback? onTap;
  final TextStyle? textStyle;
  final Color? iconColor;

  const _ContextMenuTile({
    required this.icon,
    required this.label,
    this.onTap,
    this.textStyle,
    this.iconColor,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(8),
      onTap: () {
        Navigator.of(context).pop();
        onTap?.call();
      },
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        child: Row(
          children: [
            Icon(icon, size: 18, color: iconColor ?? Theme.of(context).iconTheme.color),
            const SizedBox(width: 12),
            Text(label, style: textStyle),
          ],
        ),
      ),
    );
  }
} 