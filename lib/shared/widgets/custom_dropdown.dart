import 'package:flutter/material.dart';
import '../../core/theme/app_theme.dart';
import '../widgets/custom_search_bar.dart';
import '../../core/localization/app_localizations.dart';

class CustomDropdown<T> extends StatefulWidget {
  final T? value;
  final Map<T?, String> items;
  final ValueChanged<T?> onChanged;
  final String? hint;
  final double? width;
  final double height;
  final IconData? icon;
  final bool showSearch;
  final TextStyle? textStyle;

  const CustomDropdown({
    super.key,
    this.value,
    required this.items,
    required this.onChanged,
    this.hint,
    this.width,
    this.height = 40,
    this.icon,
    this.showSearch = false,
    this.textStyle,
  });

  @override
  State<CustomDropdown<T>> createState() => _CustomDropdownState<T>();
}

class _CustomDropdownState<T> extends State<CustomDropdown<T>> {
  bool _isHovered = false;
  bool _isOpen = false;
  late OverlayEntry _overlayEntry;
  final LayerLink _layerLink = LayerLink();
  final GlobalKey _dropdownKey = GlobalKey();
  String _searchQuery = '';

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return CompositedTransformTarget(
      link: _layerLink,
      child: MouseRegion(
        onEnter: (_) => setState(() => _isHovered = true),
        onExit: (_) => setState(() => _isHovered = false),
        child: GestureDetector(
          key: _dropdownKey,
          onTap: _toggleDropdown,
          child: Container(
            width: widget.width ?? 200,
            height: widget.height,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            decoration: BoxDecoration(
              color: _isHovered 
                  ? AppTheme.subtleHoverColor
                  : AppTheme.subtleBackgroundColor,
              border: Border.all(
                color: _isHovered 
                    ? AppTheme.subtleAccentColor
                    : AppTheme.subtleBorderColor,
                width: 1,
              ),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              mainAxisSize: MainAxisSize.min,
              children: [
                Flexible(
                  child: Text(
                    widget.value != null ? widget.items[widget.value] ?? '' : widget.hint ?? '',
                    style: widget.textStyle ?? TextStyle(
                      color: widget.value != null ? AppTheme.textPrimary : AppTheme.textHint,
                      fontSize: 14,
                      fontWeight: FontWeight.w400,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                const SizedBox(width: 8),
                AnimatedRotation(
                  turns: _isOpen ? 0.5 : 0,
                  duration: const Duration(milliseconds: 200),
                  child: Icon(
                    widget.icon ?? Icons.keyboard_arrow_down_rounded,
                    color: AppTheme.textSecondary,
                    size: 20,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _toggleDropdown() {
    if (_isOpen) {
      _closeDropdown();
    } else {
      _openDropdown();
    }
  }

  void _openDropdown() {
    _overlayEntry = _createOverlayEntry();
    Overlay.of(context).insert(_overlayEntry);
    setState(() => _isOpen = true);
  }

  void _closeDropdown() {
    _overlayEntry.remove();
    setState(() {
      _isOpen = false;
      _searchQuery = '';
    });
  }

  Map<T?, String> get _filteredItems {
    if (!widget.showSearch || _searchQuery.isEmpty) {
      return widget.items;
    }
    return Map.fromEntries(
      widget.items.entries.where((entry) =>
        entry.value.toLowerCase().contains(_searchQuery.toLowerCase())
      ),
    );
  }

  OverlayEntry _createOverlayEntry() {
    final l10n = AppLocalizations.of(context);
    final renderBox = _dropdownKey.currentContext!.findRenderObject() as RenderBox;
    final size = renderBox.size;

    // Calculate content height
    const double itemHeight = 44.0; // Height of each dropdown item
    const double searchBarHeight = 56.0; // Height of search bar with padding
    const double maxVisibleItems = 5.0; // Maximum number of visible items
    const double maxDropdownHeight = itemHeight * maxVisibleItems;

    // Calculate total height based on number of items
    final int itemCount = _filteredItems.length + (widget.hint != null ? 1 : 0);
    final double contentHeight = itemHeight * itemCount;
    final double dropdownHeight = contentHeight.clamp(0.0, maxDropdownHeight);
    
    final double totalHeight = widget.showSearch 
        ? dropdownHeight + searchBarHeight 
        : dropdownHeight;

    return OverlayEntry(
      builder: (context) => Stack(
        children: [
          Positioned.fill(
            child: GestureDetector(
              onTap: _closeDropdown,
              behavior: HitTestBehavior.translucent,
              child: Container(
                color: Colors.transparent,
              ),
            ),
          ),
          Positioned(
            width: size.width,
            child: CompositedTransformFollower(
              link: _layerLink,
              showWhenUnlinked: false,
              offset: Offset(0, size.height + 4),
              child: Material(
                elevation: 8,
                borderRadius: BorderRadius.circular(12),
                color: AppTheme.surfaceColor,
                shadowColor: Colors.black.withOpacity(0.1),
                child: Container(
                  constraints: BoxConstraints(
                    maxHeight: totalHeight,
                  ),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: AppTheme.subtleBorderColor,
                      width: 1,
                    ),
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (widget.showSearch) ...[
                          Padding(
                            padding: const EdgeInsets.all(8),
                            child: CustomSearchBar(
                              value: _searchQuery,
                              onChanged: (value) {
                                setState(() => _searchQuery = value);
                                _overlayEntry.markNeedsBuild();
                              },
                              hintText: l10n?.search ?? 'Поиск...',
                              height: 40,
                              width: double.infinity,
                            ),
                          ),
                          if (_filteredItems.isEmpty)
                            Padding(
                              padding: const EdgeInsets.all(16),
                              child: Text(
                                l10n?.notFound ?? 'Ничего не найдено',
                                style: TextStyle(
                                  color: AppTheme.textSecondary,
                                  fontSize: 14,
                                ),
                              ),
                            ),
                        ],
                        Flexible(
                          child: ListView(
                            padding: EdgeInsets.zero,
                            shrinkWrap: true,
                            children: [
                              if (widget.hint != null)
                                _CustomDropdownItem<T?>(
                                  value: null,
                                  label: widget.hint!,
                                  isSelected: widget.value == null,
                                  onTap: () {
                                    widget.onChanged(null);
                                    _closeDropdown();
                                  },
                                ),
                              ..._filteredItems.entries.map((entry) {
                                final isSelected = entry.key == widget.value;
                                return _CustomDropdownItem<T?>(
                                  value: entry.key,
                                  label: entry.value,
                                  isSelected: isSelected,
                                  onTap: () {
                                    widget.onChanged(entry.key);
                                    _closeDropdown();
                                  },
                                );
                              }),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _CustomDropdownItem<T> extends StatefulWidget {
  final T value;
  final String label;
  final bool isSelected;
  final VoidCallback onTap;

  const _CustomDropdownItem({
    required this.value,
    required this.label,
    required this.isSelected,
    required this.onTap,
  });

  @override
  State<_CustomDropdownItem<T>> createState() => _CustomDropdownItemState<T>();
}

class _CustomDropdownItemState<T> extends State<_CustomDropdownItem<T>> {
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      child: GestureDetector(
        onTap: widget.onTap,
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
            color: widget.isSelected
                ? AppTheme.subtleBackgroundColor
                : _isHovered
                    ? AppTheme.subtleHoverColor
                    : Colors.transparent,
          ),
          child: Text(
            widget.label,
            style: TextStyle(
              color: widget.isSelected 
                  ? AppTheme.brightPrimaryColor
                  : AppTheme.textPrimary,
              fontSize: 14,
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
      ),
    );
  }
} 