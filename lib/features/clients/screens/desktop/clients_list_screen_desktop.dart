import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/localization/app_localizations.dart';
import '../clients_list_screen.dart';
import '../../../../shared/widgets/custom_search_bar.dart';
import '../../../../shared/widgets/custom_button.dart';
import '../../widgets/client_list_item.dart';

class ClientsListScreenDesktop extends StatelessWidget {
  final ClientsListScreenState state;

  const ClientsListScreenDesktop({super.key, required this.state});

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
            widthFactor: 0.3,
            child: _ClientsFilterSheet(state: state),
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
                        onChanged: state.setSearchQuery,
                        hintText: '${l10n?.search ?? 'Поиск'} ${(l10n?.clients ?? 'клиенты').toLowerCase()}...',
                        width: 320,
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
                                        isBusy: state.loadingItemOperations.contains(client.id),
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

class _ClientsFilterSheet extends StatefulWidget {
  final ClientsListScreenState state;

  const _ClientsFilterSheet({required this.state});

  @override
  State<_ClientsFilterSheet> createState() => _ClientsFilterSheetState();
}

class _ClientsFilterSheetState extends State<_ClientsFilterSheet> {
  late String _guarantor;
  late String _creation;
  late String _sortBy;
  late bool _ascending;

  ClientsListScreenState get state => widget.state;

  @override
  void initState() {
    super.initState();
    _guarantor = state.guarantorFilter;
    _creation = state.creationFilter;
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
                label: l10n?.withGuarantor ?? 'Guarantor',
                value: _guarantor,
                items: state.getGuarantorFilterOptions(),
                onChanged: (value) => setState(() => _guarantor = value ?? _guarantor),
              ),
              const SizedBox(height: 16),
              _buildDropdown(
                label: l10n?.creationDate ?? 'Creation date',
                value: _creation,
                items: state.getCreationFilterOptions(),
                onChanged: (value) => setState(() => _creation = value ?? _creation),
              ),
              const SizedBox(height: 16),
              _buildDropdown(
                label: l10n?.sortBy ?? 'Sort by',
                value: _sortBy,
                items: state.getSortOptions(),
                onChanged: (value) => setState(() => _sortBy = value ?? _sortBy),
              ),
              const SizedBox(height: 12),
              SegmentedButton<bool>(
                segments: [
                  ButtonSegment<bool>(
                    value: true,
                    icon: const Icon(Icons.arrow_upward),
                    label: Text(l10n?.ascending ?? 'Ascending'),
                  ),
                  ButtonSegment<bool>(
                    value: false,
                    icon: const Icon(Icons.arrow_downward),
                    label: Text(l10n?.descending ?? 'Descending'),
                  ),
                ],
                selected: {_ascending},
                onSelectionChanged: (value) =>
                    setState(() => _ascending = value.first),
              ),
              const Spacer(),
              Row(
                children: [
                  OutlinedButton(
                    onPressed: () {
                      state.resetFilters();
                      Navigator.of(context).pop();
                    },
                    child: Text(l10n?.resetFilters ?? 'Reset filters'),
                  ),
                  const Spacer(),
                  FilledButton(
                    onPressed: _apply,
                    child: Text(l10n?.apply ?? 'Apply'),
                  ),
                ],
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
    return DropdownButtonFormField<String>(
      value: value,
      decoration: InputDecoration(labelText: label),
      items: items.entries
          .map(
            (entry) => DropdownMenuItem<String>(
              value: entry.key,
              child: Text(entry.value),
            ),
          )
          .toList(),
      onChanged: onChanged,
    );
  }

  void _apply() {
    if (state.guarantorFilter != _guarantor) {
      state.setGuarantorFilter(_guarantor);
    }
    if (state.creationFilter != _creation) {
      state.setCreationFilter(_creation);
    }
    if (state.sortBy != _sortBy) {
      state.setSortBy(_sortBy);
    }
    if (state.sortAscending != _ascending) {
      state.setSortAscending(_ascending);
    }
    Navigator.of(context).pop();
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
      height: 40,
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
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
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
