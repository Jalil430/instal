import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/localization/app_localizations.dart';
import '../../../shared/widgets/custom_contextual_dialog.dart';
import '../domain/entities/installment_payment.dart';
import '../domain/repositories/installment_repository.dart';
import '../data/repositories/installment_repository_impl.dart';
import '../data/datasources/installment_local_datasource.dart';
import '../../../shared/database/database_helper.dart';
import '../../../shared/widgets/custom_button.dart';

class PaymentRegistrationDialog {
  static Future<void> show({
    required BuildContext context,
    required Offset position,
    required InstallmentPayment payment,
    required VoidCallback onPaymentRegistered,
  }) async {
    final result = await CustomContextualDialog.show<bool>(
      context: context,
      position: position,
      child: _PaymentRegistrationContent(payment: payment),
    );
    
    if (result == true) {
      onPaymentRegistered();
    }
  }
}

class _PaymentRegistrationContent extends ContextualDialogContent {
  final InstallmentPayment payment;

  const _PaymentRegistrationContent({required this.payment});

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
    );
  }
}

class _PaymentRegistrationState extends StatefulWidget {
  final InstallmentPayment payment;

  const _PaymentRegistrationState({super.key, required this.payment});

  @override
  State<_PaymentRegistrationState> createState() => _PaymentRegistrationStateState();
}

class _PaymentRegistrationStateState extends State<_PaymentRegistrationState> {
  late InstallmentRepository _repository;
  late DateTime _selectedDate;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _repository = InstallmentRepositoryImpl(
      InstallmentLocalDataSourceImpl(DatabaseHelper.instance),
    );
    _selectedDate = DateTime.now();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final currencyFormat = NumberFormat.currency(
      locale: l10n?.locale.languageCode == 'ru' ? 'ru_RU' : 'en_US',
      symbol: l10n?.locale.languageCode == 'ru' ? '₽' : '\$',
      decimalDigits: 0,
    );
    final dateFormat = DateFormat('dd.MM.yyyy');

    return Column(
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
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                  color: AppTheme.textPrimary,
                ),
              ),
            ),
            Text(
              currencyFormat.format(widget.payment.expectedAmount),
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w500,
                color: AppTheme.textSecondary,
              ),
            ),
          ],
        ),
        
        const SizedBox(height: 12),
        
        // Date picker
        InkWell(
          onTap: () async {
            final date = await showDatePicker(
              context: context,
              initialDate: _selectedDate,
              firstDate: DateTime(2020),
              lastDate: DateTime.now().add(const Duration(days: 365)),
              locale: l10n?.locale ?? const Locale('ru'),
            );
            if (date != null) {
              setState(() => _selectedDate = date);
            }
          },
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              border: Border.all(color: AppTheme.borderColor),
              borderRadius: BorderRadius.circular(6),
            ),
            child: Row(
              children: [
                Icon(
                  Icons.calendar_today_outlined,
                  size: 14,
                  color: AppTheme.textSecondary,
                ),
                const SizedBox(width: 6),
                Text(
                  dateFormat.format(_selectedDate),
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w400,
                    color: AppTheme.textPrimary,
                  ),
                ),
                const Spacer(),
                Icon(
                  Icons.arrow_drop_down,
                  size: 16,
                  color: AppTheme.textSecondary,
                ),
              ],
            ),
          ),
        ),
        
        const SizedBox(height: 12),
        
        // Buttons
        Row(
          children: [
            Expanded(
              child: TextButton(
                onPressed: _isLoading ? null : () => Navigator.of(context).pop(),
                style: TextButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(6),
                  ),
                ),
                child: Text(
                  l10n?.cancel ?? 'Отмена',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                    color: AppTheme.textSecondary,
                  ),
                ),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              flex: 2,
              child: _isLoading
                  ? SizedBox(
                      width: 14,
                      height: 14,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                      ),
                    )
                  : CustomButton(
                      onPressed: _isLoading ? null : _handlePayment,
                      text: l10n?.confirm ?? 'Подтвердить',
                      icon: Icons.keyboard_return_rounded,
                      iconRight: true,
                      showIcon: true,
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                      color: AppTheme.primaryColor,
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      height: 30,
                    ),
            ),
          ],
        ),
      ],
    );
  }

  Future<void> _handlePayment() async {
    setState(() => _isLoading = true);

    try {
      final updatedPayment = widget.payment.copyWith(
        isPaid: true,
        paidDate: _selectedDate,
      );
      
      await _repository.updatePayment(updatedPayment);
      Navigator.of(context).pop(true); // Return true to indicate success
    } catch (e) {
      setState(() => _isLoading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('${AppLocalizations.of(context)?.error ?? 'Ошибка'}: $e')),
        );
      }
    }
  }
} 