import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/localization/app_localizations.dart';
import '../../../../shared/widgets/custom_search_bar.dart';
import '../../../../shared/widgets/custom_button.dart';
import '../../../../shared/widgets/custom_dropdown.dart';
import '../../../../shared/widgets/custom_toggle.dart';
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
        title:
            state.isSelectionMode
                ? Text(
                    l10n?.wallets ?? 'Кошельки',
                    style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
                  )
                : Row(
                    children: [
                      Text(
                        l10n?.wallets ?? 'Кошельки',
                        style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: CustomSearchBar(
                          value: state.searchQuery,
                          onChanged: state.setSearchQuery,
                          hintText: '${l10n?.search ?? 'Поиск'}...',
                          height: 36,
                        ),
                      ),
                    ],
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
            final sortOptions = state.getSortOptions();

            Widget buildDropdown({
              required String label,
              required String value,
              required Map<String, String> options,
              required ValueChanged<String> onChanged,
            }) {
              final currentValue =
                  options.containsKey(value) ? value : options.keys.first;
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
                    value: currentValue,
                    items: options,
                    onChanged: (selected) {
                      if (selected != null) {
                        onChanged(selected);
                        setModalState(() {});
                      }
                    },
                    width: double.infinity,
                  ),
                ],
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
                      label: l10n?.status ?? 'Статус',
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
                      label: l10n?.sortBy ?? 'Sort by',
                      value: state.sortBy,
                      options: sortOptions,
                      onChanged: state.setSortBy,
                    ),
                    const SizedBox(height: 12),
                    CustomToggle<bool>(
                      value: state.sortAscending,
                      onChanged: (value) {
                        state.setSortAscending(value);
                        setModalState(() {});
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
