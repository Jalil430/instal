import 'package:flutter/material.dart';
import '../../../core/theme/app_theme.dart';

class SearchSortBar extends StatelessWidget {
  final String searchHint;
  final Map<String, String> sortOptions;
  final String selectedSort;
  final ValueChanged<String> onSearchChanged;
  final ValueChanged<String?> onSortChanged;

  const SearchSortBar({
    super.key,
    required this.searchHint,
    required this.sortOptions,
    required this.selectedSort,
    required this.onSearchChanged,
    required this.onSortChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: const BoxDecoration(
        color: AppTheme.surfaceColor,
        border: Border(
          bottom: BorderSide(
            color: AppTheme.borderColor,
            width: 1,
          ),
        ),
      ),
      child: Row(
        children: [
          // Search Field
          Expanded(
            child: Container(
              height: 40,
              decoration: BoxDecoration(
                color: AppTheme.backgroundColor,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: AppTheme.borderColor,
                ),
              ),
              child: TextField(
                onChanged: onSearchChanged,
                style: Theme.of(context).textTheme.bodyMedium,
                decoration: InputDecoration(
                  hintText: searchHint,
                  hintStyle: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: AppTheme.textHint,
                      ),
                  prefixIcon: const Icon(
                    Icons.search,
                    size: 20,
                    color: AppTheme.textHint,
                  ),
                  border: InputBorder.none,
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 10,
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(width: 16),
          // Sort Dropdown
          Container(
            height: 40,
            padding: const EdgeInsets.symmetric(horizontal: 12),
            decoration: BoxDecoration(
              color: AppTheme.backgroundColor,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                color: AppTheme.borderColor,
              ),
            ),
            child: DropdownButtonHideUnderline(
              child: DropdownButton<String>(
                value: selectedSort,
                icon: const Icon(
                  Icons.arrow_drop_down,
                  color: AppTheme.textSecondary,
                ),
                style: Theme.of(context).textTheme.bodyMedium,
                items: sortOptions.entries.map((entry) {
                  return DropdownMenuItem<String>(
                    value: entry.key,
                    child: Row(
                      children: [
                        Icon(
                          Icons.sort,
                          size: 16,
                          color: AppTheme.textSecondary,
                        ),
                        const SizedBox(width: 8),
                        Text(entry.value),
                      ],
                    ),
                  );
                }).toList(),
                onChanged: onSortChanged,
              ),
            ),
          ),
        ],
      ),
    );
  }
} 