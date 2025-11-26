import 'dart:convert';
import 'package:fl_chart/fl_chart.dart';
import 'package:instal_app/features/analytics/domain/entities/analytics_data.dart';
import 'package:instal_app/features/installments/domain/entities/installment.dart';
import 'package:instal_app/features/installments/domain/entities/installment_payment.dart';
import 'package:instal_app/features/installments/domain/repositories/installment_repository.dart';
import '../../../../core/api/cache_service.dart';
import '../../../../core/api/api_client.dart';

class AnalyticsRepository {
  final InstallmentRepository _installmentRepository;
  final CacheService _cache = CacheService();

  AnalyticsRepository(this._installmentRepository);

  Future<AnalyticsData> getAnalyticsData(
    String userId, {
    String? walletId,
  }) async {
    final cacheKey = CacheService.analyticsKey(userId, walletId);
    final cachedAnalytics = _cache.get<AnalyticsData>(cacheKey);
    if (cachedAnalytics != null) {
      return cachedAnalytics;
    }

    try {
      // Send current date to ensure server uses same date as client
      final now = DateTime.now();
      final dateStr =
          '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';

      // TEMPORARY DEBUG: Print the date being sent to the backend.
      print(
        '--- ANALYTICS DEBUG: Sending client_date to backend: $dateStr ---',
      );

      // Use optimized analytics endpoint that calculates everything in single database queries
      // Use longer timeout for analytics as it involves complex calculations
      final queryParameters = {'user_id': userId, 'client_date': dateStr};
      if (walletId != null) {
        queryParameters['wallet_id'] = walletId;
      }
      final uri =
          Uri(
            path: '/analytics-optimized',
            queryParameters: queryParameters,
          ).toString();

      print('--- ANALYTICS DEBUG: Final URI: $uri ---');
      final response = await ApiClient.get(
        uri,
        timeout: const Duration(seconds: 30),
      );
      print('--- ANALYTICS DEBUG: Response status: ${response.statusCode} ---');
      print('--- ANALYTICS DEBUG: Response body: ${response.body} ---');
      ApiClient.handleResponse(response);

      final Map<String, dynamic> data = json.decode(response.body);
      print('--- ANALYTICS DEBUG: Parsed data keys: ${data.keys.toList()} ---');
      if (data['installment_details'] != null) {
        print(
          '--- ANALYTICS DEBUG: Installment details keys: ${data['installment_details'].keys.toList()} ---',
        );
        print(
          '--- ANALYTICS DEBUG: Total cash price value: ${data['installment_details']['total_cash_price']} ---',
        );
      }

      final analyticsData = AnalyticsData(
        keyMetrics: _parseKeyMetrics(data['key_metrics']),
        totalSales: _parseTotalSales(data['total_sales']),
        installmentStatus: _parseInstallmentStatus(data['installment_status']),
        installmentDetails: _parseInstallmentDetails(
          data['installment_details'],
        ),
        profitAnalytics: _parseProfitAnalytics(data['profit_analytics']),
      );

      // Cache the result for a short time to allow quick refresh when date changes
      _cache.set(cacheKey, analyticsData, duration: const Duration(seconds: 5));

      return analyticsData;
    } catch (e) {
      print('Error calculating analytics data: $e');
      print('Error type: ${e.runtimeType}');
      if (e is ApiException) {
        print('API Exception message: ${e.message}');
      }

      // Return default analytics data instead of throwing an error
      final defaultAnalytics = AnalyticsData(
        keyMetrics: KeyMetricsData(
          totalRevenue: 0.0,
          totalRevenueChange: null,
          totalRevenueChartData: [const FlSpot(0, 0)],
          newInstallments: 0,
          newInstallmentsChange: null,
          newInstallmentsChartData: [const FlSpot(0, 0)],
          collectionRate: 0.0,
          collectionRateChange: null,
          collectionRateChartData: [const FlSpot(0, 0)],
          portfolioGrowth: 0.0,
          portfolioGrowthChange: null,
          portfolioGrowthChartData: [const FlSpot(0, 0)],
        ),
        totalSales: TotalSalesData(
          weeklySales: [0, 0, 0, 0, 0, 0, 0],
          averageSales: 0.0,
          percentageChange: null,
        ),
        installmentStatus: InstallmentStatusData(
          overdueCount: 0,
          dueToPayCount: 0,
          upcomingCount: 0,
          paidCount: 0,
        ),
        installmentDetails: InstallmentDetailsData(
          activeInstallments: 0,
          totalPortfolio: 0.0,
          totalCashPrice: 0.0,
          totalOverdue: 0.0,
          averageInstallmentValue: 0.0,
          averageTerm: 0.0,
          totalInstallmentValue: 0.0,
          upcomingRevenue30Days: 0.0,
        ),
        profitAnalytics: _getDefaultProfitAnalytics(),
      );

      if (walletId == null) {
        // Cache the default data for all-wallet analytics only
        _cache.set(cacheKey, defaultAnalytics);
        return defaultAnalytics;
      } else {
        rethrow;
      }
    }
  }

