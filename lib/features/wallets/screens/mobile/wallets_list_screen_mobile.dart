import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/localization/app_localizations.dart';
import '../../../../shared/widgets/custom_search_bar.dart';
import '../../../../shared/widgets/custom_dropdown.dart';
import '../../../../shared/widgets/custom_button.dart';
import '../../domain/entities/wallet.dart';
import '../../domain/entities/wallet_balance.dart';
import '../wallets_list_screen.dart';
import '../../widgets/wallet_list_item.dart';
import '../../widgets/empty_state.dart';

class WalletsListScreenMobile extends StatelessWidget {
  final WalletsListScreenState state;

  const WalletsListScreenMobile({
    super.key,
    required this.state,
  });

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final totalBalance = state.walletBalances.values.fold<double>(
      0,
      (sum, balance) => sum + balance.balance,
    );

    return Scaffold(
      backgroundColor: AppTheme.backgroundColor,
      appBar: AppBar(
        titleSpacing: 16,
        title: Text(
          l10n?.wallets ?? 'Кошельки',
          style: const TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w600,
          ),
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
          ] else ...[],
        ],
        bottom: state.isSelectionMode
            ? PreferredSize(
                preferredSize: const Size.fromHeight(48),
                child: Container(
                  color: AppTheme.subtleBackgroundColor,
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  child: Row(
                    children: [
                      Text(
                        '${state.selectedWalletIds.length} ${l10n?.selectedItems ?? 'выбрано'}',
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
                        itemBuilder: (context) => [
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
                          child: const Icon(
                            Icons.more_vert,
                            size: 20,
                          ),
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
            child: state.isLoading
                ? const Center(child: CircularProgressIndicator())
                : state.filteredAndSortedWallets.isEmpty
                    ? EmptyState(
                        icon: Icons.account_balance_wallet,
                        title: 'Нет кошельков',
                        description: 'Создайте свой первый кошелек для начала работы',
                        action: CustomButton(
                          text: 'Создать кошелек',
                          onPressed: state.showCreateWalletDialog,
                          color: AppTheme.primaryColor,
                          textColor: Colors.white,
                        ),
                      )
                    : FadeTransition(
                        opacity: state.fadeAnimation,
                        child: ListView.builder(
                          padding: const EdgeInsets.only(bottom: 80),
                          itemCount: state.filteredAndSortedWallets.length,
                          itemBuilder: (context, index) {
                            final wallet = state.filteredAndSortedWallets[index];
                            final balance = state.walletBalances[wallet.id];

                            return WalletListItem(
                              wallet: wallet,
                              balance: balance,
                              isSelected: state.selectedWalletIds.contains(wallet.id),
                              isSelectionMode: state.isSelectionMode,
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
      floatingActionButton: state.isSelectionMode
          ? null
          : FloatingActionButton(
              onPressed: state.showCreateWalletDialog,
              backgroundColor: AppTheme.primaryColor,
              child: const Icon(Icons.add, color: Colors.white),
            ),
    );
  }
}
