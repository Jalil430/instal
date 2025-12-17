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

    final hasNewShape = data.containsKey('profit') || data.containsKey('revenue');
    if (hasNewShape) {
      final profitData = _parseProfitMetric(data['profit'] as Map<String, dynamic>?);
      final revenueData =
          _parseProfitMetric((data['revenue'] as Map<String, dynamic>?) ?? data['profit'] as Map<String, dynamic>?);
      final basisRaw = (data['default_basis'] as String?) ?? 'revenue';
      final basis =
          basisRaw.toLowerCase() == 'revenue' ? ProfitMetric.revenue : ProfitMetric.profit;
      return ProfitAnalyticsData(
        profit: profitData,
        revenue: revenueData,
        defaultMetric: basis,
      );
    }

    // Legacy single-series payload
    final legacyMetric = _parseProfitMetric(data);
    return ProfitAnalyticsData(
      profit: legacyMetric,
      revenue: legacyMetric,
      defaultMetric: ProfitMetric.revenue,
    );
  }

  ProfitMetricData _parseProfitMetric(Map<String, dynamic>? map) {
    if (map == null) return _getDefaultProfitMetric();

    final monthsRaw = map['months'] as List<dynamic>? ?? [];

    if (monthsRaw.isNotEmpty) {
      final months = monthsRaw.map((raw) {
        final item = raw as Map<String, dynamic>;
        final monthString = (item['month'] as String?) ?? '';
        final parsedMonth =
            monthString.isNotEmpty
                ? DateTime.tryParse(monthString) ?? DateTime.now()
                : DateTime.now();

        final expectedDailyRaw =
            item['expected_daily'] ??
            (item['expected'] is Map<String, dynamic>
                ? (item['expected'] as Map<String, dynamic>)['daily']
                : null) ??
            [];
        final receivedDailyRaw =
            item['received_daily'] ??
            (item['received'] is Map<String, dynamic>
                ? (item['received'] as Map<String, dynamic>)['daily']
                : null) ??
            [];

        final expectedDaily = (expectedDailyRaw as List<dynamic>? ?? []).map((
          value,
        ) {
          final obj = value as Map<String, dynamic>;
          return ExpectedProfitPoint(
            day: (obj['day'] ?? 1) as int,
            expectedAmount: (obj['expected_amount'] ?? 0.0).toDouble(),
            paidAmount: (obj['paid_amount'] ?? 0.0).toDouble(),
            isOverdue: obj['is_overdue'] == true,
          );
        }).toList();

        final receivedDaily = (receivedDailyRaw as List<dynamic>? ?? []).map((
          value,
        ) {
          if (value is num) {
            return ReceivedProfitPoint(
              day: 1,
              amount: (value).toDouble(),
            );
          }
          final obj = value as Map<String, dynamic>;
          return ReceivedProfitPoint(
            day: (obj['day'] ?? 1) as int,
            amount: (obj['amount'] ?? obj['paid_amount'] ?? 0.0).toDouble(),
          );
        }).toList();

        return MonthlyProfitData(
          month: parsedMonth,
          expectedDaily: expectedDaily,
          receivedDaily: receivedDaily,
          overdueAmount: (item['overdue_amount'] ?? 0.0).toDouble(),
          outsideMonthPaid: (item['outside_month_paid'] ?? 0.0).toDouble(),
        );
      }).toList();

      return ProfitMetricData(
        months: months,
        totalOverdue: (map['total_overdue'] ?? 0.0).toDouble(),
      );
    }

    if (map.containsKey('months')) {
      return ProfitMetricData(
        months: const [],
        totalOverdue: (map['total_overdue'] ?? 0.0).toDouble(),
      );
    }

    return _buildLegacyProfitMetric(map);
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
    final defaultMetric = _getDefaultProfitMetric();
    return ProfitAnalyticsData(
      profit: defaultMetric,
      revenue: defaultMetric,
      defaultMetric: ProfitMetric.revenue,
    );
  }

  ProfitMetricData _getDefaultProfitMetric() {
    return const ProfitMetricData(
      months: [],
      totalOverdue: 0.0,
    );
  }

  ProfitMetricData _buildLegacyProfitMetric(Map<String, dynamic> data) {
    final overdue = (data['profit_overdue'] ?? 0.0).toDouble();
    final upcoming = data['upcoming_payments'] as List<dynamic>? ?? [];
    final now = DateTime.now();
    final monthStart = DateTime(now.year, now.month, 1);
    final expectedMap = <int, ExpectedProfitPoint>{};

    for (final item in upcoming) {
      final map = item as Map<String, dynamic>;
      final dueDateStr = map['due_date'] as String?;
      if (dueDateStr == null) continue;
      final dueDate = DateTime.tryParse(dueDateStr);
      if (dueDate == null) continue;
      if (dueDate.year != monthStart.year || dueDate.month != monthStart.month) {
        continue;
      }
      final profitAmount = (map['profit_amount'] ?? 0.0).toDouble();
      if (profitAmount <= 0) continue;
      final day = dueDate.day;
      expectedMap[day] = ExpectedProfitPoint(
        day: day,
        expectedAmount: profitAmount,
        paidAmount: 0.0,
        isOverdue: dueDate.isBefore(now),
      );
    }

    final monthData = MonthlyProfitData(
      month: monthStart,
      expectedDaily: expectedMap.values.toList(),
      receivedDaily: const [],
      overdueAmount: overdue,
      outsideMonthPaid: 0.0,
    );

    return ProfitMetricData(
      months: [monthData],
      totalOverdue: overdue,
    );
  }
}
