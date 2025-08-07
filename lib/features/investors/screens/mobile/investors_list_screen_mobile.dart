import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/localization/app_localizations.dart';
import '../../domain/entities/investor.dart';
import '../investors_list_screen.dart';
import '../../../../shared/widgets/custom_button.dart';
import '../../../../shared/widgets/custom_search_bar.dart';

class InvestorsListScreenMobile extends StatelessWidget {
  final InvestorsListScreenState state;

  const InvestorsListScreenMobile({super.key, required this.state});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final dateFormat = DateFormat('dd.MM.yyyy');
    final currencyFormat = NumberFormat('#,###', 'ru_RU');

    return Scaffold(
      backgroundColor: AppTheme.backgroundColor,
      appBar: AppBar(
        titleSpacing: 16,
        title: state.isSelectionMode
          ? Text(
              l10n?.investors ?? 'Инвесторы',
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w600,
              ),
            )
          : Row(
              children: [
                Text(
                  l10n?.investors ?? 'Инвесторы',
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: CustomSearchBar(
                    value: state.searchQuery,
                    onChanged: (value) => state.setStateWrapper(() => state.searchQuery = value),
                    hintText: '${l10n?.search ?? 'Поиск'} ${(l10n?.investors ?? 'инвесторы').toLowerCase()}...',
                    height: 36,
                  ),
                ),
              ],
            ),
        backgroundColor: AppTheme.surfaceColor,
        elevation: 1,
        actions: [
          if (state.isSelectionMode)
            IconButton(
              icon: const Icon(Icons.close),
              onPressed: state.clearSelection,
              tooltip: l10n?.cancelSelection ?? 'Cancel Selection',
            )
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
                        '${state.selectedInvestorIds.length} ${l10n?.selectedItems ?? 'selected'}',
                        style: const TextStyle(
                          fontWeight: FontWeight.w500,
                          color: AppTheme.primaryColor,
                        ),
                      ),
                      const Spacer(),
                      _buildPopupMenu(context),
                    ],
                  ),
                ),
              )
            : null,
      ),
      body: state.isLoading
          ? const Center(
              child: CircularProgressIndicator(),
            )
          : state.filteredAndSortedInvestors.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.search_off,
                        size: 64,
                        color: Colors.grey[400],
                      ),
                      const SizedBox(height: 16),
                      Text(
                        l10n?.notFound ?? 'Ничего не найдено',
                        style: TextStyle(
                          fontSize: 16,
                          color: Colors.grey[600],
                        ),
                      ),
                    ],
                  ),
                )
              : RefreshIndicator(
                  onRefresh: () async {
                    state.forceRefresh();
                    // Need to return a future to satisfy RefreshIndicator
                    return Future.value();
                  },
                  child: ListView.builder(
                    padding: const EdgeInsets.only(top: 8, bottom: 80),
                    itemCount: state.filteredAndSortedInvestors.length,
                    itemBuilder: (context, index) {
                      final investor = state.filteredAndSortedInvestors[index];
                      return _buildInvestorCard(context, investor, dateFormat, currencyFormat);
                    },
                  ),
                ),
      floatingActionButton: state.isSelectionMode
          ? null
          : FloatingActionButton(
              onPressed: state.showCreateInvestorDialog,
              backgroundColor: AppTheme.primaryColor,
              child: const Icon(Icons.add, color: Colors.white),
            ),
    );
  }

  Widget _buildInvestorCard(BuildContext context, Investor investor, DateFormat dateFormat, NumberFormat currencyFormat) {
    final l10n = AppLocalizations.of(context);

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      elevation: 1,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(
          color: state.selectedInvestorIds.contains(investor.id)
              ? AppTheme.primaryColor
              : Colors.transparent,
          width: 2,
        ),
      ),
      child: InkWell(
        onTap: () => state.isSelectionMode
            ? state.toggleSelection(investor.id)
            : context.go('/investors/${investor.id}'),
        onLongPress: () => state.toggleSelection(investor.id),
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Investor name - larger font
              Text(
                investor.fullName,
                style: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w600,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 16),
              
              // Investment amount - larger with more padding
              Row(
                children: [
                  const Icon(
                    Icons.attach_money,
                    size: 20,
                    color: AppTheme.primaryColor,
                  ),
                  const SizedBox(width: 12),
                  Text(
                    currencyFormat.format(investor.investmentAmount) + ' ₽',
                    style: const TextStyle(
                      color: AppTheme.textPrimary,
                      fontSize: 18,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              
              // Investor share percentage
              Row(
                children: [
                  const Icon(
                    Icons.pie_chart_outline,
                    size: 20,
                    color: AppTheme.primaryColor,
                  ),
                  const SizedBox(width: 12),
                  Text.rich(
                    TextSpan(
                      text: '${l10n?.investorShare ?? 'Доля инвестора'}: ',
                      style: const TextStyle(
                        color: AppTheme.textPrimary,
                        fontSize: 16,
                      ),
                      children: [
                        TextSpan(
                          text: '${investor.investorPercentage}%',
                          style: const TextStyle(
                            color: AppTheme.primaryColor,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              
              // User share percentage
              Row(
                children: [
                  const Icon(
                    Icons.person_outline,
                    size: 20,
                    color: AppTheme.primaryColor,
                  ),
                  const SizedBox(width: 12),
                  Text.rich(
                    TextSpan(
                      text: '${l10n?.userShare ?? 'Доля пользователя'}: ',
                      style: const TextStyle(
                        color: AppTheme.textPrimary,
                        fontSize: 16,
                      ),
                      children: [
                        TextSpan(
                          text: '${investor.userPercentage}%',
                          style: const TextStyle(
                            color: AppTheme.primaryColor,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPopupMenu(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    
    return PopupMenuButton<String>(
      icon: const Icon(Icons.more_vert),
      onSelected: (value) {
        switch (value) {
          case 'select_all':
            state.selectAll();
            break;
          case 'delete':
            state.deleteBulkInvestors();
            break;
        }
      },
      itemBuilder: (context) => [
        PopupMenuItem<String>(
          value: 'select_all',
          child: Row(
            children: [
              const Icon(Icons.select_all, size: 18),
              const SizedBox(width: 12),
              Text(l10n?.selectAll ?? 'Select All'),
            ],
          ),
        ),
        const PopupMenuDivider(),
        PopupMenuItem<String>(
          value: 'delete',
          child: Row(
            children: [
              const Icon(
                Icons.delete_outline,
                size: 18,
                color: AppTheme.errorColor,
              ),
              const SizedBox(width: 12),
              Text(
                l10n?.deleteAction ?? 'Delete',
                style: const TextStyle(color: AppTheme.errorColor),
              ),
            ],
          ),
        ),
      ],
    );
  }
} 