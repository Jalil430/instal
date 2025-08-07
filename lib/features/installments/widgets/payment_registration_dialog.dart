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

class PaymentRegistrationDialog {
  static Future<void> show({
    required BuildContext context,
    required Offset position,
    required InstallmentPayment payment,
    required Function(Installment) onPaymentRegistered,
  }) async {
    final result = await CustomContextualDialog.show<Installment>(
      context: context,
      position: position,
      child: _PaymentRegistrationContent(payment: payment),
    );
    
    if (result != null) {
      onPaymentRegistered(result);
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
  // Add focus node
  final FocusNode _focusNode = FocusNode();

  @override
  void initState() {
    super.initState();
    _repository = InstallmentRepositoryImpl(
      InstallmentRemoteDataSourceImpl(),
    );
    _selectedDate = DateTime.now();
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
    final dateFormat = DateFormat('dd.MM.yyyy');
    final isDesktop = MediaQuery.of(context).size.width >= 650;
    
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
            padding: EdgeInsets.symmetric(
              horizontal: isDesktop ? 12 : 16, 
              vertical: isDesktop ? 8 : 12
            ),
            decoration: BoxDecoration(
              border: Border.all(color: AppTheme.borderColor),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              children: [
                Icon(
                  Icons.calendar_today_outlined,
                  size: isDesktop ? 14 : 18,
                  color: AppTheme.textSecondary,
                ),
                SizedBox(width: isDesktop ? 6 : 10),
                Text(
                  dateFormat.format(_selectedDate),
                  style: TextStyle(
                    fontSize: isDesktop ? 13 : 16,
                    fontWeight: FontWeight.w400,
                    color: AppTheme.textPrimary,
                  ),
                ),
                const Spacer(),
                Icon(
                  Icons.arrow_drop_down,
                  size: isDesktop ? 16 : 20,
                  color: AppTheme.textSecondary,
                ),
              ],
            ),
          ),
        ),
        
        SizedBox(height: isDesktop ? 12 : 20),
        
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
                      )
                    : SizedBox(
                        height: 45,
                        child: ElevatedButton(
                          onPressed: _isLoading ? null : _handlePayment,
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
    
    setState(() => _isLoading = true);

    try {
      // Add a small delay to ensure UI updates before the API call
      await Future.delayed(const Duration(milliseconds: 50));
      
      final updatedPayment = widget.payment.copyWith(
        isPaid: true,
        paidDate: _selectedDate,
      );
      
      // Use a shorter timeout for payment operations
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