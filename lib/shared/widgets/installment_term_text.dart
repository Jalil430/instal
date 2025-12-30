import 'package:flutter/material.dart';

import '../../core/services/term_mode_preferences.dart';
import '../../features/installments/domain/entities/installment.dart';

class InstallmentTermText extends StatefulWidget {
  final Installment installment;
  final String? prefix;
  final String? suffix;
  final String? suffixWhenIncludesDownPayment;
  final TextStyle? style;
  final TextAlign? textAlign;

  const InstallmentTermText({
    super.key,
    required this.installment,
    this.prefix,
    this.suffix,
    this.suffixWhenIncludesDownPayment,
    this.style,
    this.textAlign,
  });

  @override
  State<InstallmentTermText> createState() => _InstallmentTermTextState();
}

class _InstallmentTermTextState extends State<InstallmentTermText> {
  bool _termIncludesDownPayment = false;

  @override
  void initState() {
    super.initState();
    _loadPreference();
  }

  @override
  void didUpdateWidget(covariant InstallmentTermText oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.installment.id != widget.installment.id) {
      _loadPreference();
    }
  }

  Future<void> _loadPreference() async {
    final value = await TermModePreferences.getTermIncludesDownPayment();
    if (mounted) {
      setState(() {
        _termIncludesDownPayment = value;
      });
    }
  }

  int _displayTerm() {
    final term = widget.installment.termMonths;
    if (!_termIncludesDownPayment && widget.installment.downPayment > 0) {
      return term > 0 ? term - 1 : 0;
    }
    return term;
  }

  @override
  Widget build(BuildContext context) {
    final term = _displayTerm();
    final suffix =
        _termIncludesDownPayment && widget.suffixWhenIncludesDownPayment != null
            ? widget.suffixWhenIncludesDownPayment!
            : (widget.suffix ?? '');
    final text = '${widget.prefix ?? ''}$term$suffix';
    return Text(
      text,
      style: widget.style,
      textAlign: widget.textAlign,
    );
  }
}
