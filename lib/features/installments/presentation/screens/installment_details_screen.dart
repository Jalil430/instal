import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../../core/themes/app_theme.dart';
import '../../../../core/utils/date_utils.dart' as app_date_utils;
import '../../../clients/domain/entities/client.dart';
import '../../../clients/presentation/providers/client_provider.dart';
import '../../../investors/domain/entities/investor.dart';
import '../../../investors/presentation/providers/investor_provider.dart';
import '../../domain/entities/installment.dart';
import '../../domain/entities/installment_payment.dart';
import '../providers/installment_provider.dart';
import '../widgets/payment_status_badge.dart';
import '../widgets/register_payment_dialog.dart';

class InstallmentDetailsScreen extends StatefulWidget {
  final String installmentId;

  const InstallmentDetailsScreen({
    super.key,
    required this.installmentId,
  });

  @override
  State<InstallmentDetailsScreen> createState() => _InstallmentDetailsScreenState();
}

class _InstallmentDetailsScreenState extends State<InstallmentDetailsScreen> {
  bool _isLoading = true;
  String? _errorMessage;
  Installment? _installment;
  List<InstallmentPayment> _payments = [];
  Client? _client;
  Investor? _investor;
  
  double _totalPaid = 0;
  double _totalRemaining = 0;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final installmentProvider = Provider.of<InstallmentProvider>(context, listen: false);
      final clientProvider = Provider.of<ClientProvider>(context, listen: false);
      final investorProvider = Provider.of<InvestorProvider>(context, listen: false);
      
      // Load installment
      final installment = await installmentProvider.getInstallmentById(widget.installmentId);
      
      if (installment == null) {
        setState(() {
          _errorMessage = 'Рассрочка не найдена';
          _isLoading = false;
        });
        return;
      }
      
      // Load client
      final client = await clientProvider.getClientById(installment.clientId);
      
      // Load investor if available
      Investor? investor;
      if (installment.investorId.isNotEmpty) {
        investor = await investorProvider.getInvestorById(installment.investorId);
      }
      
      // Load payments
      final payments = await installmentProvider.getPaymentsByInstallmentId(installment.id);
      
      // Calculate totals
      double totalPaid = 0;
      double totalRemaining = installment.installmentPrice;
      
      for (final payment in payments) {
        if (payment.isPaid) {
          totalPaid += payment.paidAmount;
          totalRemaining -= payment.paidAmount;
        }
      }
      