  // These methods are no longer used - analytics now comes from optimized backend endpoint

  // Parse methods for optimized analytics response
  KeyMetricsData _parseKeyMetrics(Map<String, dynamic> data) {
    return KeyMetricsData(
      totalRevenue: (data['total_revenue'] ?? 0.0).toDouble(),
      totalRevenueChange: data['total_revenue_change']?.toDouble(),
      totalRevenueChartData: _parseChartData(data['total_revenue_chart_data']),
      newInstallments: data['new_installments'] ?? 0,
      newInstallmentsChange: data['new_installments_change']?.toDouble(),
      newInstallmentsChartData: _parseChartData(
        data['new_installments_chart_data'],
      ),
      collectionRate: (data['collection_rate'] ?? 0.0).toDouble(),
      collectionRateChange: data['collection_rate_change']?.toDouble(),
      collectionRateChartData: _parseChartData(
        data['collection_rate_chart_data'],
      ),
      portfolioGrowth: (data['portfolio_growth'] ?? 0.0).toDouble(),
      portfolioGrowthChange: data['portfolio_growth_change']?.toDouble(),
      portfolioGrowthChartData: _parseChartData(
        data['portfolio_growth_chart_data'],
      ),
    );
  }

  TotalSalesData _parseTotalSales(Map<String, dynamic> data) {
    final weeklySalesList = data['weekly_sales'] as List<dynamic>? ?? [];
    return TotalSalesData(
      weeklySales: weeklySalesList.map((e) => (e as num).toDouble()).toList(),
      averageSales: (data['average_sales'] ?? 0.0).toDouble(),
      percentageChange: data['percentage_change']?.toDouble(),
    );
  }

  InstallmentStatusData _parseInstallmentStatus(Map<String, dynamic> data) {
    return InstallmentStatusData(
      overdueCount: data['overdue_count'] ?? 0,
      dueToPayCount: data['due_to_pay_count'] ?? 0,
      upcomingCount: data['upcoming_count'] ?? 0,
      paidCount: data['paid_count'] ?? 0,
    );
  }

  InstallmentDetailsData _parseInstallmentDetails(Map<String, dynamic> data) {
    return InstallmentDetailsData(
      activeInstallments: data['active_installments'] ?? 0,
      totalPortfolio: (data['total_portfolio'] ?? 0.0).toDouble(),
      totalCashPrice: (data['total_cash_price'] ?? 0.0).toDouble(),
      totalOverdue: (data['total_overdue'] ?? 0.0).toDouble(),
      averageInstallmentValue:
          (data['average_installment_value'] ?? 0.0).toDouble(),
      averageTerm: (data['average_term'] ?? 0.0).toDouble(),
      totalInstallmentValue:
          (data['total_installment_value'] ?? 0.0).toDouble(),
      upcomingRevenue30Days:
          (data['upcoming_revenue_30_days'] ?? 0.0).toDouble(),
    );
  }

