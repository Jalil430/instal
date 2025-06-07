import 'package:flutter/material.dart';
import '../../core/theme/app_theme.dart';

class CustomDropdown<T> extends StatefulWidget {
  final T value;
  final Map<T, String> items;
  final ValueChanged<T> onChanged;
  final String? hint;
  final double? width;
  final double height;
  final IconData? icon;

  const CustomDropdown({
    super.key,
    required this.value,
    required this.items,
    required this.onChanged,
    this.hint,
    this.width,
    this.height = 44,
    this.icon,
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

  @override
  Widget build(BuildContext context) {
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
                    widget.items[widget.value] ?? widget.hint ?? '',
                    style: TextStyle(
                      color: AppTheme.textPrimary,
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
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
    setState(() => _isOpen = false);
  }

  OverlayEntry _createOverlayEntry() {
    final renderBox = _dropdownKey.currentContext!.findRenderObject() as RenderBox;
    final size = renderBox.size;

    return OverlayEntry(
      builder: (context) => Positioned(
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
                  children: widget.items.entries.map((entry) {
                    final isSelected = entry.key == widget.value;
                    return _CustomDropdownItem<T>(
                      value: entry.key,
                      label: entry.value,
                      isSelected: isSelected,
                      onTap: () {
                        widget.onChanged(entry.key);
                        _closeDropdown();
                      },
                    );
                  }).toList(),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  @override
  void dispose() {
    if (_isOpen) {
      _overlayEntry.remove();
    }
    super.dispose();
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
              fontWeight: widget.isSelected ? FontWeight.w600 : FontWeight.w500,
            ),
          ),
        ),
      ),
    );
  }
} 