import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter/foundation.dart';
import 'package:intl/intl.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/localization/app_localizations.dart';
import '../../../shared/widgets/custom_contextual_dialog.dart';
import '../domain/entities/installment.dart';
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
    required Function(Installment) onPaymentDeleted,
  }) async {
    final result = await CustomContextualDialog.show<Installment>(
      context: context,
      position: position,
      child: _PaymentDeletionContent(payment: payment),
      width: 300.0,
      estimatedHeight: 140.0,
    );
    
    if (result != null) {
      onPaymentDeleted(result);
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
  // Add focus node
  final FocusNode _focusNode = FocusNode();

  @override
  void initState() {
    super.initState();
    _repository = InstallmentRepositoryImpl(
      InstallmentRemoteDataSourceImpl(),
    );
    // Request focus when dialog is shown
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _focusNode.requestFocus();
    });
  }

  @override
  void dispose() {
    _focusNode.dispose(); // Clean up the focus node
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

    // Main content widget
    Widget content = Column(
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
        
        // Simple confirmation message (replaces date picker)
        Container(
          padding: EdgeInsets.symmetric(
            horizontal: isDesktop ? 12 : 16, 
            vertical: isDesktop ? 8 : 12
          ),
          decoration: BoxDecoration(
            color: AppTheme.errorColor.withOpacity(0.05),
            border: Border.all(color: AppTheme.errorColor.withOpacity(0.2)),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Text(
            l10n?.cancelPaymentQuestion ?? 'Отменить оплату этого платежа?',
            style: TextStyle(
              fontSize: isDesktop ? 13 : 16,
              fontWeight: FontWeight.w400,
              color: AppTheme.errorColor,
            ),
          ),
        ),
        
        SizedBox(height: isDesktop ? 12 : 20),
        
        // Buttons - matches registration dialog layout
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
                        color: AppTheme.errorColor,
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
                      )
                    : SizedBox(
                        height: 45,
                        child: ElevatedButton(
                          onPressed: _isLoading ? null : _handleDeletion,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppTheme.errorColor,
                            foregroundColor: Colors.white,
                            elevation: 0,
                            shadowColor: Colors.transparent,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                          child: Text(
                            l10n?.cancelPayment ?? 'Отменить',
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

    // Apply focus node to the content widget
    if (isDesktop) {
      return Focus(
        focusNode: _focusNode,
        autofocus: true,
        canRequestFocus: true,
        skipTraversal: false,
        includeSemantics: true,
        onKeyEvent: (FocusNode node, KeyEvent event) {
          if (event is KeyDownEvent && 
              event.logicalKey == LogicalKeyboardKey.enter && 
              !_isLoading) {
            _handleDeletion();
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
      
      final updatedInstallment = await _repository.updatePayment(updatedPayment);
      
      if (mounted) {
        Navigator.of(context).pop(updatedInstallment); // Return the updated installment
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