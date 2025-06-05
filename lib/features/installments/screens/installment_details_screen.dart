import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/localization/app_localizations.dart';
import '../domain/entities/installment.dart';
import '../domain/entities/installment_payment.dart';
import '../domain/repositories/installment_repository.dart';
import '../data/repositories/installment_repository_impl.dart';
import '../data/datasources/installment_local_datasource.dart';
import '../../clients/domain/entities/client.dart';
import '../../clients/domain/repositories/client_repository.dart';
import '../../clients/data/repositories/client_repository_impl.dart';
import '../../clients/data/datasources/client_local_datasource.dart';
import '../../investors/domain/entities/investor.dart';
import '../../investors/domain/repositories/investor_repository.dart';
import '../../investors/data/repositories/investor_repository_impl.dart';
import '../../investors/data/datasources/investor_local_datasource.dart';
import '../../../shared/database/database_helper.dart';
import '../widgets/installment_payment_item.dart';

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
  late InstallmentRepository _installmentRepository;
  late ClientRepository _clientRepository;
  late InvestorRepository _investorRepository;

  Installment? _installment;
  Client? _client;
  Investor? _investor;
  List<InstallmentPayment> _payments = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _initializeRepositories();
    _loadData();
  }

  void _initializeRepositories() {
    final db = DatabaseHelper.instance;
    _installmentRepository = InstallmentRepositoryImpl(
      InstallmentLocalDataSourceImpl(db),
    );
    _clientRepository = ClientRepositoryImpl(
      ClientLocalDataSourceImpl(db),
    );
    _investorRepository = InvestorRepositoryImpl(
      InvestorLocalDataSourceImpl(db),
    );
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    try {
      final installment = await _installmentRepository.getInstallmentById(widget.installmentId);
      if (installment == null) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Рассрочка не найдена')),
          );
          context.go('/installments');
        }
        return;
      }

      final client = await _clientRepository.getClientById(installment.clientId);
      final investor = installment.investorId.isNotEmpty 
          ? await _investorRepository.getInvestorById(installment.investorId)
          : null;
      final payments = await _installmentRepository.getPaymentsByInstallmentId(widget.installmentId);

      setState(() {
        _installment = installment;
        _client = client;
        _investor = investor;
        _payments = payments;
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Ошибка загрузки: $e')),
        );
      }
    }
  }

  double get _totalPaidAmount {
    return _payments.fold(0, (sum, payment) => sum + payment.paidAmount);
  }

  double get _totalRemainingAmount {
    return _installment!.installmentPrice - _totalPaidAmount;
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);

    if (_isLoading) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    if (_installment == null) {
      return Scaffold(
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.error_outline, size: 64, color: Colors.grey),
              const SizedBox(height: 16),
              const Text('Рассрочка не найдена'),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: () => context.go('/installments'),
                child: const Text('Вернуться к списку'),
              ),
            ],
          ),
        ),
      );
    }

    final currencyFormat = NumberFormat.currency(
      locale: 'ru_RU',
      symbol: '₽',
      decimalDigits: 0,
    );
    final dateFormat = DateFormat('dd.MM.yyyy');

    return Scaffold(
      backgroundColor: AppTheme.backgroundColor,
      body: Column(
        children: [
          // Header
          Container(
            padding: const EdgeInsets.all(24),
            decoration: const BoxDecoration(
              color: AppTheme.surfaceColor,
              border: Border(
                bottom: BorderSide(
                  color: AppTheme.borderColor,
                  width: 1,
                ),
              ),
            ),
            child: Row(
              children: [
                IconButton(
                  onPressed: () => context.go('/installments'),
                  icon: const Icon(Icons.arrow_back),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Рассрочка: ${_installment!.productName}',
                        style: Theme.of(context).textTheme.headlineMedium,
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Клиент: ${_client?.fullName ?? "Неизвестно"}',
                        style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                              color: AppTheme.textSecondary,
                            ),
                      ),
                    ],
                  ),
                ),
                ElevatedButton.icon(
                  onPressed: () => context.go('/installments/${widget.installmentId}/edit'),
                  icon: const Icon(Icons.edit),
                  label: const Text('Редактировать'),
                ),
              ],
            ),
          ),
          // Content
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: Column(
                children: [
                  // Installment Info Cards
                  Row(
                    children: [
                      Expanded(
                        child: _buildInfoCard(
                          title: 'Общая сумма',
                          value: currencyFormat.format(_installment!.installmentPrice),
                          icon: Icons.account_balance_wallet,
                          color: AppTheme.primaryColor,
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: _buildInfoCard(
                          title: 'Оплачено',
                          value: currencyFormat.format(_totalPaidAmount),
                          icon: Icons.check_circle,
                          color: AppTheme.successColor,
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: _buildInfoCard(
                          title: 'Остаток',
                          value: currencyFormat.format(_totalRemainingAmount),
                          icon: Icons.pending,
                          color: _totalRemainingAmount > 0 ? AppTheme.warningColor : AppTheme.successColor,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),
                  // Installment Details
                  Container(
                    padding: const EdgeInsets.all(24),
                    decoration: BoxDecoration(
                      color: AppTheme.surfaceColor,
                      borderRadius: BorderRadius.circular(12),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.05),
                          blurRadius: 10,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Детали рассрочки',
                          style: Theme.of(context).textTheme.titleLarge?.copyWith(
                                fontWeight: FontWeight.w600,
                              ),
                        ),
                        const SizedBox(height: 20),
                        _buildDetailRow('Товар', _installment!.productName),
                        _buildDetailRow('Клиент', _client?.fullName ?? 'Неизвестно'),
                        if (_investor != null)
                          _buildDetailRow('Инвестор', _investor!.fullName),
                        _buildDetailRow('Цена без рассрочки', currencyFormat.format(_installment!.cashPrice)),
                        _buildDetailRow('Цена в рассрочку', currencyFormat.format(_installment!.installmentPrice)),
                        _buildDetailRow('Срок', '${_installment!.termMonths} месяцев'),
                        _buildDetailRow('Первоначальный взнос', currencyFormat.format(_installment!.downPayment)),
                        _buildDetailRow('Ежемесячный платеж', currencyFormat.format(_installment!.monthlyPayment)),
                        _buildDetailRow('Дата покупки', dateFormat.format(_installment!.downPaymentDate)),
                        _buildDetailRow('Начало рассрочки', dateFormat.format(_installment!.installmentStartDate)),
                        _buildDetailRow('Окончание рассрочки', dateFormat.format(_installment!.installmentEndDate)),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),
                  // Payments List
                  Container(
                    decoration: BoxDecoration(
                      color: AppTheme.surfaceColor,
                      borderRadius: BorderRadius.circular(12),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.05),
                          blurRadius: 10,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Padding(
                          padding: const EdgeInsets.all(24),
                          child: Text(
                            'График платежей',
                            style: Theme.of(context).textTheme.titleLarge?.copyWith(
                                  fontWeight: FontWeight.w600,
                                ),
                          ),
                        ),
                        if (_payments.isEmpty)
                          const Padding(
                            padding: EdgeInsets.all(24),
                            child: Center(
                              child: Text('Нет платежей'),
                            ),
                          )
                        else
                          Column(
                            children: _payments.map((payment) {
                              return InstallmentPaymentItem(
                                payment: payment,
                                onRegisterPayment: () => _showRegisterPaymentDialog(payment),
                              );
                            }).toList(),
                          ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoCard({
    required String title,
    required String value,
    required IconData icon,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppTheme.surfaceColor,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: color.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(icon, color: color, size: 20),
              ),
              const Spacer(),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            title,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: AppTheme.textSecondary,
                ),
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.w600,
                  color: color,
                ),
          ),
        ],
      ),
    );
  }

  Widget _buildDetailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 200,
            child: Text(
              label,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: AppTheme.textSecondary,
                  ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    fontWeight: FontWeight.w500,
                  ),
            ),
          ),
        ],
      ),
    );
  }

  void _showRegisterPaymentDialog(InstallmentPayment payment) {
    showDialog(
      context: context,
      builder: (context) => _RegisterPaymentDialog(
        payment: payment,
        onPaymentRegistered: () {
          _loadData(); // Reload data after payment
        },
      ),
    );
  }
}

