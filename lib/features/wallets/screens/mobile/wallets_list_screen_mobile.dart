import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/localization/app_localizations.dart';
import '../../../../shared/widgets/custom_search_bar.dart';
import '../../../../shared/widgets/custom_button.dart';
import '../../domain/entities/wallet.dart';
import '../../domain/entities/wallet_balance.dart';
import '../wallets_list_screen.dart';
import '../../widgets/wallet_list_item.dart';
import '../../widgets/empty_state.dart';

class WalletsListScreenMobile extends StatelessWidget {
  final WalletsListScreenState state;

  const WalletsListScreenMobile({super.key, required this.state});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);

    return Scaffold(
      backgroundColor: AppTheme.backgroundColor,
      appBar: AppBar(
        titleSpacing: 16,
        title: Text(
          l10n?.wallets ?? 'Кошельки',
          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
        ),
        backgroundColor: AppTheme.surfaceColor,
        elevation: 1,
        actions: [
          if (state.isSelectionMode) ...[
            IconButton(
              icon: const Icon(Icons.select_all),
              onPressed: state.selectAll,
              tooltip: l10n?.selectAll ?? 'Выбрать все',
            ),
            IconButton(
              icon: const Icon(Icons.delete),
              onPressed: state.deleteBulkWallets,
              tooltip: l10n?.delete ?? 'Удалить',
            ),
            IconButton(
              icon: const Icon(Icons.close),
              onPressed: state.clearSelection,
              tooltip: l10n?.cancelSelection ?? 'Отменить выбор',
            ),
          ] else ...[
            IconButton(
              icon: const Icon(Icons.refresh),
              onPressed: () => state.forceRefresh(),
              tooltip: l10n?.refresh ?? 'Обновить',
            ),
            if (state.hasActiveFilters)
              IconButton(
                icon: const Icon(Icons.filter_alt_off),
                tooltip: l10n?.resetFilters ?? 'Reset filters',
                onPressed: state.resetFilters,
              ),
            IconButton(
              icon: const Icon(Icons.tune),
              onPressed: () => _showFiltersSheet(context),
              tooltip: l10n?.filters ?? 'Filters',
            ),
          ],
        ],
        bottom:
            state.isSelectionMode
                ? PreferredSize(
                  preferredSize: const Size.fromHeight(48),
                  child: Container(
                    color: AppTheme.subtleBackgroundColor,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 8,
                    ),
                    child: Row(
                      children: [
                        Text(
                          '${state.selectedWalletIds.length} ${l10n?.selectedItemsMobile ?? 'selected'}',
                          style: const TextStyle(
                            fontWeight: FontWeight.w500,
                            color: AppTheme.primaryColor,
                          ),
                        ),
                        const Spacer(),
                        PopupMenuButton<String>(
                          onSelected: (action) {
                            switch (action) {
                              case 'delete':
                                state.deleteBulkWallets();
                                break;
                            }
                          },
                          itemBuilder:
                              (context) => [
                                PopupMenuItem(
                                  value: 'delete',
                                  child: Text(l10n?.delete ?? 'Удалить'),
                                ),
                              ],
                          child: Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: AppTheme.surfaceColor,
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: const Icon(Icons.more_vert, size: 20),
                          ),
                        ),
                      ],
                    ),
                  ),
                )
                : null,
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
            child: CustomSearchBar(
              value: state.searchQuery,
              onChanged:
                  (value) =>
                      state.setSearchQuery,
              hintText:
                  '${l10n?.search ?? 'Поиск'} ${(l10n?.wallets ?? 'кошельки').toLowerCase()}...',
              height: 40,
            ),
          ),
          const SizedBox(height: 8),
          // Wallets list
          Expanded(
            child:
                state.isLoading
                    ? const Center(child: CircularProgressIndicator())
                    : state.filteredAndSortedWallets.isEmpty
                    ? EmptyState(
                      icon: Icons.account_balance_wallet,
                      title: l10n?.noWallets ?? 'No wallets',
                      description:
                          l10n?.createFirstWalletDescription ??
                          'Create your first wallet to get started',
                      action: CustomButton(
                        text: l10n?.createWallet ?? 'Создать кошелек',
                        onPressed: state.showCreateWalletDialog,
                        color: AppTheme.primaryColor,
                        textColor: Colors.white,
                      ),
                    )
                    : FadeTransition(
                      opacity: state.fadeAnimation,
                      child: ListView.builder(
                        padding: const EdgeInsets.only(bottom: 80),
                        physics: const AlwaysScrollableScrollPhysics(),
                        itemCount: state.filteredAndSortedWallets.length,
                        itemBuilder: (context, index) {
                          final wallet = state.filteredAndSortedWallets[index];
                          final balance = state.walletBalances[wallet.id];

                          return WalletListItem(
                            wallet: wallet,
                            balance: balance,
                            isSelected: state.selectedWalletIds.contains(
                              wallet.id,
                            ),
                            isSelectionMode: state.isSelectionMode,
                            isBusy: state.loadingItemOperations.contains(
                              wallet.id,
                            ),
                            onTap: () {
                              if (state.isSelectionMode) {
                                state.toggleSelection(wallet.id);
                              } else {
                                context.go('/wallets/${wallet.id}');
                              }
                            },
                            onLongPress: () {
                              state.toggleSelection(wallet.id);
                            },

                            onDelete: () => state.deleteWallet(wallet),
                          );
                        },
                      ),
                    ),
          ),
        ],
      ),
      floatingActionButton:
          state.isSelectionMode
              ? null
              : FloatingActionButton(
                onPressed: state.showCreateWalletDialog,
                backgroundColor: AppTheme.primaryColor,
                child: const Icon(Icons.add, color: Colors.white),
              ),
    );
  }

  void _showFiltersSheet(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      backgroundColor: AppTheme.surfaceColor,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            final statusOptions = state.getStatusFilterOptions();
            final typeOptions = state.getTypeFilterOptions();
            final balanceOptions = state.getBalanceFilterOptions();
            final sortOptions = state.getSortOptions();

            DropdownButtonFormField<String> buildDropdown({
              required String label,
              required String value,
              required Map<String, String> options,
              required ValueChanged<String> onChanged,
            }) {
              return DropdownButtonFormField<String>(
                value: options.containsKey(value) ? value : options.keys.first,
                decoration: InputDecoration(
                  labelText: label,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 12,
                  ),
                ),
                items:
                    options.entries
                        .map(
                          (entry) => DropdownMenuItem<String>(
                            value: entry.key,
                            child: Text(entry.value),
                          ),
                        )
                        .toList(),
                onChanged: (selected) {
                  if (selected != null) {
                    onChanged(selected);
                    setModalState(() {});
                  }
                },
              );
            }

            return Padding(
              padding: EdgeInsets.only(
                left: 16,
                right: 16,
                top: 16,
                bottom: MediaQuery.of(context).viewInsets.bottom + 16,
              ),
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text(
                          l10n?.filters ?? 'Filters',
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const Spacer(),
                        TextButton(
                          onPressed: () {
                            state.resetFilters();
                            setModalState(() {});
                          },
                          child: Text(l10n?.resetFilters ?? 'Reset filters'),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    buildDropdown(
                      label: l10n?.statusHeader ?? 'Статус',
                      value: state.statusFilter,
                      options: statusOptions,
                      onChanged: state.setStatusFilter,
                    ),
                    const SizedBox(height: 16),
                    buildDropdown(
                      label: l10n?.walletType ?? 'Тип кошелька',
                      value: state.typeFilter,
                      options: typeOptions,
                      onChanged: state.setTypeFilter,
                    ),
                    const SizedBox(height: 16),
                    buildDropdown(
                      label: l10n?.walletBalance ?? 'Баланс кошелька',
                      value: state.balanceFilter,
                      options: balanceOptions,
                      onChanged: state.setBalanceFilter,
                    ),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        Expanded(
                          child: buildDropdown(
                            label: l10n?.sortBy ?? 'Sort by',
                            value: state.sortBy,
                            options: sortOptions,
                            onChanged: state.setSortBy,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Tooltip(
                          message:
                              state.sortAscending
                                  ? l10n?.ascending ?? 'Ascending'
                                  : l10n?.descending ?? 'Descending',
                          child: Material(
                            color: Colors.transparent,
                            child: InkWell(
                              borderRadius: BorderRadius.circular(12),
                              onTap: () {
                                state.setSortBy(state.sortBy);
                                setModalState(() {});
                              },
                              child: Container(
                                width: 48,
                                height: 48,
                                decoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(12),
                                  color: AppTheme.subtleBackgroundColor,
                                ),
                                child: Icon(
                                  state.sortAscending
                                      ? Icons.arrow_upward
                                      : Icons.arrow_downward,
                                  color: AppTheme.textSecondary,
                                ),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 24),
                    Align(
                      alignment: Alignment.centerRight,
                      child: ElevatedButton(
                        onPressed: () => Navigator.of(context).pop(),
                        child: Text(l10n?.close ?? 'Close'),
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }
}
