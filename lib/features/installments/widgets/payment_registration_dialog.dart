import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter/foundation.dart';
import 'package:intl/intl.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/localization/app_localizations.dart';
import '../../../shared/widgets/custom_contextual_dialog.dart';
import '../../../shared/widgets/custom_date_input.dart';
import '../domain/entities/installment.dart';
import '../domain/entities/installment_payment.dart';
import '../domain/repositories/installment_repository.dart';
import '../data/repositories/installment_repository_impl.dart';
import '../data/datasources/installment_remote_datasource.dart';
import '../../../shared/widgets/custom_button.dart';

class PaymentRegistrationDialog {
  static Future<void> show({
    required BuildContext context,
    required Offset position,
    required InstallmentPayment payment,
    required Function(Installment) onPaymentRegistered,
    // If provided, dialog will close immediately on confirm and caller will handle background submission
    void Function(InstallmentPayment updatedPayment)? onSubmitInBackground,
  }) async {
    final result = await CustomContextualDialog.show<Installment>(
      context: context,
      position: position,
      child: _PaymentRegistrationContent(payment: payment, onSubmitInBackground: onSubmitInBackground),
    );
    
    if (result != null) {
      onPaymentRegistered(result);
    }
  }
}

class _PaymentRegistrationContent extends ContextualDialogContent {
  final InstallmentPayment payment;
  final void Function(InstallmentPayment updatedPayment)? onSubmitInBackground;

  const _PaymentRegistrationContent({required this.payment, this.onSubmitInBackground});

  @override
  void onKeyDown(RawKeyDownEvent event) {
    if (event.logicalKey == LogicalKeyboardKey.enter) {
      final state = _registrationKey.currentState;
      if (state != null && !state._isLoading) {
        state._handlePayment();
      }
    }
  }

  static final GlobalKey<_PaymentRegistrationStateState> _registrationKey = 
      GlobalKey<_PaymentRegistrationStateState>();

  @override
  Widget buildContent(BuildContext context) {
    return _PaymentRegistrationState(
      key: _registrationKey,
      payment: payment,
      onSubmitInBackground: onSubmitInBackground,
    );
  }
}

class _PaymentRegistrationState extends StatefulWidget {
  final InstallmentPayment payment;
  final void Function(InstallmentPayment updatedPayment)? onSubmitInBackground;

  const _PaymentRegistrationState({super.key, required this.payment, this.onSubmitInBackground});

  @override
  State<_PaymentRegistrationState> createState() => _PaymentRegistrationStateState();
}

