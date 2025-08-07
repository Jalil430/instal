import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/localization/app_localizations.dart';
import '../../domain/entities/client.dart';
import '../clients_list_screen.dart';
import '../../../../shared/widgets/custom_search_bar.dart';
import '../../../../shared/widgets/custom_dropdown.dart';
import '../../../../shared/widgets/custom_button.dart';
import '../../widgets/client_list_item.dart';

class ClientsListScreenDesktop extends StatelessWidget {
  final ClientsListScreenState state;

  const ClientsListScreenDesktop({super.key, required this.state});

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
                              l10n?.clients ?? 'Клиенты',
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
                              ? '${l10n?.selectedItems ?? 'Selected'}: ${state.selectedClientIds.length}'
                              : '${state.filteredAndSortedClients.length} ${state.getClientsCountText(state.filteredAndSortedClients.length)}',
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
                        onPressed: state.selectedClientIds.isNotEmpty ? state.deleteBulkClients : null,
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
                        hintText: '${l10n?.search ?? 'Поиск'} ${(l10n?.clients ?? 'клиенты').toLowerCase()}...',
                        width: 320,
                      ),
                      const SizedBox(width: 16),
                      // Custom Add button
                      CustomButton(
                        text: l10n?.addClient ?? 'Добавить клиента',
                        onPressed: () => state.showCreateClientDialog(),
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
                                    l10n?.contactNumberHeader ?? 'КОНТАКТНЫЙ НОМЕР',
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
                                    l10n?.passportNumberHeader ?? 'НОМЕР ПАСПОРТА',
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
                                    l10n?.addressHeader ?? 'АДРЕС',
                                    style: Theme.of(context).textTheme.labelMedium?.copyWith(
                                          color: AppTheme.textSecondary,
                                          fontWeight: FontWeight.w400,
                                          fontSize: 12,
                                          letterSpacing: 0.5,
                                        ),
                                  ),
                                ),
                                Expanded(
                                  child: Text(
                                    l10n?.creationDateHeader ?? 'ДАТА СОЗДАНИЯ',
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
                            child: state.filteredAndSortedClients.isEmpty
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
                                    itemCount: state.filteredAndSortedClients.length,
                                    itemBuilder: (context, index) {
                                      final client = state.filteredAndSortedClients[index];
                                      return ClientListItem(
                                        client: client,
                                        onTap: state.isSelectionMode 
                                            ? () => state.toggleSelection(client.id)
                                            : () => context.go('/clients/${client.id}'),
                                        onEdit: () => state.showEditClientDialog(client),
                                        onDelete: () => state.deleteClient(client),
                                        onSelect: () => state.toggleSelection(client.id),
                                        onSelectionToggle: () => state.toggleSelection(client.id),
                                        isSelected: state.selectedClientIds.contains(client.id),
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