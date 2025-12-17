import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart'; // ignore: depend_on_referenced_packages
import '../../../../core/localization/app_localizations.dart';
import '../../../../core/theme/app_theme.dart';
import '../../domain/entities/wallet.dart';
import '../../domain/entities/wallet_balance.dart';
import '../wallets_list_screen.dart';
import '../../../../shared/widgets/custom_button.dart';
import '../../../../shared/widgets/custom_search_bar.dart';
import '../../../../shared/widgets/custom_dropdown.dart';
import '../../../../shared/widgets/custom_toggle.dart';

class WalletsListScreenDesktop extends StatelessWidget {
  final WalletsListScreenState state;

  const WalletsListScreenDesktop({super.key, required this.state});

  void _openFiltersSheet(BuildContext context) {
    final l10n = AppLocalizations.of(context);

    showGeneralDialog(
      context: context,
      barrierDismissible: true,
      barrierLabel: l10n?.filters ?? 'Filters',
      barrierColor: Colors.black38,
      pageBuilder: (context, animation, secondaryAnimation) {
        return Align(
          alignment: Alignment.centerRight,
          child: FractionallySizedBox(
            widthFactor: 0.32,
            child: _WalletsFilterSheet(state: state),
          ),
        );
      },
      transitionBuilder: (context, animation, secondaryAnimation, child) {
        final offsetAnimation = Tween<Offset>(
          begin: const Offset(1, 0),
          end: Offset.zero,
        ).animate(CurvedAnimation(parent: animation, curve: Curves.easeOut));
        return SlideTransition(position: offsetAnimation, child: child);
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final wallets = state.filteredAndSortedWallets;
    final currencyFormat = NumberFormat.currency(
      locale: l10n?.locale.languageCode == 'ru' ? 'ru_RU' : 'en_US',
      symbol: l10n?.locale.languageCode == 'ru' ? '₽' : '\$',
      decimalDigits: 2,
    );

    return Scaffold(
      backgroundColor: AppTheme.backgroundColor,
      body: Column(
        children: [
          Container(
            padding: const EdgeInsets.fromLTRB(32, 28, 32, 20),
            decoration: const BoxDecoration(color: AppTheme.surfaceColor),
            child: Column(
              children: [
                Row(
                  children: [
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
                              tooltip: l10n?.refresh ?? 'Обновить',
                              padding: EdgeInsets.zero,
                              constraints: const BoxConstraints(),
                            ),
                          ],
                        ),
                        Text(
                          state.isSelectionMode
                              ? '${l10n?.selectedItems ?? 'Selected'}: ${state.selectedWalletIds.length}'
                              : '${wallets.length} ${state.getWalletsCountText(wallets.length)}',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w400,
                            color: state.isSelectionMode
                                ? AppTheme.primaryColor
                                : AppTheme.textSecondary,
                          ),
                        ),
                      ],
                    ),
                    const Spacer(),
                    if (state.isSelectionMode) ...[
                      TextButton(
                        onPressed: state.clearSelection,
                        style: TextButton.styleFrom(
                          backgroundColor: Colors.grey[100],
                          foregroundColor: AppTheme.textSecondary,
                          padding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 10,
                          ),
                        ),
                        child: Text(l10n?.cancelSelection ?? 'Cancel'),
                      ),
                      const SizedBox(width: 8),
                      TextButton(
                        onPressed: state.selectAll,
                        style: TextButton.styleFrom(
                          backgroundColor: AppTheme.subtleBackgroundColor,
                          foregroundColor: AppTheme.primaryColor,
                          padding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 10,
                          ),
                        ),
                        child: Text(l10n?.selectAll ?? 'Select all'),
                      ),
                      const SizedBox(width: 8),
                      CustomButton(
                        text: l10n?.deleteAction ?? 'Delete',
                        onPressed: state.deleteBulkWallets,
                        color: AppTheme.errorColor,
                        icon: Icons.delete_outline,
                      ),
                    ] else ...[
                      CustomSearchBar(
                        value: state.searchQuery,
                        onChanged: state.setSearchQuery,
                        hintText: '${l10n?.search ?? 'Поиск'}...',
                        width: 280,
                      ),
                      const SizedBox(width: 16),
                      _FilterButton(
                        onPressed: () => _openFiltersSheet(context),
                        hasActiveFilters: state.hasActiveFilters,
                        text: l10n?.filters ?? 'Filters',
                      ),
                      if (state.hasActiveFilters) ...[
                        const SizedBox(width: 8),
                        TextButton(
                          onPressed: state.resetFilters,
                          child: Text(l10n?.resetFilters ?? 'Reset filters'),
                        ),
                      ],
                      const SizedBox(width: 16),
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
          Expanded(
            child: Container(
              color: AppTheme.surfaceColor,
              child: state.isLoading
                  ? Center(
                      child: CircularProgressIndicator(
                        strokeWidth: 3,
                        valueColor: AlwaysStoppedAnimation<Color>(
                          AppTheme.brightPrimaryColor,
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
                      child: wallets.isEmpty
                          ? Center(
                              child: Text(
                                l10n?.notFound ?? 'Ничего не найдено',
                                style: TextStyle(
                                  color: AppTheme.textSecondary,
                                  fontSize: 16,
                                ),
                              ),
                            )
                          : Column(
                              children: [
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 32,
                                    vertical: 16,
                                  ),
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
                                          (l10n?.walletName ?? 'Название')
                                              .toUpperCase(),
                                          style: Theme.of(context)
                                              .textTheme
                                              .labelMedium
                                              ?.copyWith(
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
                                          (l10n?.walletType ?? 'Тип')
                                              .toUpperCase(),
                                          style: Theme.of(context)
                                              .textTheme
                                              .labelMedium
                                              ?.copyWith(
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
                                          (l10n?.walletBalance ?? 'Баланс')
                                              .toUpperCase(),
                                          style: Theme.of(context)
                                              .textTheme
                                              .labelMedium
                                              ?.copyWith(
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
                                          (l10n?.statusHeader ?? 'Статус')
                                              .toUpperCase(),
                                          style: Theme.of(context)
                                              .textTheme
                                              .labelMedium
                                              ?.copyWith(
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
                                Expanded(
                                  child: ListView.builder(
                                    itemCount: wallets.length,
                                    itemBuilder: (context, index) {
                                      final wallet = wallets[index];
                                      final balance =
                                          state.walletBalances[wallet.id];
                                      final isSelected = state
                                          .selectedWalletIds
                                          .contains(wallet.id);

                                      return _WalletRow(
                                        wallet: wallet,
                                        balance: balance,
                                        currencyFormat: currencyFormat,
                                        l10n: l10n,
                                        isSelected: isSelected,
                                        isSelectionMode: state.isSelectionMode,
                                        onTap: () {
                                          if (state.isSelectionMode) {
                                            state.toggleSelection(wallet.id);
                                          } else {
                                            context.go('/wallets/${wallet.id}');
                                          }
                                        },
                                        onToggleSelection: () =>
                                            state.toggleSelection(wallet.id),
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

class _WalletRow extends StatefulWidget {
  final Wallet wallet;
  final WalletBalance? balance;
  final NumberFormat currencyFormat;
  final AppLocalizations? l10n;
  final bool isSelected;
  final bool isSelectionMode;
  final VoidCallback onTap;
  final VoidCallback onToggleSelection;

  const _WalletRow({
    required this.wallet,
    required this.balance,
    required this.currencyFormat,
    required this.l10n,
    required this.isSelected,
    required this.isSelectionMode,
    required this.onTap,
    required this.onToggleSelection,
  });

  @override
  State<_WalletRow> createState() => _WalletRowState();
}

class _WalletRowState extends State<_WalletRow> with TickerProviderStateMixin {
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
    final typeLabel = widget.wallet.isPersonalWallet
        ? (widget.l10n?.personal ?? 'Personal')
        : (widget.l10n?.investor ?? 'Investor');
    final statusLabel = widget.wallet.status == WalletStatus.archived
        ? (widget.l10n?.statusArchived ?? 'Archived')
        : (widget.l10n?.statusActive ?? 'Active');
    final statusColor = widget.wallet.status == WalletStatus.archived
        ? AppTheme.errorColor
        : AppTheme.successColor;

    return MouseRegion(
      onEnter: (_) => _hoverController.forward(),
      onExit: (_) => _hoverController.reverse(),
      child: GestureDetector(
        onTap: widget.onTap,
        onLongPress: widget.onToggleSelection,
        child: AnimatedBuilder(
          animation: _hoverAnimation,
          builder: (context, child) {
            return Container(
              height: 48,
              padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 12),
              decoration: BoxDecoration(
                color: widget.isSelected
                    ? AppTheme.primaryColor.withOpacity(0.1)
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
                ),
              ),
              child: Row(
                children: [
                  Expanded(
                    flex: 3,
                    child: Text(
                      widget.wallet.name,
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                            fontWeight: FontWeight.w500,
                            fontSize: 14,
                          ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  Expanded(
                    flex: 2,
                    child: Text(
                      typeLabel,
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                            fontSize: 14,
                            fontWeight: FontWeight.w400,
                          ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  Expanded(
                    flex: 2,
                    child: Text(
                      widget.currencyFormat
                          .format(widget.balance?.balance ?? 0),
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                            fontSize: 14,
                            fontWeight: FontWeight.w400,
                          ),
                    ),
                  ),
                  Expanded(
                    flex: 2,
                    child: Text(
                      statusLabel,
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                            color: statusColor,
                            fontWeight: FontWeight.w500,
                            fontSize: 14,
                          ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }
}

class _WalletsFilterSheet extends StatefulWidget {
  final WalletsListScreenState state;

  const _WalletsFilterSheet({required this.state});

  @override
  State<_WalletsFilterSheet> createState() => _WalletsFilterSheetState();
}

class _WalletsFilterSheetState extends State<_WalletsFilterSheet> {
  late String _status;
  late String _type;
  late String _sortBy;
  late bool _ascending;

  WalletsListScreenState get state => widget.state;

  @override
  void initState() {
    super.initState();
    _status = state.statusFilter;
    _type = state.typeFilter;
    _sortBy = state.sortBy;
    _ascending = state.sortAscending;
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);

    return Material(
      color: AppTheme.surfaceColor,
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      l10n?.filters ?? 'Filters',
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.w600,
                          ),
                    ),
                  ),
                  IconButton(
                    onPressed: () => Navigator.of(context).pop(),
                    icon: const Icon(Icons.close),
                  ),
                ],
              ),
              const SizedBox(height: 24),
              _buildDropdown(
                label: l10n?.status ?? 'Status',
                value: _status,
                items: state.getStatusFilterOptions(),
                onChanged: (value) {
                  setState(() => _status = value ?? _status);
                  state.setStatusFilter(_status);
                },
              ),
              const SizedBox(height: 16),
              _buildDropdown(
                label: l10n?.walletType ?? 'Type',
                value: _type,
                items: state.getTypeFilterOptions(),
                onChanged: (value) {
                  setState(() => _type = value ?? _type);
                  state.setTypeFilter(_type);
                },
              ),
              const SizedBox(height: 16),
              _buildDropdown(
                label: l10n?.sortBy ?? 'Sort by',
                value: _sortBy,
                items: state.getSortOptions(),
                onChanged: (value) {
                  setState(() => _sortBy = value ?? _sortBy);
                  state.setSortBy(_sortBy);
                },
              ),
              const SizedBox(height: 12),
              CustomToggle<bool>(
                value: _ascending,
                onChanged: (value) {
                  setState(() => _ascending = value);
                  state.setSortAscending(_ascending);
                },
                options: [
                  CustomToggleOption<bool>(
                    value: true,
                    label: l10n?.ascending ?? 'Ascending',
                    icon: Icons.arrow_upward,
                  ),
                  CustomToggleOption<bool>(
                    value: false,
                    label: l10n?.descending ?? 'Descending',
                    icon: Icons.arrow_downward,
                  ),
                ],
              ),
              const Spacer(),
              OutlinedButton(
                onPressed: () {
                  state.resetFilters();
                  Navigator.of(context).pop();
                },
                child: Text(l10n?.resetFilters ?? 'Reset filters'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDropdown({
    required String label,
    required String value,
    required Map<String, String> items,
    required ValueChanged<String?> onChanged,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: AppTheme.textPrimary,
          ),
        ),
        const SizedBox(height: 8),
        CustomDropdown<String>(
          value: items.containsKey(value) ? value : items.keys.first,
          items: items,
          onChanged: onChanged,
          width: double.infinity,
        ),
      ],
    );
  }
}

class _FilterButton extends StatelessWidget {
  final VoidCallback onPressed;
  final bool hasActiveFilters;
  final String text;

  const _FilterButton({
    required this.onPressed,
    required this.hasActiveFilters,
    required this.text,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 36,
      decoration: BoxDecoration(
        color: hasActiveFilters 
            ? AppTheme.primaryColor.withOpacity(0.1)
            : AppTheme.subtleBackgroundColor,
        border: Border.all(
          color: hasActiveFilters 
              ? AppTheme.primaryColor.withOpacity(0.3)
              : AppTheme.subtleBorderColor,
          width: 1,
        ),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onPressed,
          borderRadius: BorderRadius.circular(8),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.tune_rounded,
                  size: 18,
                  color: hasActiveFilters
                      ? AppTheme.primaryColor
                      : AppTheme.textSecondary,
                ),
                const SizedBox(width: 8),
                Text(
                  text,
                  style: TextStyle(
                    color: hasActiveFilters
                        ? AppTheme.primaryColor
                        : AppTheme.textSecondary,
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                    fontFamily: 'Inter',
                  ),
                ),
                if (hasActiveFilters) ...[
                  const SizedBox(width: 6),
                  Container(
                    width: 6,
                    height: 6,
                    decoration: BoxDecoration(
                      color: AppTheme.primaryColor,
                      shape: BoxShape.circle,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}