class _RegisterPaymentDialog extends StatefulWidget {
  final InstallmentPayment payment;
  final VoidCallback onPaymentRegistered;

  const _RegisterPaymentDialog({
    required this.payment,
    required this.onPaymentRegistered,
  });

  @override
  State<_RegisterPaymentDialog> createState() => _RegisterPaymentDialogState();
}

class _RegisterPaymentDialogState extends State<_RegisterPaymentDialog> {
  late TextEditingController _amountController;
  late InstallmentRepository _repository;

  @override
  void initState() {
    super.initState();
    _amountController = TextEditingController(
      text: widget.payment.expectedAmount.toStringAsFixed(0),
    );
    _repository = InstallmentRepositoryImpl(
      InstallmentLocalDataSourceImpl(DatabaseHelper.instance),
    );
  }

  @override
  void dispose() {
    _amountController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text('Регистрация платежа ${widget.payment.paymentNumber == 0 ? "(Первоначальный взнос)" : "(Месяц ${widget.payment.paymentNumber})"}'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          TextField(
            controller: _amountController,
            keyboardType: TextInputType.number,
            decoration: const InputDecoration(
              labelText: 'Сумма платежа',
              suffixText: '₽',
            ),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Отмена'),
        ),
        ElevatedButton(
          onPressed: () async {
            final amount = double.tryParse(_amountController.text) ?? 0;
            if (amount > 0) {
              final updatedPayment = widget.payment.copyWith(
                paidAmount: amount,
                paidDate: DateTime.now(),
                status: 'оплачено',
              );
              
              await _repository.updatePayment(updatedPayment);
              widget.onPaymentRegistered();
              Navigator.of(context).pop();
            }
          },
          child: const Text('Сохранить'),
        ),
      ],
    );
  }
} 