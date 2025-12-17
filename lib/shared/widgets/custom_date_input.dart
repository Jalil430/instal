import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';

import '../../core/theme/app_theme.dart';

class CustomDateInput extends StatefulWidget {
  final DateTime? value;
  final ValueChanged<DateTime?> onChanged;
  final String? label;
  final bool enabled;
  final DateTime firstDate;
  final DateTime lastDate;
  final Locale? locale;
  final String placeholder;
  final ValueChanged<bool>? onValidityChanged;

  CustomDateInput({
    super.key,
    required this.value,
    required this.onChanged,
    this.label,
    this.enabled = true,
    DateTime? firstDate,
    DateTime? lastDate,
    this.locale,
    this.placeholder = '',
    this.onValidityChanged,
  })  : firstDate = firstDate ?? DateTime(2020),
        lastDate = lastDate ?? DateTime(2030);

  @override
  State<CustomDateInput> createState() => _CustomDateInputState();
}

class _CustomDateInputState extends State<CustomDateInput> {
  late final TextEditingController _controller;
  late final FocusNode _focusNode;
  final DateFormat _format = DateFormat('dd.MM.yyyy');
  bool _isFormatting = false;
  bool _hasError = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: _formatValue(widget.value));
    _focusNode = FocusNode();
    _focusNode.addListener(_handleFocusChange);
    _controller.addListener(_handleTextChange);
  }

  @override
  void didUpdateWidget(covariant CustomDateInput oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.value != oldWidget.value) {
      final next = _formatValue(widget.value);
      if (next != _controller.text) {
        _controller.text = next;
        _selectAll();
      }
    }
  }

  @override
  void dispose() {
    _controller.removeListener(_handleTextChange);
    _focusNode.removeListener(_handleFocusChange);
    _controller.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  String _formatValue(DateTime? date) {
    if (date == null) return '';
    return _format.format(date);
  }

  void _handleTextChange() {
    if (_isFormatting) return;

    final rawText = _controller.text;
    final selectionIndex = _controller.selection.baseOffset;
    final digitsBeforeCursor = _countDigitsBeforeCursor(rawText, selectionIndex);

    final formatted = _applyMask(_controller.text);
    if (formatted != _controller.text) {
      _isFormatting = true;
      _controller.value = TextEditingValue(
        text: formatted,
        selection: _cursorForDigitIndex(formatted, digitsBeforeCursor),
      );
      _isFormatting = false;
    }

    final validation = _validateInput(formatted);
    final parsed = validation == null ? _parseInput(formatted) : null;

    if (_hasError != (validation != null) || _errorMessage != validation) {
      widget.onValidityChanged?.call(validation == null);
      setState(() {
        _hasError = validation != null;
        _errorMessage = validation;
      });
    } else {
      widget.onValidityChanged?.call(validation == null);
    }

    widget.onChanged(parsed);
  }

  void _handleFocusChange() {
    if (_focusNode.hasFocus) {
      _selectAll();
    }
  }

  void _selectAll() {
    _controller.selection = TextSelection(baseOffset: 0, extentOffset: _controller.text.length);
  }

  int _countDigitsBeforeCursor(String text, int cursor) {
    if (cursor <= 0) return 0;
    final safeCursor = cursor.clamp(0, text.length);
    return RegExp(r'\d').allMatches(text.substring(0, safeCursor)).length;
  }

  TextSelection _cursorForDigitIndex(String text, int digitIndex) {
    if (digitIndex <= 0) {
      return const TextSelection.collapsed(offset: 0);
    }
    int digitsSeen = 0;
    for (int i = 0; i < text.length; i++) {
      if (RegExp(r'\d').hasMatch(text[i])) {
        digitsSeen++;
        if (digitsSeen == digitIndex) {
          return TextSelection.collapsed(offset: i + 1);
        }
      }
    }
    return TextSelection.collapsed(offset: text.length);
  }

  String _applyMask(String input) {
    final digits = input.replaceAll(RegExp(r'\D'), '');
    final clipped = digits.substring(0, math.min(digits.length, 8));
    final buffer = StringBuffer();
    for (int i = 0; i < clipped.length; i++) {
      buffer.write(clipped[i]);
      if (i == 1 || i == 3) buffer.write('.');
    }
    return buffer.toString();
  }

  String? _validateInput(String input) {
    final digits = input.replaceAll(RegExp(r'\D'), '');
    if (digits.isEmpty) return null; // blank allowed
    if (digits.length < 8) return null; // allow partial typing

    final date = _buildDate(digits);
    if (date == null) return _localizedError();
    return null; // Valid date, range not enforced here
  }

  DateTime? _parseInput(String input) {
    final digits = input.replaceAll(RegExp(r'\D'), '');
    if (digits.isEmpty || digits.length < 8) return null;
    final date = _buildDate(digits);
    if (date == null) return null;
    return date;
  }

  DateTime? _buildDate(String digits) {
    if (digits.length < 8) return null;
    final day = int.tryParse(digits.substring(0, 2));
    final month = int.tryParse(digits.substring(2, 4));
    final year = int.tryParse(digits.substring(4, 8));
    if (day == null || month == null || year == null) return null;
    DateTime candidate;
    try {
      candidate = DateTime(year, month, day);
    } catch (_) {
      return null;
    }
    if (candidate.year != year || candidate.month != month || candidate.day != day) {
      return null;
    }
    return candidate;
  }

  Future<void> _openDatePicker() async {
    if (!widget.enabled) return;

    final initialDate = widget.value ?? DateTime.now();
    final date = await showDatePicker(
      context: context,
      initialDate: initialDate.isBefore(widget.firstDate) ? widget.firstDate : initialDate,
      firstDate: widget.firstDate,
      lastDate: widget.lastDate,
      locale: widget.locale,
    );

    if (date != null) {
      _controller.text = _formatValue(date);
      _handleTextChange();
      widget.onChanged(date);
      widget.onValidityChanged?.call(true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final border = OutlineInputBorder(
      borderRadius: BorderRadius.circular(8),
      borderSide: BorderSide(color: AppTheme.borderColor),
    );
    final hintText = widget.placeholder.isNotEmpty ? widget.placeholder : _localizedHint();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (widget.label != null) ...[
          Text(
            widget.label!,
            style: TextStyle(
              color: AppTheme.textSecondary,
              fontSize: 14,
              fontWeight: FontWeight.w400,
            ),
          ),
          const SizedBox(height: 8),
        ],
        TextFormField(
          controller: _controller,
          focusNode: _focusNode,
          enabled: widget.enabled,
          keyboardType: TextInputType.datetime,
          inputFormatters: [FilteringTextInputFormatter.digitsOnly],
          style: const TextStyle(fontSize: 16),
          decoration: InputDecoration(
            hintText: hintText,
            filled: true,
            fillColor: widget.enabled ? Colors.white : AppTheme.subtleBackgroundColor,
            suffixIconConstraints: const BoxConstraints(minHeight: 20, minWidth: 20),
            suffixIcon: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (_hasError)
                  IconButton(
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(minHeight: 32, minWidth: 32),
                    icon: Icon(Icons.warning_amber_rounded, color: AppTheme.errorColor, size: 18),
                    tooltip: _errorMessage ?? 'Invalid date',
                    onPressed: () {
                      final message = _errorMessage ?? 'Invalid date';
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text(message)),
                      );
                    },
                  ),
                IconButton(
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(minHeight: 32, minWidth: 32),
                  icon: Icon(Icons.calendar_today, color: AppTheme.textSecondary),
                  onPressed: _openDatePicker,
                ),
              ],
            ),
            contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
            border: border,
            enabledBorder: border,
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: BorderSide(color: AppTheme.primaryColor, width: 2),
            ),
            errorBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: BorderSide(color: AppTheme.errorColor),
            ),
          ),
          onChanged: (_) {
            // handled via controller listener
          },
          onFieldSubmitted: (_) {
            _handleTextChange();
          },
          onTap: _selectAll,
        ),
      ],
    );
  }

  String _localizedHint() {
    if (widget.locale?.languageCode == 'ru') return 'дд.мм.гггг';
    return 'dd.MM.yyyy';
  }

  String _localizedError() {
    return 'Недопустимый формат даты.';
  }
}
