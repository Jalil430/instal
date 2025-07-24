import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../core/theme/app_theme.dart';

class KeyboardNavigableDropdown<T> extends StatefulWidget {
  final T? value;
  final List<T> items;
  final String Function(T) getDisplayText;
  final String Function(T) getSearchText;
  final ValueChanged<T?> onChanged;
  final VoidCallback? onNext;
  final String label;
  final String hint;
  final String? noItemsMessage;
  final VoidCallback? onCreateNew;
  final bool autoFocus;

  const KeyboardNavigableDropdown({
    super.key,
    this.value,
    required this.items,
    required this.getDisplayText,
    required this.getSearchText,
    required this.onChanged,
    this.onNext,
    required this.label,
    required this.hint,
    this.noItemsMessage,
    this.onCreateNew,
    this.autoFocus = false,
  });

  @override
  State<KeyboardNavigableDropdown<T>> createState() => KeyboardNavigableDropdownState<T>();
}

class KeyboardNavigableDropdownState<T> extends State<KeyboardNavigableDropdown<T>> {
  final _controller = TextEditingController();
  final _focusNode = FocusNode();
  final _scrollController = ScrollController();
  
  bool _isOpen = false;
  int _selectedIndex = 0;
  String _searchQuery = '';
  List<T> _filteredItems = [];
  OverlayEntry? _overlayEntry;
  final LayerLink _layerLink = LayerLink();

