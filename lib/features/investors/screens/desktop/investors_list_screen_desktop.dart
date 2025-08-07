import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/localization/app_localizations.dart';
import '../../domain/entities/investor.dart';
import '../investors_list_screen.dart';
import '../../../../shared/widgets/custom_search_bar.dart';
import '../../../../shared/widgets/custom_dropdown.dart';
import '../../../../shared/widgets/custom_button.dart';
import '../../widgets/investor_list_item.dart';

class InvestorsListScreenDesktop extends StatelessWidget {
  final InvestorsListScreenState state;

  const InvestorsListScreenDesktop({super.key, required this.state});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);

    return Scaffold(
      backgroundColor: AppTheme.backgroundColor,
      body: Column(
        children: [
          // Enhanced Header with search and sort
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
                              l10n?.investors ?? 'Инвесторы',
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
                              ? '${l10n?.selectedItems ?? 'Selected'}: ${state.selectedInvestorIds.length}'
                              : '${state.filteredAndSortedInvestors.length} ${state.getInvestorsCountText(state.filteredAndSortedInvestors.length)}',
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
                      CustomButton(
                        text: l10n?.cancelSelection ?? 'Cancel Selection',
                        onPressed: state.clearSelection,
                        color: Colors.grey[100],
                        textColor: AppTheme.textSecondary,
                        showIcon: false,
                        height: 36,
                        fontSize: 13,
                      ),
                      const SizedBox(width: 8),
                      // Select All button - subtle style
                      CustomButton(
                        text: l10n?.selectAll ?? 'Select All',
                        onPressed: state.selectAll,
                        color: AppTheme.subtleBackgroundColor,
                        textColor: AppTheme.primaryColor,
                        showIcon: false,
                        height: 36,
                        fontSize: 13,
                      ),
                      const SizedBox(width: 8),
                      // Delete button - error color
                      CustomButton(
                        text: l10n?.deleteAction ?? 'Delete',
                        onPressed: state.selectedInvestorIds.isNotEmpty ? state.deleteBulkInvestors : null,
                        color: AppTheme.errorColor,
                        icon: Icons.delete_outline,
                        height: 36,
                        fontSize: 13,
                      ),
                    ] else ...[
                      // Regular mode controls
                      // Enhanced Search field
                      CustomSearchBar(
                        value: state.searchQuery,
                        onChanged: (value) => state.setStateWrapper(() => state.searchQuery = value),
                        hintText: '${l10n?.search ?? 'Поиск'} ${(l10n?.investors ?? 'инвесторы').toLowerCase()}...',
                        width: 320,
                      ),
                      const SizedBox(width: 16),
                      // Custom Add button
                      CustomButton(
                        text: l10n?.addInvestor ?? 'Добавить инвестора',
                        onPressed: () => state.showCreateInvestorDialog(),
                      ),
                    ],
                  ],
                ),
              ],
            ),
          ),
          
          // Continuous Table Section
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
                                    l10n?.fullNameHeader ?? 'ПОЛНОЕ ИМЯ',
                                    style: const TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w400,
                                      color: AppTheme.textSecondary,
                                      letterSpacing: 0.3,
                                    ),
                                  ),
                                ),
                                Expanded(
                                  flex: 2,
                                  child: Text(
                                    l10n?.investmentAmountHeader ?? 'СУММА ИНВЕСТИЦИИ',
                                    style: const TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w400,
                                      color: AppTheme.textSecondary,
                                      letterSpacing: 0.3,
                                    ),
                                  ),
                                ),
                                Expanded(
                                  flex: 2,
                                  child: Text(
                                    l10n?.investorShareHeader ?? 'ДОЛЯ ИНВЕСТОРА',
                                    style: const TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w400,
                                      color: AppTheme.textSecondary,
                                      letterSpacing: 0.3,
                                    ),
                                  ),
                                ),
                                Expanded(
                                  flex: 2,
                                  child: Text(
                                    l10n?.userShareHeader ?? 'ДОЛЯ ПОЛЬЗОВАТЕЛЯ',
                                    style: const TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w400,
                                      color: AppTheme.textSecondary,
                                      letterSpacing: 0.3,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          // Table Content
                          Expanded(
                            child: state.filteredAndSortedInvestors.isEmpty
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
                                    itemCount: state.filteredAndSortedInvestors.length,
                                    itemBuilder: (context, index) {
                                      final investor = state.filteredAndSortedInvestors[index];
                                      return InvestorListItem(
                                        investor: investor,
                                        onTap: state.isSelectionMode 
                                            ? () => state.toggleSelection(investor.id)
                                            : () => context.go('/investors/${investor.id}'),
                                        onEdit: () => state.showEditInvestorDialog(investor),
                                        onDelete: () => state.deleteInvestor(investor),
                                        onSelect: () => state.toggleSelection(investor.id),
                                        onSelectionToggle: () => state.toggleSelection(investor.id),
                                        isSelected: state.selectedInvestorIds.contains(investor.id),
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