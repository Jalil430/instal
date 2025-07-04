import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/localization/app_localizations.dart';
import '../../../shared/widgets/custom_contextual_dialog.dart';
import '../domain/entities/installment_payment.dart';
import '../domain/repositories/installment_repository.dart';
import '../data/repositories/installment_repository_impl.dart';
import '../data/datasources/installment_remote_datasource.dart';
import '../../../shared/widgets/custom_button.dart';

class PaymentDeletionDialog {
  static Future<void> show({
    required BuildContext context,
    required Offset position,
    required InstallmentPayment payment,
    required VoidCallback onPaymentDeleted,
  }) async {
    final result = await CustomContextualDialog.show<bool>(
      context: context,
      position: position,
      child: _PaymentDeletionContent(payment: payment),
      width: 300.0,
      estimatedHeight: 140.0,
    );
    
    if (result == true) {
      onPaymentDeleted();
    }
  }
}

class _PaymentDeletionContent extends ContextualDialogContent {
  final InstallmentPayment payment;

  const _PaymentDeletionContent({required this.payment});

  @override
  void onKeyDown(RawKeyDownEvent event) {
    if (event.logicalKey == LogicalKeyboardKey.enter) {
      final state = _deletionKey.currentState;
      if (state != null && !state._isLoading) {
        state._handleDeletion();
      }
    }
  }

  static final GlobalKey<_PaymentDeletionStateState> _deletionKey = 
      GlobalKey<_PaymentDeletionStateState>();

  @override
  Widget buildContent(BuildContext context) {
    return _PaymentDeletionState(
      key: _deletionKey,
      payment: payment,
    );
  }
}

class _PaymentDeletionState extends StatefulWidget {
  final InstallmentPayment payment;

  const _PaymentDeletionState({super.key, required this.payment});

  @override
  State<_PaymentDeletionState> createState() => _PaymentDeletionStateState();
}

class _PaymentDeletionStateState extends State<_PaymentDeletionState> {
  late InstallmentRepository _repository;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _repository = InstallmentRepositoryImpl(
      InstallmentRemoteDataSourceImpl(),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final currencyFormat = NumberFormat.currency(
      locale: l10n?.locale.languageCode == 'ru' ? 'ru_RU' : 'en_US',
      symbol: l10n?.locale.languageCode == 'ru' ? '₽' : '\$',
      decimalDigits: 0,
    );

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Header - matches registration dialog
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
        
        // Simple confirmation message (replaces date picker)
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            color: AppTheme.errorColor.withOpacity(0.05),
            border: Border.all(color: AppTheme.errorColor.withOpacity(0.2)),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Text(
            l10n?.cancelPaymentQuestion ?? 'Отменить оплату этого платежа?',
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w400,
              color: AppTheme.errorColor,
            ),
          ),
        ),
        
        const SizedBox(height: 12),
        
        // Buttons - matches registration dialog layout
        Row(
          children: [
            Expanded(
              child: TextButton(
                onPressed: _isLoading ? null : () => Navigator.of(context).pop(),
                style: TextButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
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
                  ? Container(
                      height: 30,
                      decoration: BoxDecoration(
                        color: AppTheme.errorColor,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            'Обработка...',
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w500,
                              color: Colors.white,
                            ),
                          ),
                        ],
                      ),
                    )
                  : CustomButton(
                      onPressed: _isLoading ? null : _handleDeletion,
                      text: l10n?.cancelPayment ?? 'Отменить',
                      icon: Icons.keyboard_return_rounded,
                      iconRight: true,
                      showIcon: true,
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                      color: AppTheme.errorColor,
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      height: 30,
                    ),
            ),
          ],
        ),
      ],
    );
  }

  Future<void> _handleDeletion() async {
    if (_isLoading) return; // Prevent multiple calls
    
    setState(() => _isLoading = true);

    try {
      // Add a small delay to ensure UI updates before the API call
      await Future.delayed(const Duration(milliseconds: 50));
      
      final updatedPayment = widget.payment.copyWith(
        isPaid: false,
        paidDate: null,
      );
      
      await _repository.updatePayment(updatedPayment);
      
      if (mounted) {
        Navigator.of(context).pop(true); // Return true to indicate success
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
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