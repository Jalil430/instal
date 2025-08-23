import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/localization/app_localizations.dart';
import '../../../../shared/widgets/custom_contextual_dialog.dart';
import '../../domain/entities/wallet.dart';
import '../../domain/entities/wallet_balance.dart';
import '../wallets_list_screen.dart';
import '../../widgets/wallet_list_item.dart';
import '../../../../shared/widgets/analytics_card.dart';
import '../../../../shared/widgets/custom_button.dart';

class WalletsListScreenDesktop extends StatelessWidget {
  final WalletsListScreenState state;

  const WalletsListScreenDesktop({
    super.key,
    required this.state,
  });

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final currencyFormat = NumberFormat.currency(
      locale: l10n?.locale.languageCode == 'ru' ? 'ru_RU' : 'en_US',
      symbol: l10n?.locale.languageCode == 'ru' ? '₽' : '\$',
      decimalDigits: 2,
    );

    return Scaffold(
      backgroundColor: Colors.white,
      body: Column(
        children: [
          // Enhanced Header with search and sort - matching clients screen pattern
          Container(
            padding: const EdgeInsets.fromLTRB(32, 28, 32, 20),
            decoration: const BoxDecoration(
              color: AppTheme.surfaceColor,
            ),
            child: Column(
              children: [
                // Title and Actions Row
                Row(
                  children: [
                    // Title without Icon
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Text(
                              l10n?.wallets ?? 'Кошельки',
                              style: const TextStyle(
                                fontSize: 20,
                                fontWeight: FontWeight.w600,
                                letterSpacing: -0.5,
                              ),
                            ),
                            const SizedBox(width: 12),
                            IconButton(
                              icon: const Icon(Icons.refresh, size: 20),
                              onPressed: state.forceRefresh,
                              tooltip: 'Обновить',
                              padding: EdgeInsets.zero,
                              constraints: const BoxConstraints(),
                            ),
                          ],
                        ),
                        Text(
                          state.isSelectionMode
                              ? '${l10n?.selectedItems ?? 'Selected'}: ${state.selectedWalletIds.length}'
                              : '${state.filteredAndSortedWallets.length} ${state.getWalletsCountText(state.filteredAndSortedWallets.length)}',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w400,
                            color: state.isSelectionMode ? AppTheme.primaryColor : AppTheme.textSecondary,
                          ),
                        ),
                      ],
                    ),
                    const Spacer(),
                    // Show different controls based on selection mode
                    if (state.isSelectionMode) ...[
                      // Clear selection button - light grey
                      TextButton(
                        onPressed: state.clearSelection,
                        style: TextButton.styleFrom(
                          backgroundColor: Colors.grey[100],
                          foregroundColor: AppTheme.textSecondary,
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                        ),
                        child: Text(l10n?.cancelSelection ?? 'Cancel Selection'),
                      ),
                      const SizedBox(width: 12),
                      // Delete button - red
                      TextButton(
                        onPressed: state.deleteBulkWallets,
                        style: TextButton.styleFrom(
                          backgroundColor: AppTheme.errorColor.withOpacity(0.1),
                          foregroundColor: AppTheme.errorColor,
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                        ),
                        child: Text(l10n?.delete ?? 'Delete'),
                      ),
                    ] else ...[
                      // Custom Add button
                      CustomButton(
                        text: l10n?.createWallet ?? 'Создать кошелек',
                        onPressed: () => state.showCreateWalletDialog(),
                      ),
                    ],
                  ],
                ),


              ],
            ),
          ),

          // Wallets table section (matching installments/clients design)
          Expanded(
            child: Container(
              color: AppTheme.surfaceColor,
              child: state.isLoading
                  ? Center(
                      child: Container(
                        padding: const EdgeInsets.all(20),
                        child: CircularProgressIndicator(
                          strokeWidth: 3,
                          valueColor: AlwaysStoppedAnimation<Color>(AppTheme.brightPrimaryColor),
                        ),
                      ),
                    )
                  : Container(
                      margin: const EdgeInsets.symmetric(horizontal: 16),
                      decoration: BoxDecoration(
                        color: AppTheme.surfaceColor,
                        borderRadius: BorderRadius.circular(12),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.02),
                            offset: const Offset(0, 1),
                            blurRadius: 3,
                            spreadRadius: 0,
                          ),
                        ],
                      ),
                      child: Column(
                        children: [
                          // Table Header
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
                            decoration: BoxDecoration(
                              color: AppTheme.subtleBackgroundColor,
                              borderRadius: const BorderRadius.only(
                                topLeft: Radius.circular(12),
                                topRight: Radius.circular(12),
                              ),
                              border: Border(
                                bottom: BorderSide(
                                  color: AppTheme.subtleBorderColor,
                                  width: 1,
                                ),
                              ),
                            ),
                            child: Row(
                              children: [
                                Expanded(
                                  flex: 3,
                                  child: Text(
                                    l10n?.walletName?.toUpperCase() ?? 'НАЗВАНИЕ КОШЕЛЬКА',
                                    style: Theme.of(context).textTheme.labelMedium?.copyWith(
                                          color: AppTheme.textSecondary,
                                          fontWeight: FontWeight.w400,
                                          fontSize: 12,
                                          letterSpacing: 0.5,
                                        ),
                                  ),
                                ),
                                Expanded(
                                  flex: 2,
                                  child: Text(
                                    l10n?.walletType?.toUpperCase() ?? 'ТИП',
                                    style: Theme.of(context).textTheme.labelMedium?.copyWith(
                                          color: AppTheme.textSecondary,
                                          fontWeight: FontWeight.w400,
                                          fontSize: 12,
                                          letterSpacing: 0.5,
                                        ),
                                  ),
                                ),
                                Expanded(
                                  flex: 2,
                                  child: Text(
                                    l10n?.walletBalance?.toUpperCase() ?? 'БАЛАНС',
                                    style: Theme.of(context).textTheme.labelMedium?.copyWith(
                                          color: AppTheme.textSecondary,
                                          fontWeight: FontWeight.w400,
                                          fontSize: 12,
                                          letterSpacing: 0.5,
                                        ),
                                  ),
                                ),
                                if (state.filteredAndSortedWallets.any((w) => w.isInvestorWallet)) ...[
                                  Expanded(
                                    flex: 3,
                                    child: Text(
                                      'ИНВЕСТИЦИОННЫЕ ДЕТАЛИ',
                                      style: Theme.of(context).textTheme.labelMedium?.copyWith(
                                            color: AppTheme.textSecondary,
                                            fontWeight: FontWeight.w400,
                                            fontSize: 12,
                                            letterSpacing: 0.5,
                                          ),
                                    ),
                                  ),
                                ],
                                Container(
                                  width: 120,
                                  alignment: Alignment.center,
                                  child: Text(
                                    (l10n?.edit ?? 'Редактировать').toUpperCase(),
                                    style: Theme.of(context).textTheme.labelMedium?.copyWith(
                                          color: AppTheme.textSecondary,
                                          fontWeight: FontWeight.w400,
                                          fontSize: 12,
                                          letterSpacing: 0.5,
                                        ),
                                  ),
                                ),
                              ],
                            ),
                          ),

                          // Table Content
                          Expanded(
                            child: state.filteredAndSortedWallets.isEmpty
                                ? Center(
                                    child: Text(
                                      l10n?.notFound ?? 'Ничего не найдено',
                                      style: TextStyle(
                                        color: AppTheme.textSecondary,
                                        fontSize: 16,
                                        fontWeight: FontWeight.w400,
                                      ),
                                    ),
                                  )
                                : ListView.builder(
                                    padding: EdgeInsets.zero,
                                    itemCount: state.filteredAndSortedWallets.length,
                                    itemBuilder: (context, index) {
                                      final wallet = state.filteredAndSortedWallets[index];
                                      final balance = state.walletBalances[wallet.id];

                                      return _WalletListItem(
                                        wallet: wallet,
                                        balance: balance,
                                        currencyFormat: currencyFormat,
                                        showInvestorDetails: state.filteredAndSortedWallets.any((w) => w.isInvestorWallet),
                                        isSelected: state.selectedWalletIds.contains(wallet.id),
                                        isSelectionMode: state.isSelectionMode,
                                        onTap: () {
                                          if (state.isSelectionMode) {
                                            state.toggleSelection(wallet.id);
                                          } else {
                                            context.go('/wallets/${wallet.id}');
                                          }
                                        },
                                        onEdit: () => state.showEditWalletDialog(wallet),
                                        onDelete: () => state.deleteWallet(wallet),
                                        onSelect: () => state.toggleSelection(wallet.id),
                                      );
                                    },
                                  ),
                          ),
                        ],
                      ),
                    ),
            ),
          ),
        ],
      ),
    );
  }
}

