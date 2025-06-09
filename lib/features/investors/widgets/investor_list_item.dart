import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../../core/theme/app_theme.dart';
import '../domain/entities/investor.dart';
import '../../../shared/widgets/custom_contextual_dialog.dart';

class InvestorListItem extends StatefulWidget {
  final Investor investor;
  final VoidCallback onTap;
  final VoidCallback? onEdit;
  final VoidCallback? onDelete;
  final VoidCallback? onSelect;

  const InvestorListItem({
    super.key,
    required this.investor,
    required this.onTap,
    this.onEdit,
    this.onDelete,
    this.onSelect,
  });

  @override
  State<InvestorListItem> createState() => _InvestorListItemState();
}

class _InvestorListItemState extends State<InvestorListItem> with TickerProviderStateMixin {
  bool _isHovered = false;
  
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
    final currencyFormat = NumberFormat.currency(
      locale: 'ru_RU',
      symbol: '₽',
      decimalDigits: 0,
    );

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
            child: _InvestorContextMenu(
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
                      flex: 2,
                      child: Padding(
                        padding: const EdgeInsets.only(right: 16),
                        child: Text(
                          widget.investor.fullName,
                          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                            fontWeight: FontWeight.w500,
                            fontSize: 14,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ),
                    // Investment Amount
                    Expanded(
                      flex: 1,
                      child: Padding(
                        padding: const EdgeInsets.only(right: 20),
                        child: Text(
                          currencyFormat.format(widget.investor.investmentAmount),
                          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                            fontSize: 14,
                            fontWeight: FontWeight.w500,
                            color: AppTheme.primaryColor,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ),
                    // Investor Percentage
                    Expanded(
                      flex: 1,
                      child: Padding(
                        padding: const EdgeInsets.only(right: 20),
                        child: Text(
                          '${widget.investor.investorPercentage.toStringAsFixed(1)}%',
                          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                            fontSize: 14,
                            fontWeight: FontWeight.w400,
                          ),
                          textAlign: TextAlign.start,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ),
                    // User Percentage
                    Expanded(
                      flex: 1,
                      child: Padding(
                        padding: const EdgeInsets.only(right: 20),
                        child: Text(
                          '${widget.investor.userPercentage.toStringAsFixed(1)}%',
                          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                            fontSize: 14,
                            fontWeight: FontWeight.w400,
                          ),
                          textAlign: TextAlign.start,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ),
                    // Created Date
                    Expanded(
                      flex: 1,
                      child: Text(
                        dateFormat.format(widget.investor.createdAt),
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          fontSize: 14,
                          fontWeight: FontWeight.w400,
                          color: AppTheme.textSecondary,
                        ),
                        textAlign: TextAlign.start,
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

class _InvestorContextMenu extends StatelessWidget {
  final VoidCallback? onSelect;
  final VoidCallback? onEdit;
  final VoidCallback? onDelete;

  const _InvestorContextMenu({this.onSelect, this.onEdit, this.onDelete});

  @override
  Widget build(BuildContext context) {
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
            label: 'Выбрать',
            onTap: onSelect,
            textStyle: textStyle,
          ),
          _ContextMenuTile(
            icon: Icons.edit_outlined,
            label: 'Редактировать',
            onTap: onEdit,
            textStyle: textStyle,
          ),
          _ContextMenuTile(
            icon: Icons.delete_outline,
            label: 'Удалить',
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