class _PaymentRegistrationStateState extends State<_PaymentRegistrationState> {
  late InstallmentRepository _repository;
  late DateTime _selectedDate;
  bool _isLoading = false;
  bool _isDateValid = true;
  // Add focus node
  final FocusNode _focusNode = FocusNode();
  final TextEditingController _amountController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _repository = InstallmentRepositoryImpl(
      InstallmentRemoteDataSourceImpl(),
    );
    final dueDate = widget.payment.dueDate;
    _selectedDate = DateTime(dueDate.year, dueDate.month, dueDate.day);
    // Pre-fill amount with expected amount
    _amountController.text = widget.payment.expectedAmount.toStringAsFixed(0);
    // Request focus when dialog is shown
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _focusNode.requestFocus();
    });
  }

  @override
  void dispose() {
    _focusNode.dispose(); // Clean up the focus node
    _amountController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final currencyFormat = NumberFormat.currency(
      locale: l10n?.locale.languageCode == 'ru' ? 'ru_RU' : 'en_US',
      symbol: l10n?.locale.languageCode == 'ru' ? '₽' : '\$',
      decimalDigits: 0,
    );
    final isDesktop = MediaQuery.of(context).size.width >= 650;
    final firstDate = DateTime(2020);
    final now = DateTime.now();
    final defaultLastDate = now.add(const Duration(days: 365));
    final safeSelectedDate = _selectedDate.isBefore(firstDate) ? firstDate : _selectedDate;
    final lastDate = safeSelectedDate.isAfter(defaultLastDate) ? safeSelectedDate : defaultLastDate;
    
    // For desktop view, add a keyboard listener specifically for Enter key
    Widget content = Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Header
        Row(
          children: [
            Expanded(
              child: Text(
                widget.payment.paymentNumber == 0 
                    ? (l10n?.downPaymentFull ?? 'Первоначальный взнос')
                    : '${l10n?.monthLabel ?? 'Месяц'} ${widget.payment.paymentNumber}',
                style: TextStyle(
                  fontSize: isDesktop ? 14 : 16,
                  fontWeight: FontWeight.w500,
                  color: AppTheme.textPrimary,
                ),
              ),
            ),
            Text(
              currencyFormat.format(widget.payment.expectedAmount),
              style: TextStyle(
                fontSize: isDesktop ? 14 : 16,
                fontWeight: FontWeight.w500,
                color: AppTheme.textSecondary,
              ),
            ),
          ],
        ),
        
        SizedBox(height: isDesktop ? 12 : 16),
        
        // Date input with picker
        CustomDateInput(
          value: _selectedDate,
          onChanged: (date) {
            if (date != null) {
              setState(() => _selectedDate = date);
            }
          },
          onValidityChanged: (isValid) {
            if (_isDateValid != isValid) {
              setState(() => _isDateValid = isValid);
            }
          },
          firstDate: firstDate,
          lastDate: lastDate,
          locale: l10n?.locale,
        ),
        
        SizedBox(height: isDesktop ? 12 : 20),

        // Amount input
        TextField(
          controller: _amountController,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'^[0-9]+([.,][0-9]{0,2})?'))],
          decoration: InputDecoration(
            labelText: l10n?.enterAmount ?? 'Сумма оплаты',
            hintText: currencyFormat.format(widget.payment.expectedAmount),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
          ),
        ),
        SizedBox(height: isDesktop ? 12 : 16),
        SizedBox(height: isDesktop ? 8 : 12),
        
        // Buttons
        Row(
          children: [
            Expanded(
              child: TextButton(
                onPressed: _isLoading ? null : () => Navigator.of(context).pop(),
                style: TextButton.styleFrom(
                  padding: EdgeInsets.symmetric(vertical: isDesktop ? 8 : 12),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: Text(
                  l10n?.cancel ?? 'Отмена',
                  style: TextStyle(
                    fontSize: isDesktop ? 14 : 16,
                    fontWeight: FontWeight.w500,
                    color: AppTheme.textSecondary,
                  ),
                ),
              ),
            ),
            SizedBox(width: isDesktop ? 8 : 12),
            Expanded(
              flex: 2,
              child: _isLoading
                  ? Container(
                      height: isDesktop ? 30 : 45,
                      decoration: BoxDecoration(
                        color: AppTheme.primaryColor,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          SizedBox(
                            width: isDesktop ? 16 : 20,
                            height: isDesktop ? 16 : 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                            ),
                          ),
                          SizedBox(width: isDesktop ? 8 : 10),
                          Text(
                            'Обработка...',
                            style: TextStyle(
                              fontSize: isDesktop ? 14 : 16,
                              fontWeight: FontWeight.w500,
                              color: Colors.white,
                            ),
                          ),
                        ],
                      ),
                    )
                  : isDesktop 
                    ? CustomButton(
                        onPressed: (_isLoading || !_isDateValid) ? null : _handlePayment,
                        text: l10n?.confirm ?? 'Подтвердить',
                        icon: Icons.keyboard_return_rounded,
                        iconRight: true,
                        showIcon: true,
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                        color: AppTheme.primaryColor,
                        padding: const EdgeInsets.symmetric(vertical: 8),
                        height: 30,
                      )
                    : SizedBox(
                        height: 45,
                        child: ElevatedButton(
                          onPressed: _isLoading || !_isDateValid ? null : _handlePayment,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppTheme.primaryColor,
                            foregroundColor: Colors.white,
                            elevation: 0,
                            shadowColor: Colors.transparent,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                          child: Text(
                            l10n?.confirm ?? 'Подтвердить',
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                      ),
            ),
          ],
        ),
      ],
    );

    if (isDesktop) {
      // Make entire dialog content focusable
      return Focus(
        autofocus: true,
        focusNode: _focusNode,
        canRequestFocus: true,
        skipTraversal: false,
        includeSemantics: true,
        onKeyEvent: (FocusNode node, KeyEvent event) {
          if (event is KeyDownEvent && 
              event.logicalKey == LogicalKeyboardKey.enter && 
              !_isLoading) {
            _handlePayment();
            return KeyEventResult.handled;
          }
          return KeyEventResult.ignored;
        },
        child: content,
      );
    } else {
      return content;
    }
  }

  Future<void> _handlePayment() async {
    if (_isLoading) return; // Prevent multiple calls
    
    // If background mode, do not block the dialog with loading spinner
    final backgroundMode = widget.onSubmitInBackground != null;
    if (!backgroundMode) {
      setState(() => _isLoading = true);
    }

    try {
      // Add a small delay to ensure UI updates before the API call
      await Future.delayed(const Duration(milliseconds: 50));
      
      // Parse amount (allow comma or dot) + validate (0 allowed)
      final raw = _amountController.text.trim().replaceAll(',', '.');
      final valid = RegExp(r'^[0-9]+(\.[0-9]{1,2})?$').hasMatch(raw);
      if (!valid) {
        if (mounted) {
          final loc = AppLocalizations.of(context);
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(loc?.invalidAmount ?? 'Некорректная сумма (до 2 знаков после запятой)')),
          );
        }
        setState(() => _isLoading = false);
        return;
      }
      double amount = double.tryParse(raw) ?? 0.0;
      if (amount < 0) {
        if (mounted) {
          final loc = AppLocalizations.of(context);
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(loc?.invalidAmount ?? 'Некорректная сумма')),
          );
        }
        setState(() => _isLoading = false);
        return;
      }
      final updatedPayment = widget.payment.copyWith(
        isPaid: true,
        paidDate: _selectedDate,
        paidAmount: amount,
      );
      
      // Use a shorter timeout for payment operations
      if (backgroundMode) {
        if (mounted) {
          Navigator.of(context).pop();
        }
        // Delegate submission to caller
        widget.onSubmitInBackground?.call(updatedPayment);
      } else {
        final updatedInstallment = await _repository.updatePayment(updatedPayment);
        if (mounted) {
          Navigator.of(context).pop(updatedInstallment); // Return the updated installment
        }
      }
    } catch (e) {
      if (mounted) {
        if (!backgroundMode) setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('${AppLocalizations.of(context)?.error ?? 'Ошибка'}: $e'),
            backgroundColor: AppTheme.errorColor,
          ),
        );
      }
    }
  }
} 
