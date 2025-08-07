import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/localization/app_localizations.dart';
import '../../domain/entities/client.dart';
import '../clients_list_screen.dart';
import '../../../../shared/widgets/custom_button.dart';
import '../../../../shared/widgets/custom_search_bar.dart';

class ClientsListScreenMobile extends StatelessWidget {
  final ClientsListScreenState state;

  const ClientsListScreenMobile({super.key, required this.state});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final dateFormat = DateFormat('dd.MM.yyyy');

    return Scaffold(
      backgroundColor: AppTheme.backgroundColor,
      appBar: AppBar(
        titleSpacing: 16,
        title: state.isSelectionMode
          ? Text(
              l10n?.clients ?? 'Клиенты',
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w600,
              ),
            )
          : Row(
              children: [
                Text(
                  l10n?.clients ?? 'Клиенты',
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
                    hintText: '${l10n?.search ?? 'Поиск'} ${(l10n?.clients ?? 'клиенты').toLowerCase()}...',
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
                        '${state.selectedClientIds.length} ${l10n?.selectedItems ?? 'selected'}',
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
          : state.filteredAndSortedClients.isEmpty
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
                    itemCount: state.filteredAndSortedClients.length,
                    itemBuilder: (context, index) {
                      final client = state.filteredAndSortedClients[index];
                      return _buildClientCard(context, client, dateFormat);
                    },
                  ),
                ),
      floatingActionButton: state.isSelectionMode
          ? null
          : FloatingActionButton(
              onPressed: state.showCreateClientDialog,
              backgroundColor: AppTheme.primaryColor,
              child: const Icon(Icons.add, color: Colors.white),
            ),
    );
  }

  Widget _buildClientCard(BuildContext context, Client client, DateFormat dateFormat) {
    final l10n = AppLocalizations.of(context);

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      elevation: 1,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(
          color: state.selectedClientIds.contains(client.id)
              ? AppTheme.primaryColor
              : Colors.transparent,
          width: 2,
        ),
      ),
      child: InkWell(
        onTap: () => state.isSelectionMode
            ? state.toggleSelection(client.id)
            : context.go('/clients/${client.id}'),
        onLongPress: () => state.toggleSelection(client.id),
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Client name - larger font
              Text(
                client.fullName,
                style: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w600,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 16),
              
              // Contact number - larger with more padding
              Row(
                children: [
                  const Icon(
                    Icons.phone,
                    size: 20,
                    color: AppTheme.primaryColor,
                  ),
                  const SizedBox(width: 12),
                  Text(
                    client.contactNumber,
                    style: const TextStyle(
                      color: AppTheme.textPrimary,
                      fontSize: 18,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              
              // Passport if available - larger with more padding
              if (client.passportNumber?.isNotEmpty == true) ...[
                Row(
                  children: [
                    const Icon(
                      Icons.badge_outlined,
                      size: 20,
                      color: AppTheme.primaryColor,
                    ),
                    const SizedBox(width: 12),
                    Text(
                      client.passportNumber ?? '',
                      style: const TextStyle(
                        color: AppTheme.textPrimary,
                        fontSize: 16,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
              ],
              
              // Address at the bottom with "See more" option
              if (client.address?.isNotEmpty == true) ...[
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Icon(
                      Icons.location_on_outlined,
                      size: 20,
                      color: AppTheme.primaryColor,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _buildTruncatedAddress(context, client.address ?? ''),
                    ),
                  ],
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
  
  Widget _buildTruncatedAddress(BuildContext context, String address) {
    return GestureDetector(
      onTap: () => _showAddressDialog(context, address),
      child: Text(
        address,
        style: const TextStyle(
          color: AppTheme.primaryColor,
          fontSize: 16,
        ),
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
    );
  }
  
  void _showAddressDialog(BuildContext context, String address) {
    final l10n = AppLocalizations.of(context);
    
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(l10n?.address ?? 'Адрес'),
        content: Text(
          address,
          style: const TextStyle(
            fontSize: 16,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: Text(l10n?.close ?? 'Закрыть'),
          ),
        ],
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
            state.deleteBulkClients();
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