      if (mounted) {
        setState(() {
          _installment = installment;
          _payments = payments;
          _client = client;
          _investor = investor;
          _totalPaid = totalPaid;
          _totalRemaining = totalRemaining;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = 'Ошибка загрузки данных: ${e.toString()}';
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _showRegisterPaymentDialog(InstallmentPayment payment) async {
    final result = await showDialog<bool>(
      context: context,
      builder: (context) => RegisterPaymentDialog(payment: payment),
    );
    
    if (result == true) {
      // Reload data after payment
      _loadData();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Детали рассрочки'),
        elevation: 0,
        backgroundColor: AppTheme.surfaceColor,
        actions: [
          IconButton(
            icon: const Icon(Icons.edit),
            onPressed: () {
              // TODO: Navigate to edit installment screen
            },
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _errorMessage != null
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.error_outline, size: 64, color: AppTheme.textTertiary),
                      const SizedBox(height: 16),
                      Text(
                        'Ошибка',
                        style: Theme.of(context).textTheme.titleLarge?.copyWith(
                              color: AppTheme.textSecondary,
                            ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        _errorMessage!,
                        style: Theme.of(context).textTheme.bodyMedium,
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 16),
                      ElevatedButton(
                        onPressed: _loadData,
                        child: const Text('Повторить'),
                      ),
                    ],
                  ),
                )
              : Container(
                  color: AppTheme.backgroundColor,
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Header with basic info
                        Card(
                          elevation: 0,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                            side: const BorderSide(color: AppTheme.dividerColor),
                          ),
                          child: Padding(
                            padding: const EdgeInsets.all(24),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            _installment!.productName,
                                            style: Theme.of(context).textTheme.headlineSmall,
                                          ),
                                          const SizedBox(height: 8),
                                          Text(
                                            'Клиент: ${_client?.fullName ?? 'Неизвестно'}',
                                            style: Theme.of(context).textTheme.bodyLarge,
                                          ),
                                          if (_investor != null) ...[
                                            const SizedBox(height: 4),
                                            Text(
                                              'Инвестор: ${_investor?.fullName}',
                                              style: Theme.of(context).textTheme.bodyLarge,
                                            ),
                                          ],
                                        ],
                                      ),
                                    ),
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 16,
                                        vertical: 8,
                                      ),
                                      decoration: BoxDecoration(
                                        color: AppTheme.primaryColor.withOpacity(0.1),
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                      child: Column(
                                        children: [
                                          Text(
                                            '${_installment!.termMonths} мес.',
                                            style: Theme.of(context).textTheme.titleLarge?.copyWith(
                                                  color: AppTheme.primaryColor,
                                                ),
                                          ),
                                          const SizedBox(height: 4),
                                          Text(
                                            'срок',
                                            style: Theme.of(context).textTheme.bodySmall,
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 24),
                                
                                // Payment progress
                                Row(
                                  children: [
                                    Expanded(
                                      child: _buildProgressCard(
                                        title: 'Оплачено',
                                        amount: _totalPaid,
                                        total: _installment!.installmentPrice,
                                        color: Colors.green,
                                      ),
                                    ),
                                    const SizedBox(width: 16),
                                    Expanded(
                                      child: _buildProgressCard(
                                        title: 'Осталось',
                                        amount: _totalRemaining,
                                        total: _installment!.installmentPrice,
                                        color: AppTheme.primaryColor,
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        ),
                        
                        const SizedBox(height: 24),
                        
                        // Installment details
                        Card(
                          elevation: 0,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                            side: const BorderSide(color: AppTheme.dividerColor),
                          ),
                          child: Padding(
                            padding: const EdgeInsets.all(24),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Информация о рассрочке',
                                  style: Theme.of(context).textTheme.titleLarge,
                                ),
                                const SizedBox(height: 16),
                                _buildDetailRow('Цена за наличные:', '${_installment!.cashPrice} ₽'),
                                _buildDetailRow('Цена в рассрочку:', '${_installment!.installmentPrice} ₽'),
                                _buildDetailRow('Первоначальный взнос:', '${_installment!.downPayment} ₽'),
                                _buildDetailRow('Ежемесячный платеж:', '${_installment!.monthlyPayment} ₽'),
                                _buildDetailRow(
                                  'Дата первоначального взноса:',
                                  app_date_utils.formatDate(_installment!.downPaymentDate),
                                ),
                                _buildDetailRow(
                                  'Дата начала рассрочки:',
                                  app_date_utils.formatDate(_installment!.installmentStartDate),
                                ),
                                _buildDetailRow(
                                  'Дата окончания рассрочки:',
                                  app_date_utils.formatDate(_installment!.installmentEndDate),
                                ),
                              ],
                            ),
                          ),
                        ),
                        
                        const SizedBox(height: 24),
                        
                        // Payment schedule
                        Card(
                          elevation: 0,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                            side: const BorderSide(color: AppTheme.dividerColor),
                          ),
                          child: Padding(
                            padding: const EdgeInsets.all(24),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'График платежей',
                                  style: Theme.of(context).textTheme.titleLarge,
                                ),
                                const SizedBox(height: 16),
                                
                                // Payment list
                                ListView.separated(
                                  shrinkWrap: true,
                                  physics: const NeverScrollableScrollPhysics(),
                                  itemCount: _payments.length,
                                  separatorBuilder: (context, index) => const Divider(),
                                  itemBuilder: (context, index) {
                                    final payment = _payments[index];
                                    return _buildPaymentItem(payment);
                                  },
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
    );
  }

  Widget _buildProgressCard({
    required String title,
    required double amount,
    required double total,
    required Color color,
  }) {
    final percentage = total > 0 ? (amount / total * 100).clamp(0, 100) : 0;
    
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppTheme.dividerColor),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 8),
          Text(
            '${amount.toStringAsFixed(2)} ₽',
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const SizedBox(height: 8),
          Stack(
            children: [
              Container(
                height: 8,
                width: double.infinity,
                decoration: BoxDecoration(
                  color: Colors.grey.shade200,
                  borderRadius: BorderRadius.circular(4),
                ),
              ),
              Container(
                height: 8,
                width: percentage * 0.01 * MediaQuery.of(context).size.width * 0.35,
                decoration: BoxDecoration(
                  color: color,
                  borderRadius: BorderRadius.circular(4),
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            '${percentage.toStringAsFixed(1)}%',
            style: Theme.of(context).textTheme.bodySmall,
          ),
        ],
      ),
    );
  }

  Widget _buildDetailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          Expanded(
            flex: 2,
            child: Text(
              label,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: AppTheme.textSecondary,
                  ),
            ),
          ),
          Expanded(
            flex: 3,
            child: Text(
              value,
              style: Theme.of(context).textTheme.bodyMedium,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPaymentItem(InstallmentPayment payment) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Row(
        children: [
          Expanded(
            flex: 3,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  payment.paymentLabel,
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(height: 4),
                Text(
                  'Срок: ${app_date_utils.formatShortDate(payment.dueDate)}',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: AppTheme.textSecondary,
                      ),
                ),
              ],
            ),
          ),
          Expanded(
            flex: 2,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${payment.expectedAmount} ₽',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(height: 4),
                if (payment.isPaid)
                  Text(
                    'Оплачено: ${app_date_utils.formatShortDate(payment.paidDate!)}',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: Colors.green,
                        ),
                  ),
              ],
            ),
          ),
          Expanded(
            flex: 2,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                PaymentStatusBadge(status: payment.status),
                const SizedBox(width: 12),
                if (!payment.isPaid)
                  ElevatedButton(
                    onPressed: () => _showRegisterPaymentDialog(payment),
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 8,
                      ),
                      minimumSize: Size.zero,
                    ),
                    child: const Text('Оплатить'),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
} 