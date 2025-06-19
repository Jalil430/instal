import 'package:flutter/material.dart';
import 'package:instal_app/features/installments/domain/entities/installment.dart';
import 'package:instal_app/features/installments/domain/entities/installment_payment.dart';
import 'package:instal_app/features/installments/domain/repositories/installment_repository.dart';
import 'package:instal_app/features/installments/data/repositories/installment_repository_impl.dart';
import 'package:instal_app/features/installments/data/datasources/installment_local_datasource.dart';
import 'package:instal_app/shared/database/database_helper.dart';
import 'package:instal_app/core/theme/app_theme.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:intl/intl.dart';
import '../widgets/metric_card.dart';
import '../widgets/installment_status_pie_chart.dart';
import '../widgets/product_popularity_bar_chart.dart';
import '../../../core/localization/app_localizations.dart';


class AnalyticsScreen extends StatefulWidget {
  const AnalyticsScreen({super.key});

  @override
  State<AnalyticsScreen> createState() => _AnalyticsScreenState();
}

class _AnalyticsScreenState extends State<AnalyticsScreen> {
  late InstallmentRepository _installmentRepository;
  bool _isLoading = true;
  List<Installment> _installments = [];
  Map<String, List<InstallmentPayment>> _paymentsByInstallment = {};

  // Calculated analytics data
  double _totalPortfolioValue = 0;
  double _totalReceived = 0;
  double _totalOutstanding = 0;
  int _activeInstallments = 0;
  int _completedInstallments = 0;
  int _overdueInstallments = 0;
  Map<String, double> _revenueByMonth = {};
  Map<String, int> _productPopularity = {};


  @override
  void initState() {
    super.initState();
    final db = DatabaseHelper.instance;
    _installmentRepository = InstallmentRepositoryImpl(
      InstallmentLocalDataSourceImpl(db),
    );
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    try {
      const userId = 'user123'; // TODO: Replace with actual user ID
      _installments = await _installmentRepository.getAllInstallments(userId);
      
      for (final installment in _installments) {
        final payments = await _installmentRepository.getPaymentsByInstallmentId(installment.id);
        _paymentsByInstallment[installment.id] = payments;
      }

      _calculateAnalytics();

      setState(() => _isLoading = false);
    } catch (e) {
      setState(() => _isLoading = false);
      // Handle error
    }
  }

  void _calculateAnalytics() {
    // Reset values
    _totalPortfolioValue = 0;
    _totalReceived = 0;
    _activeInstallments = 0;
    _completedInstallments = 0;
    _overdueInstallments = 0;
    _revenueByMonth = {};
    _productPopularity = {};

    for (final installment in _installments) {
      final payments = _paymentsByInstallment[installment.id] ?? [];
      
      bool isCompleted = payments.every((p) => p.isPaid);
      bool isOverdue = payments.any((p) => p.isOverdue);

      _totalPortfolioValue += installment.installmentPrice;
      
      for (final payment in payments) {
        if (payment.isPaid) {
          _totalReceived += payment.paidAmount;
        }
      }

      if (isCompleted) {
        _completedInstallments++;
      } else {
        _activeInstallments++;
        if (isOverdue) {
          _overdueInstallments++;
        }
      }
      
      // Product Popularity
      _productPopularity[installment.productName] = (_productPopularity[installment.productName] ?? 0) + 1;
    }
    _totalOutstanding = _totalPortfolioValue - _totalReceived;
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;

    return Scaffold(
      backgroundColor: AppTheme.backgroundColor,
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(AppTheme.spacingLg),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    l10n.analytics,
                    style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: AppTheme.spacingMd),
                  _buildMetricsGrid(l10n),
                  const SizedBox(height: AppTheme.spacingLg),
                  _buildCharts(l10n),
                ],
              ),
            ),
    );
  }

  Widget _buildMetricsGrid(AppLocalizations l10n) {
    final currencyFormat = NumberFormat.currency(locale: 'ru_RU', symbol: '₽');

    return GridView.count(
      crossAxisCount: 3,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      crossAxisSpacing: AppTheme.spacingMd,
      mainAxisSpacing: AppTheme.spacingMd,
      childAspectRatio: 2.2,
      children: [
        MetricCard(
          title: l10n.totalPortfolio,
          value: currencyFormat.format(_totalPortfolioValue),
          icon: Icons.account_balance_wallet_outlined,
          color: Colors.blue,
        ),
        MetricCard(
          title: l10n.totalReceived,
          value: currencyFormat.format(_totalReceived),
          icon: Icons.trending_up,
          color: Colors.green,
        ),
        MetricCard(
          title: l10n.totalOutstanding,
          value: currencyFormat.format(_totalOutstanding),
          icon: Icons.trending_down,
          color: Colors.orange,
        ),
        MetricCard(
          title: l10n.activeInstallments,
          value: _activeInstallments.toString(),
          icon: Icons.hourglass_bottom,
          color: Colors.purple,
        ),
        MetricCard(
          title: l10n.completedInstallments,
          value: _completedInstallments.toString(),
          icon: Icons.check_circle_outline,
          color: Colors.teal,
        ),
        MetricCard(
          title: l10n.overdueInstallments,
          value: _overdueInstallments.toString(),
          icon: Icons.error_outline,
          color: Colors.red,
        ),
      ],
    );
  }
  
  Widget _buildCharts(AppLocalizations l10n) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: InstallmentStatusPieChart(
            title: l10n.installmentStatus,
            active: _activeInstallments,
            completed: _completedInstallments,
            overdue: _overdueInstallments,
          ),
        ),
        const SizedBox(width: AppTheme.spacingMd),
        Expanded(
          child: ProductPopularityBarChart(
            title: l10n.productPopularity,
            productPopularity: _productPopularity,
          ),
        ),
      ],
    );
  }
} 