class _WalletListItem extends StatefulWidget {
  final Wallet wallet;
  final WalletBalance? balance;
  final NumberFormat currencyFormat;
  final bool showInvestorDetails;
  final bool isSelected;
  final bool isSelectionMode;
  final VoidCallback onTap;
  final VoidCallback onEdit;
  final VoidCallback onDelete;
  final VoidCallback onSelect;

  const _WalletListItem({
    required this.wallet,
    required this.balance,
    required this.currencyFormat,
    required this.showInvestorDetails,
    required this.isSelected,
    required this.isSelectionMode,
    required this.onTap,
    required this.onEdit,
    required this.onDelete,
    required this.onSelect,
  });

  @override
  State<_WalletListItem> createState() => _WalletListItemState();
}

class _WalletListItemState extends State<_WalletListItem> with TickerProviderStateMixin {
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
    return Column(
      children: [
        MouseRegion(
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
                child: _WalletContextMenu(
                  onSelect: widget.onSelect,
                  onEdit: widget.onEdit,
                  onDelete: widget.onDelete,
                ),
                width: 200,
                estimatedHeight: 120,
              );
            },
            child: AnimatedBuilder(
              animation: _hoverAnimation,
              builder: (context, child) {
                // Define selection color
                final Color selectionColor = const Color(0xFFE3F2FD); // Light blue selection color

                return Container(
                  margin: const EdgeInsets.symmetric(horizontal: 0, vertical: 0),
                  decoration: BoxDecoration(
                    color: widget.isSelected
                        ? selectionColor // Use selection color when selected
                        : Color.lerp(
                            AppTheme.surfaceColor,
                            AppTheme.backgroundColor,
                            _hoverAnimation.value * 0.6,
                          ),
                    border: Border(
                      bottom: BorderSide(
                        color: AppTheme.borderColor.withOpacity(0.3),
                        width: 1,
                      ),
                      left: widget.isSelected
                          ? BorderSide(color: AppTheme.primaryColor, width: 3) // Left border for selected items
                          : BorderSide.none,
                    ),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
                    child: Row(
                      children: [
                        // Wallet Name
                        Expanded(
                          flex: 3,
                          child: Text(
                            widget.wallet.name,
                            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w500,
                                  color: AppTheme.textPrimary,
                                ),
                          ),
                        ),
                        // Wallet Type
                        Expanded(
                          flex: 2,
                          child: Padding(
                            padding: const EdgeInsets.only(right: 16),
                            child: Row(
                              children: [
                                Icon(
                                  widget.wallet.isPersonalWallet ? Icons.account_balance_wallet : Icons.trending_up,
                                  size: 18,
                                  color: widget.wallet.isPersonalWallet ? AppTheme.primaryColor : AppTheme.successColor,
                                ),
                                const SizedBox(width: 8),
                                Text(
                                  widget.wallet.isPersonalWallet ? 'Личный' : 'Инвестор',
                                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                        fontSize: 14,
                                        color: widget.wallet.isPersonalWallet ? AppTheme.primaryColor : AppTheme.successColor,
                                        fontWeight: FontWeight.w500,
                                      ),
                                ),
                              ],
                            ),
                          ),
                        ),
                        // Balance
                        Expanded(
                          flex: 2,
                          child: Text(
                            widget.balance != null ? widget.currencyFormat.format(widget.balance!.balance) : '0.00 ₽',
                            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w600,
                                  color: AppTheme.textPrimary,
                                ),
                          ),
                        ),
                        // Investor Details (if any investor wallets exist)
                        if (widget.showInvestorDetails) ...[
                          Expanded(
                            flex: 3,
                            child: widget.wallet.isInvestorWallet
                                ? Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        'Доход: ${widget.wallet.investorPercentage}% / ${widget.wallet.userPercentage}%',
                                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                              fontSize: 12,
                                              color: AppTheme.textSecondary,
                                              fontWeight: FontWeight.w400,
                                            ),
                                      ),
                                      const SizedBox(height: 4),
                                      Text(
                                        'Инвестиция: ${widget.currencyFormat.format(widget.wallet.investmentAmount!)}',
                                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                              fontSize: 12,
                                              color: AppTheme.textSecondary,
                                              fontWeight: FontWeight.w400,
                                            ),
                                      ),
                                    ],
                                  )
                                : const SizedBox(),
                          ),
                        ],
                        // Actions
                        Container(
                          width: 120,
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              IconButton(
                                onPressed: widget.onEdit,
                                icon: const Icon(Icons.edit, size: 18),
                                tooltip: 'Редактировать',
                                padding: EdgeInsets.zero,
                                constraints: const BoxConstraints(),
                              ),
                              const SizedBox(width: 16),
                              IconButton(
                                onPressed: widget.onDelete,
                                icon: const Icon(Icons.delete, size: 18),
                                tooltip: 'Удалить',
                                padding: EdgeInsets.zero,
                                constraints: const BoxConstraints(),
                                color: AppTheme.errorColor,
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
        ),
      ],
    );
  }
}

class _WalletContextMenu extends StatelessWidget {
  final VoidCallback? onSelect;
  final VoidCallback? onEdit;
  final VoidCallback? onDelete;

  const _WalletContextMenu({
    this.onSelect,
    this.onEdit,
    this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
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
            icon: Icons.check,
            label: l10n?.select ?? 'Выбрать',
            onTap: onSelect,
            textStyle: textStyle,
          ),
          const Divider(height: 1),
          _ContextMenuTile(
            icon: Icons.edit,
            label: l10n?.edit ?? 'Редактировать',
            onTap: onEdit,
            textStyle: textStyle,
          ),
          const Divider(height: 1),
          _ContextMenuTile(
            icon: Icons.delete_outline,
            label: l10n?.deleteAction ?? 'Удалить',
            onTap: onDelete,
            textStyle: textStyle?.copyWith(color: AppTheme.errorColor),
            iconColor: AppTheme.errorColor,
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
