import 'package:fluent_ui/fluent_ui.dart';
import 'package:intl/intl.dart';
import '../../models/installment.dart';
import '../../models/installment_payment.dart';
import '../../models/client.dart';
import '../../models/investor.dart';
import '../../services/database_service.dart';
import '../../utils/theme.dart';

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
  Installment? _installment;
  Client? _client;
  Investor? _investor;
  List<InstallmentPayment> _payments = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);

    try {
      final installment = await DatabaseService.getInstallment(widget.installmentId);
      if (installment != null) {
        final client = await DatabaseService.getClient(installment.clientId);
        final investor = installment.investorId != null 
            ? await DatabaseService.getInvestor(installment.investorId!)
            : null;
        final payments = await DatabaseService.getInstallmentPayments(installment.id);
        
        // Update payment statuses
        await DatabaseService.updatePaymentStatuses();
        
        setState(() {
          _installment = installment;
          _client = client;
          _investor = investor;
          _payments = payments;
          _isLoading = false;
        });
      } else {
        setState(() => _isLoading = false);
        if (mounted) {
          Navigator.of(context).pop();
        }
      }
    } catch (e) {
      setState(() => _isLoading = false);
      if (mounted) {
        showDialog(
          context: context,
          builder: (context) => ContentDialog(
            title: const Text('Error'),
            content: Text('Failed to load data: $e'),
            actions: [
              Button(
                child: const Text('OK'),
                onPressed: () => Navigator.of(context).pop(),
              ),
            ],
          ),
        );
      }
    }
  }

  Future<void> _registerPayment(InstallmentPayment payment) async {
    final amountController = TextEditingController(
      text: payment.expectedAmount.toStringAsFixed(2),
    );

    final result = await showDialog<bool>(
      context: context,
      builder: (context) => ContentDialog(
        title: Text('Register Payment - ${payment.displayName}'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            InfoLabel(
              label: 'Payment Amount',
              child: TextBox(
                controller: amountController,
                prefix: const Padding(
                  padding: EdgeInsets.only(left: 8),
                  child: Text('\$'),
                ),
                keyboardType: TextInputType.number,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Expected: \$${payment.expectedAmount.toStringAsFixed(2)}',
              style: AppTheme.captionStyle,
            ),
          ],
        ),
        actions: [
          Button(
            child: const Text('Cancel'),
            onPressed: () => Navigator.of(context).pop(false),
          ),
          FilledButton(
            child: const Text('Register Payment'),
            onPressed: () => Navigator.of(context).pop(true),
          ),
        ],
      ),
    );

    if (result == true) {
      final amount = double.tryParse(amountController.text) ?? 0;
      if (amount > 0) {
        await DatabaseService.updatePaymentStatus(
          payment.id,
          amount,
          DateTime.now(),
        );
        _loadData();
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Center(child: ProgressRing());
    }

    if (_installment == null) {
      return const Center(child: Text('Installment not found'));
    }

    final currencyFormat = NumberFormat.currency(symbol: '\$', decimalDigits: 2);
    final dateFormat = DateFormat('MMM d, yyyy');
    final totalPaid = _payments.fold<double>(
      0,
      (sum, payment) => sum + payment.paidAmount,
    );
    final totalLeft = _installment!.installmentPrice - totalPaid;
    final progress = totalPaid / _installment!.installmentPrice;

    return NavigationView(
      appBar: NavigationAppBar(
        title: Text('Installment Details - ${_installment!.productName}'),
        leading: IconButton(
          icon: const Icon(FluentIcons.back),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      content: ScaffoldPage(
        content: ListView(
          padding: const EdgeInsets.all(24),
          children: [
            // Overview Card
            Card(
              padding: const EdgeInsets.all(24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            _installment!.productName,
                            style: AppTheme.headlineStyle,
                          ),
                          const SizedBox(height: 4),
                          Text(
                            _client?.fullName ?? 'Unknown Client',
                            style: AppTheme.subtitleStyle.copyWith(
                              color: AppTheme.textSecondaryColor,
                            ),
                          ),
                        ],
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                        decoration: BoxDecoration(
                          color: progress >= 1 
                              ? AppTheme.successColor.withOpacity(0.1)
                              : AppTheme.primaryColor.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text(
                          progress >= 1 ? 'Completed' : 'Active',
                          style: TextStyle(
                            color: progress >= 1 
                                ? AppTheme.successColor
                                : AppTheme.primaryColor,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),
                  
                  // Progress Bar
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            'Payment Progress',
                            style: AppTheme.bodyStyle.copyWith(
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          Text(
                            '${(progress * 100).toStringAsFixed(1)}%',
                            style: AppTheme.bodyStyle.copyWith(
                              fontWeight: FontWeight.w600,
                              color: AppTheme.primaryColor,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      ProgressBar(
                        value: progress * 100,
                        strokeWidth: 8,
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),
                  
                  // Financial Summary
                  Row(
                    children: [
                      Expanded(
                        child: _SummaryItem(
                          label: 'Total Amount',
                          value: currencyFormat.format(_installment!.installmentPrice),
                          icon: FluentIcons.money,
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: _SummaryItem(
                          label: 'Paid',
                          value: currencyFormat.format(totalPaid),
                          icon: FluentIcons.check_mark,
                          color: AppTheme.successColor,
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: _SummaryItem(
                          label: 'Remaining',
                          value: currencyFormat.format(totalLeft),
                          icon: FluentIcons.clock,
                          color: AppTheme.warningColor,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),
            
            // Details Grid
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Card(
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Installment Information', style: AppTheme.subtitleStyle),
                        const SizedBox(height: 16),
                        _DetailRow('Cash Price', currencyFormat.format(_installment!.cashPrice)),
                        _DetailRow('Installment Price', currencyFormat.format(_installment!.installmentPrice)),
                        _DetailRow('Down Payment', currencyFormat.format(_installment!.downPayment)),
                        _DetailRow('Monthly Payment', currencyFormat.format(_installment!.monthlyPayment)),
                        _DetailRow('Term', '${_installment!.term} months'),
                      ],
                    ),
                  ),
                ),
                const SizedBox(width: 20),
                Expanded(
                  child: Card(
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Important Dates', style: AppTheme.subtitleStyle),
                        const SizedBox(height: 16),
                        _DetailRow('Buying Date', dateFormat.format(_installment!.downPaymentDate)),
                        _DetailRow('Start Date', dateFormat.format(_installment!.installmentStartDate)),
                        _DetailRow('End Date', dateFormat.format(_installment!.installmentEndDate)),
                        _DetailRow('Created', dateFormat.format(_installment!.createdAt)),
                        if (_investor != null)
                          _DetailRow('Investor', _investor!.fullName),
                      ],
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
            
            // Payment Schedule
            Card(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Payment Schedule', style: AppTheme.subtitleStyle),
                  const SizedBox(height: 20),
                  if (_payments.isEmpty)
                    const Center(
                      child: Padding(
                        padding: EdgeInsets.all(40),
                        child: Text('No payments found'),
                      ),
                    )
                  else
                    ..._payments.map((payment) => _PaymentListItem(
                      payment: payment,
                      onRegisterPayment: () => _registerPayment(payment),
                    )),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SummaryItem extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;
  final Color? color;

  const _SummaryItem({
    required this.label,
    required this.value,
    required this.icon,
    this.color,
  });

  @override
  Widget build(BuildContext context) {
    final displayColor = color ?? AppTheme.primaryColor;
    
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: displayColor.withOpacity(0.05),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: displayColor.withOpacity(0.2),
          width: 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 16, color: displayColor),
              const SizedBox(width: 8),
              Text(
                label,
                style: AppTheme.captionStyle.copyWith(color: displayColor),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            value,
            style: AppTheme.subtitleStyle.copyWith(
              fontSize: 20,
              fontWeight: FontWeight.w600,
              color: displayColor,
            ),
          ),
        ],
      ),
    );
  }
}

class _DetailRow extends StatelessWidget {
  final String label;
  final String value;

  const _DetailRow(this.label, this.value);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: AppTheme.bodyStyle.copyWith(
              color: AppTheme.textSecondaryColor,
            ),
          ),
          Text(
            value,
            style: AppTheme.bodyStyle.copyWith(
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}

class _PaymentListItem extends StatelessWidget {
  final InstallmentPayment payment;
  final VoidCallback onRegisterPayment;

  const _PaymentListItem({
    required this.payment,
    required this.onRegisterPayment,
  });

  @override
  Widget build(BuildContext context) {
    final currencyFormat = NumberFormat.currency(symbol: '\$', decimalDigits: 2);
    final dateFormat = DateFormat('MMM d, yyyy');
    final isPaid = payment.status == PaymentStatus.paid;
    
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isPaid 
            ? AppTheme.successColor.withOpacity(0.05)
            : AppTheme.backgroundColor,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: isPaid 
              ? AppTheme.successColor.withOpacity(0.2)
              : AppTheme.borderColor,
          width: 1,
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: isPaid 
                  ? AppTheme.successColor
                  : AppTheme.getStatusColor(payment.status.label).withOpacity(0.1),
              shape: BoxShape.circle,
            ),
            child: Center(
              child: isPaid
                  ? const Icon(
                      FluentIcons.check_mark,
                      color: Colors.white,
                      size: 20,
                    )
                  : Text(
                      payment.paymentNumber.toString(),
                      style: TextStyle(
                        fontWeight: FontWeight.w600,
                        color: AppTheme.getStatusColor(payment.status.label),
                      ),
                    ),
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  payment.displayName,
                  style: AppTheme.bodyStyle.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Due: ${dateFormat.format(payment.dueDate)}',
                  style: AppTheme.captionStyle,
                ),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                currencyFormat.format(payment.expectedAmount),
                style: AppTheme.bodyStyle.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 4),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: AppTheme.getStatusColor(payment.status.label).withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  payment.status.label,
                  style: AppTheme.captionStyle.copyWith(
                    color: AppTheme.getStatusColor(payment.status.label),
                    fontSize: 11,
                  ),
                ),
              ),
            ],
          ),
          if (!isPaid) ...[
            const SizedBox(width: 12),
            Button(
              child: const Text('Pay'),
              onPressed: onRegisterPayment,
            ),
          ] else if (payment.paidDate != null) ...[
            const SizedBox(width: 12),
            Tooltip(
              message: 'Paid on ${dateFormat.format(payment.paidDate!)}',
              child: Icon(
                FluentIcons.info,
                size: 16,
                color: AppTheme.textSecondaryColor,
              ),
            ),
          ],
        ],
      ),
    );
  }
} 