  ProfitAnalyticsData _parseProfitAnalytics(Map<String, dynamic>? data) {
    if (data == null) {
      return _getDefaultProfitAnalytics();
    }

    final upcoming = data['upcoming_payments'] as List<dynamic>? ?? [];
    final parsedUpcoming =
        upcoming.map((item) {
          final map = item as Map<String, dynamic>;
          final dueDateStr = map['due_date'] as String?;
          return PaymentProfitItem(
            installmentId: map['installment_id'] ?? '',
            clientName: map['client_name'],
            productName: map['product_name'],
            paymentNumber: map['payment_number'],
            dueDate: dueDateStr != null ? DateTime.tryParse(dueDateStr) : null,
            paymentAmount: (map['payment_amount'] ?? 0.0).toDouble(),
            profitAmount: (map['profit_amount'] ?? 0.0).toDouble(),
          );
        }).toList();

    return ProfitAnalyticsData(
      profitNext30Days: (data['profit_next_30_days'] ?? 0.0).toDouble(),
      profitNext90Days: (data['profit_next_90_days'] ?? 0.0).toDouble(),
      profitNext365Days: (data['profit_next_365_days'] ?? 0.0).toDouble(),
      profitEarnedToDate: (data['profit_earned_to_date'] ?? 0.0).toDouble(),
      profitOverdue: (data['profit_overdue'] ?? 0.0).toDouble(),
      totalRemainingProfit: (data['total_remaining_profit'] ?? 0.0).toDouble(),
      upcomingPayments: parsedUpcoming,
    );
  }

  List<FlSpot> _parseChartData(dynamic chartData) {
    if (chartData is List) {
      return chartData.asMap().entries.map((entry) {
        final index = entry.key;
        final value = entry.value;
        if (value is Map && value.containsKey('x') && value.containsKey('y')) {
          return FlSpot(
            (value['x'] as num).toDouble(),
            (value['y'] as num).toDouble(),
          );
        }
        return FlSpot(index.toDouble(), 0.0);
      }).toList();
    }
    return List.generate(28, (index) => FlSpot(index.toDouble(), 0.0));
  }

  // Default/empty data methods for error scenarios
  KeyMetricsData _getDefaultKeyMetrics() {
    return KeyMetricsData(
      totalRevenue: 0.0,
      totalRevenueChange: null,
      totalRevenueChartData: List.generate(
        28,
        (index) => FlSpot(index.toDouble(), 0.0),
      ),
      newInstallments: 0,
      newInstallmentsChange: null,
      newInstallmentsChartData: List.generate(
        28,
        (index) => FlSpot(index.toDouble(), 0.0),
      ),
      collectionRate: 0.0,
      collectionRateChange: null,
      collectionRateChartData: List.generate(
        28,
        (index) => FlSpot(index.toDouble(), 0.0),
      ),
      portfolioGrowth: 0.0,
      portfolioGrowthChange: null,
      portfolioGrowthChartData: List.generate(
        28,
        (index) => FlSpot(index.toDouble(), 0.0),
      ),
    );
  }

  TotalSalesData _getDefaultTotalSales() {
    return TotalSalesData(
      weeklySales: List.filled(7, 0.0),
      averageSales: 0.0,
      percentageChange: null,
    );
  }

  InstallmentStatusData _getDefaultInstallmentStatus() {
    return InstallmentStatusData(
      overdueCount: 0,
      dueToPayCount: 0,
      upcomingCount: 0,
      paidCount: 0,
    );
  }

  InstallmentDetailsData _getDefaultInstallmentDetails() {
    return InstallmentDetailsData(
      activeInstallments: 0,
      totalPortfolio: 0.0,
      totalCashPrice: 0.0,
      totalOverdue: 0.0,
      averageInstallmentValue: 0.0,
      averageTerm: 0.0,
      totalInstallmentValue: 0.0,
      upcomingRevenue30Days: 0.0,
    );
  }

  ProfitAnalyticsData _getDefaultProfitAnalytics() {
    return ProfitAnalyticsData(
      profitNext30Days: 0.0,
      profitNext90Days: 0.0,
      profitNext365Days: 0.0,
      profitEarnedToDate: 0.0,
      profitOverdue: 0.0,
      totalRemainingProfit: 0.0,
      upcomingPayments: const <PaymentProfitItem>[],
    );
  }
}