  @override
  void initState() {
    super.initState();
    _filteredItems = widget.items;
    
    if (widget.value != null) {
      _controller.text = widget.getDisplayText(widget.value!);
    }
    
    if (widget.autoFocus) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _focusNode.requestFocus();
        _openDropdown();
      });
    }
  }

  @override
  void didUpdateWidget(KeyboardNavigableDropdown<T> oldWidget) {
    super.didUpdateWidget(oldWidget);
    
    // Update the text field when value changes
    if (widget.value != oldWidget.value) {
      if (widget.value != null) {
        _controller.text = widget.getDisplayText(widget.value!);
      } else {
        _controller.clear();
      }
    }
    
    // Handle autoFocus changes
    if (widget.autoFocus && !oldWidget.autoFocus) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _focusNode.requestFocus();
        _openDropdown();
      });
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    _focusNode.dispose();
    _scrollController.dispose();
    _overlayEntry?.remove();
    super.dispose();
  }

  void _openDropdown() {
    if (_isOpen) return;
    
    _overlayEntry = _createOverlayEntry();
    Overlay.of(context).insert(_overlayEntry!);
    setState(() {
      _isOpen = true;
      _selectedIndex = 0;
    });
  }

  void _closeDropdown() {
    if (!_isOpen) return;
    
    _overlayEntry?.remove();
    _overlayEntry = null;
    setState(() {
      _isOpen = false;
    });
  }

  void _scrollToSelectedItem() {
    if (!_scrollController.hasClients || _filteredItems.isEmpty) return;
    
    const itemHeight = 48.0; // Height of each dropdown item
    final targetOffset = _selectedIndex * itemHeight;
    final maxScrollExtent = _scrollController.position.maxScrollExtent;
    final viewportHeight = _scrollController.position.viewportDimension;
    
    // Calculate if we need to scroll
    final currentOffset = _scrollController.offset;
    final itemTop = targetOffset;
    final itemBottom = targetOffset + itemHeight;
    final viewportTop = currentOffset;
    final viewportBottom = currentOffset + viewportHeight;
    
    double? newOffset;
    
    if (itemTop < viewportTop) {
      // Item is above visible area, scroll up
      newOffset = itemTop;
    } else if (itemBottom > viewportBottom) {
      // Item is below visible area, scroll down
      newOffset = itemBottom - viewportHeight;
    }
    
    if (newOffset != null) {
      newOffset = newOffset.clamp(0.0, maxScrollExtent);
      _scrollController.animateTo(
        newOffset,
        duration: const Duration(milliseconds: 200),
        curve: Curves.easeInOut,
      );
    }
  }

  void _filterItems(String query) {
    setState(() {
      _searchQuery = query;
      if (query.isEmpty) {
        _filteredItems = widget.items;
      } else {
        _filteredItems = widget.items.where((item) {
          return widget.getSearchText(item).toLowerCase().contains(query.toLowerCase());
        }).toList();
      }
      _selectedIndex = 0;
    });
    
    if (!_isOpen) {
      _openDropdown();
    } else {
      _overlayEntry?.markNeedsBuild();
    }
  }

  void _selectItem(T? item) {
    if (item != null) {
      _controller.text = widget.getDisplayText(item);
    } else {
      _controller.clear();
    }
    _closeDropdown();
    widget.onChanged(item);
    
    // Move to next field after selection
    WidgetsBinding.instance.addPostFrameCallback((_) {
      widget.onNext?.call();
    });
  }

  bool _isHandlingSubmit = false;

  void _handleSubmit() {
    if (_isHandlingSubmit) return; // Prevent double execution
    _isHandlingSubmit = true;
    
    if (_filteredItems.isEmpty) {
      if (widget.onCreateNew != null && _searchQuery.isNotEmpty) {
        // Create new item
        _closeDropdown();
        widget.onCreateNew!();
      } else {
        // Skip this field
        _selectItem(null);
      }
    } else {
      // Select the highlighted item
      _selectItem(_filteredItems[_selectedIndex]);
    }
    
    // Reset the flag after a short delay
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _isHandlingSubmit = false;
    });
  }

  String get searchQuery => _searchQuery;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          widget.label,
          style: TextStyle(
            color: AppTheme.textSecondary,
            fontSize: 14,
            fontWeight: FontWeight.w400,
          ),
        ),
        const SizedBox(height: 8),
        CompositedTransformTarget(
          link: _layerLink,
          child: RawKeyboardListener(
            focusNode: FocusNode(),
            onKey: (RawKeyEvent event) {
              if (event is RawKeyDownEvent) {
                if (event.logicalKey == LogicalKeyboardKey.arrowDown) {
                  setState(() {
                    _selectedIndex = (_selectedIndex + 1) % _filteredItems.length;
                  });
                  _scrollToSelectedItem();
                  _overlayEntry?.markNeedsBuild();
                } else if (event.logicalKey == LogicalKeyboardKey.arrowUp) {
                  setState(() {
                    _selectedIndex = (_selectedIndex - 1) % _filteredItems.length;
                    if (_selectedIndex < 0) _selectedIndex = _filteredItems.length - 1;
                  });
                  _scrollToSelectedItem();
                  _overlayEntry?.markNeedsBuild();
                } else if (event.logicalKey == LogicalKeyboardKey.enter) {
                  _handleSubmit();
                } else if (event.logicalKey == LogicalKeyboardKey.escape) {
                  _closeDropdown();
                }
              }
            },
            child: TextFormField(
              controller: _controller,
              focusNode: _focusNode,
              textInputAction: TextInputAction.next,
              onChanged: _filterItems,
              onFieldSubmitted: (_) => _handleSubmit(),
              onTap: () {
                if (!_isOpen) _openDropdown();
              },
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w400,
              ),
              decoration: InputDecoration(
                hintText: widget.hint,
                hintStyle: TextStyle(
                  color: AppTheme.textHint,
                  fontSize: 14,
                ),
                filled: true,
                fillColor: Colors.white,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: AppTheme.subtleBorderColor),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: AppTheme.subtleBorderColor),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: AppTheme.primaryColor, width: 2),
                ),
                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                suffixIcon: Icon(
                  _isOpen ? Icons.keyboard_arrow_up : Icons.keyboard_arrow_down,
                  color: AppTheme.textSecondary,
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  OverlayEntry _createOverlayEntry() {
    final renderBox = context.findRenderObject() as RenderBox;
    final size = renderBox.size;

    return OverlayEntry(
      builder: (context) => Positioned(
        width: size.width,
        child: CompositedTransformFollower(
          link: _layerLink,
          showWhenUnlinked: false,
          offset: Offset(0, size.height / 1.45),
          child: Material(
            elevation: 8,
            borderRadius: BorderRadius.circular(12),
            color: AppTheme.surfaceColor,
            shadowColor: Colors.black.withOpacity(0.1),
            child: Container(
              constraints: const BoxConstraints(maxHeight: 200),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppTheme.subtleBorderColor),
              ),
              child: _filteredItems.isEmpty
                  ? _buildNoItemsWidget()
                  : ClipRRect(
                      borderRadius: BorderRadius.circular(12),
                      child: ListView.builder(
                        controller: _scrollController,
                        padding: EdgeInsets.zero,
                        shrinkWrap: true,
                        itemCount: _filteredItems.length,
                        itemBuilder: (context, index) {
                          final item = _filteredItems[index];
                          final isSelected = index == _selectedIndex;
                          
                          return InkWell(
                            onTap: () => _selectItem(item),
                            child: Container(
                              height: 48, // Fixed height for consistent scrolling
                              width: double.infinity,
                              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                              decoration: BoxDecoration(
                                color: isSelected
                                    ? AppTheme.subtleBackgroundColor
                                    : Colors.transparent,
                              ),
                              child: Align(
                                alignment: Alignment.centerLeft,
                                child: Text(
                                  widget.getDisplayText(item),
                                  style: TextStyle(
                                    color: isSelected 
                                        ? AppTheme.brightPrimaryColor
                                        : AppTheme.textPrimary,
                                    fontSize: 14,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ),
                            ),
                          );
                        },
                      ),
                    ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildNoItemsWidget() {
    return Container(
      padding: const EdgeInsets.all(16),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            widget.noItemsMessage ?? 'No items found',
            style: TextStyle(
              color: AppTheme.textSecondary,
              fontSize: 14,
            ),
          ),
          if (widget.onCreateNew != null && _searchQuery.isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(
              'Press Enter to create "${_searchQuery}"',
              style: TextStyle(
                color: AppTheme.primaryColor,
                fontSize: 12,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ],
      ),
    );
  }
}