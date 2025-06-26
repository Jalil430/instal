import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../../core/themes/app_theme.dart';
import '../../../../core/utils/date_utils.dart' as app_date_utils;
import '../../domain/entities/installment_payment.dart';
import '../providers/installment_provider.dart';

class RegisterPaymentDialog extends StatefulWidget {
  final InstallmentPayment payment;
  
  const RegisterPaymentDialog({
    super.key,
    required this.payment,
  });

  @override
  State<RegisterPaymentDialog> createState() => _RegisterPaymentDialogState();
}

class _RegisterPaymentDialogState extends State<RegisterPaymentDialog> {
  final _formKey = GlobalKey<FormState>();
  final _amountController = TextEditingController();
  DateTime _paymentDate = DateTime.now();
  bool _isLoading = false;
  String? _errorMessage;
  
  @override
  void initState() {
    super.initState();
    // Initialize with expected payment amount
    _amountController.text = widget.payment.expectedAmount.toString();
  }

  @override
  void dispose() {
    _amountController.dispose();
    super.dispose();
  }
  
  Future<void> _selectPaymentDate() async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _paymentDate,
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
    );
    
    if (picked != null && picked != _paymentDate) {
      setState(() {
        _paymentDate = picked;
      });
    }
  }
  
  Future<void> _registerPayment() async {
    if (_formKey.currentState?.validate() ?? false) {
      setState(() {
        _isLoading = true;
        _errorMessage = null;
      });
      
      try {
        final installmentProvider = Provider.of<InstallmentProvider>(context, listen: false);
        
        // Create updated payment object
        final updatedPayment = widget.payment.copyWith(
          paidAmount: double.parse(_amountController.text),
          status: 'оплачено',
          paidDate: _paymentDate,
          updatedAt: DateTime.now(),
        );
        
        // Update payment in repository
        await installmentProvider.updatePayment(updatedPayment);
        
        if (mounted) {
          Navigator.of(context).pop(true);
        }
      } catch (e) {
        setState(() {
          _errorMessage = 'Ошибка при регистрации платежа: ${e.toString()}';
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(
        'Регистрация платежа',
        style: Theme.of(context).textTheme.titleLarge,
      ),
      content: Form(
        key: _formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (_errorMessage != null) ...[
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                margin: const EdgeInsets.only(bottom: 16),
                decoration: BoxDecoration(
                  color: Colors.red.shade50,
                  borderRadius: BorderRadius.circular(4),
                  border: Border.all(color: Colors.red.shade200),
                ),
                child: Text(
                  _errorMessage!,
                  style: TextStyle(color: Colors.red.shade700, fontSize: 14),
                ),
              ),
            ],
            
            Text(
              widget.payment.paymentLabel,
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 4),
            Text(
              'Срок оплаты: ${app_date_utils.formatDate(widget.payment.dueDate)}',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: AppTheme.textSecondary,
                  ),
            ),
            const SizedBox(height: 16),
            
            TextFormField(
              controller: _amountController,
              decoration: const InputDecoration(
                labelText: 'Сумма платежа',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.payments),
                suffixText: '₽',
              ),
              keyboardType: TextInputType.number,
              validator: (value) {
                if (value == null || value.isEmpty) {
                  return 'Пожалуйста, введите сумму платежа';
                }
                if (double.tryParse(value) == null) {
                  return 'Пожалуйста, введите корректную сумму';
                }
                return null;
              },
            ),
            const SizedBox(height: 16),
            
            InkWell(
              onTap: _selectPaymentDate,
              child: InputDecorator(
                decoration: const InputDecoration(
                  labelText: 'Дата платежа',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.calendar_today),
                ),
                child: Text(
                  app_date_utils.formatDate(_paymentDate),
                  style: Theme.of(context).textTheme.bodyLarge,
                ),
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: _isLoading ? null : () => Navigator.of(context).pop(),
          child: const Text('Отмена'),
        ),
        ElevatedButton(
          onPressed: _isLoading ? null : _registerPayment,
          child: _isLoading
              ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Text('Зарегистрировать'),
        ),
      ],
    );
  }
} 