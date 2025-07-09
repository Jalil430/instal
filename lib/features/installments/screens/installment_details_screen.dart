import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/localization/app_localizations.dart';
import '../../../shared/widgets/custom_icon_button.dart';
import '../domain/entities/installment.dart';
import '../domain/entities/installment_payment.dart';
import '../domain/repositories/installment_repository.dart';
import '../data/repositories/installment_repository_impl.dart';
import '../data/datasources/installment_remote_datasource.dart';
import '../../clients/domain/entities/client.dart';
import '../../clients/domain/repositories/client_repository.dart';
import '../../clients/data/repositories/client_repository_impl.dart';
import '../../clients/data/datasources/client_remote_datasource.dart';
import '../../investors/domain/entities/investor.dart';
import '../../investors/domain/repositories/investor_repository.dart';
import '../../investors/data/repositories/investor_repository_impl.dart';
import '../../investors/data/datasources/investor_remote_datasource.dart';
import '../widgets/installment_payment_item.dart';
import '../../../shared/widgets/custom_confirmation_dialog.dart';

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
  bool _isInitialized = false;

  @override
  void initState() {
    super.initState();
    _initializeRepositories();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_isInitialized) {
      _loadData();
      _isInitialized = true;
    }
  }

  void _initializeRepositories() {
    _installmentRepository = InstallmentRepositoryImpl(
      InstallmentRemoteDataSourceImpl(),
    );
    _clientRepository = ClientRepositoryImpl(
      ClientRemoteDataSourceImpl(),
    );
    _investorRepository = InvestorRepositoryImpl(
      InvestorRemoteDataSourceImpl(),
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
    return _payments.fold(
        0.0, (sum, payment) => sum + (payment.isPaid ? payment.expectedAmount : 0.0));
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
      backgroundColor: Colors.white,
      body: Column(
        children: [
          // Top section
          Container(
            padding: const EdgeInsets.fromLTRB(32, 28, 32, 20),
            color: AppTheme.surfaceColor,
            child: Row(
              children: [
                CustomIconButton(
                  routePath: '/installments',
                ),
                const SizedBox(width: 16),
                Text(
                  l10n?.installmentDetails ?? 'Детали рассрочки',
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w600,
                    letterSpacing: -0.5,
                  ),
                ),
                const Spacer(),
                const SizedBox(width: 12),
                CustomIconButton(
                  icon: Icons.delete_outline,
                  onPressed: () async {
                    final confirmed = await showCustomConfirmationDialog(
                      context: context,
                      title: l10n?.deleteInstallmentTitle ?? 'Удалить рассрочку',
                      content: l10n?.deleteInstallmentConfirmation ??
                          'Вы уверены, что хотите удалить рассрочку?',
                    );
                    if (confirmed == true) {
                      try {
                        await _installmentRepository.deleteInstallment(_installment!.id);
                        if (mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                                content: Text(l10n?.installmentDeleted ??
                                    'Рассрочка удалена')),
                          );
                          context.go('/installments');
                        }
                      } catch (e) {
                        if (mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(content: Text('Ошибка удаления: $e')),
                          );
                        }
                      }
                    }
                  },
                  hoverBackgroundColor: AppTheme.errorColor.withOpacity(0.1),
                  hoverIconColor: AppTheme.errorColor,
                  hoverBorderColor: AppTheme.errorColor.withOpacity(0.3),
                ),
              ],
            ),
          ),
          // Main content
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Information section
                  Text(
                    l10n?.information ?? 'Информация',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w500,
                      color: AppTheme.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 20),
                  _buildInfoRow(l10n?.product ?? 'Товар', _installment!.productName),
                  _buildInfoRow(l10n?.client ?? 'Клиент', _client?.fullName ?? 'Неизвестно'),
                  if (_investor != null)
                    _buildInfoRow(l10n?.investor ?? 'Инвестор', _investor!.fullName),
                  _buildInfoRow(
                      l10n?.cashPrice ?? 'Цена без рассрочки', currencyFormat.format(_installment!.cashPrice)),
                  _buildInfoRow(l10n?.installmentPrice ?? 'Цена в рассрочку', currencyFormat.format(_installment!.installmentPrice)),
                  _buildInfoRow(l10n?.term ?? 'Срок', '${_installment!.termMonths} ${l10n?.monthsLabel ?? 'месяцев'}'),
                  _buildInfoRow(l10n?.downPaymentFull ?? 'Первоначальный взнос', currencyFormat.format(_installment!.downPayment)),
                  _buildInfoRow(l10n?.monthlyPayment ?? 'Ежемесячный платеж', currencyFormat.format(_installment!.monthlyPayment)),
                  _buildInfoRow(l10n?.buyingDate ?? 'Дата покупки', dateFormat.format(_installment!.downPaymentDate)),
                  _buildInfoRow(l10n?.installmentStartDate ?? 'Дата начала рассрочки', dateFormat.format(_installment!.installmentStartDate)),
                  _buildInfoRow(l10n?.installmentEndDate ?? 'Дата окончания рассрочки', dateFormat.format(_installment!.installmentEndDate)),
                  _buildInfoRow(l10n?.paidAmount ?? 'Оплачено', currencyFormat.format(_totalPaidAmount)),
                  _buildInfoRow(l10n?.leftAmount ?? 'Остаток', currencyFormat.format(_totalRemainingAmount)),

                  const SizedBox(height: 20),

                  // Payment Schedule section
                  Text(
                    l10n?.scheduleHeader ?? 'График платежей',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w500,
                      color: AppTheme.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 14),
                  Container(
                    decoration: BoxDecoration(
                      color: AppTheme.surfaceColor,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Column(
                      children: [
                        _buildTableHeader(context),
                        if (_payments.isEmpty)
                          Padding(
                            padding: const EdgeInsets.all(24),
                            child: Center(
                              child: Text(l10n?.noPayments ?? 'Нет платежей'),
                            ),
                          )
                        else
                          ..._payments.map((payment) {
                            return InstallmentPaymentItem(
                              payment: payment,
                              onPaymentUpdated: _loadData,
                              isExpanded: false,
                            );
                          }),
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

  Widget _buildTableHeader(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      decoration: BoxDecoration(
        color: AppTheme.subtleBackgroundColor,
        borderRadius: const BorderRadius.only(
          topLeft: Radius.circular(11),
          topRight: Radius.circular(11),
        ),
        border: Border(
          bottom: BorderSide(
            color: AppTheme.subtleBorderColor,
            width: 1,
          ),
        ),
      ),
      child: Row(
        children: [
          Expanded(
            flex: 2,
            child: Padding(
              padding: const EdgeInsets.only(right: 16),
              child: Text(
                l10n?.paymentHeader ?? 'ПЛАТЕЖ',
                style: Theme.of(context).textTheme.labelMedium?.copyWith(
                      color: AppTheme.textSecondary,
                      fontWeight: FontWeight.w400,
                      fontSize: 12,
                      letterSpacing: 0.5,
                    ),
              ),
            ),
          ),
          Expanded(
            flex: 2,
            child: Padding(
              padding: const EdgeInsets.only(right: 16),
              child: Text(
                l10n?.dateHeader ?? 'ДАТА',
                style: Theme.of(context).textTheme.labelMedium?.copyWith(
                      color: AppTheme.textSecondary,
                      fontWeight: FontWeight.w400,
                      fontSize: 12,
                      letterSpacing: 0.5,
                    ),
              ),
            ),
          ),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.only(right: 16),
              child: Container(), // Spacer to match layout
            ),
          ),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.only(right: 16),
              child: Container(), // Spacer to match layout
            ),
          ),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.only(right: 16),
              child: Container(), // Spacer to match layout
            ),
          ),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.only(right: 16),
              child: Text(
                l10n?.statusHeader ?? 'СТАТУС',
                style: Theme.of(context).textTheme.labelMedium?.copyWith(
                      color: AppTheme.textSecondary,
                      fontWeight: FontWeight.w400,
                      fontSize: 12,
                      letterSpacing: 0.5,
                    ),
              ),
            ),
          ),
          Container(
            width: 160,
            padding: const EdgeInsets.only(left: 8),
            child: Text(
              l10n?.amountHeader ?? 'СУММА',
              style: Theme.of(context).textTheme.labelMedium?.copyWith(
                    color: AppTheme.textSecondary,
                    fontWeight: FontWeight.w400,
                    fontSize: 12,
                    letterSpacing: 0.5,
                  ),
              textAlign: TextAlign.start,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 200,
            child: Text(
              label,
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w400,
                color: Colors.grey,
              ),
            ),
          ),
          const SizedBox(width: 32),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w500,
                color: AppTheme.textPrimary,
              ),
            ),
          ),
        ],
      ),
    );
  }
} 