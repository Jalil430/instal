import 'package:fl_chart/fl_chart.dart';
import 'package:instal_app/features/analytics/domain/entities/analytics_data.dart';
import 'package:instal_app/features/installments/domain/entities/installment.dart';
import 'package:instal_app/features/installments/domain/entities/installment_payment.dart';
import 'package:instal_app/features/installments/domain/repositories/installment_repository.dart';
import '../../../../core/api/cache_service.dart';

class AnalyticsRepository {
  final InstallmentRepository _installmentRepository;
  final CacheService _cache = CacheService();

  AnalyticsRepository(this._installmentRepository);

  Future<AnalyticsData> getAnalyticsData(String userId) async {
    // Check cache first
    final cacheKey = CacheService.analyticsKey(userId);
    final cachedAnalytics = _cache.get<AnalyticsData>(cacheKey);
    if (cachedAnalytics != null) {
      return cachedAnalytics;
    }

    // Load installments and all payments in parallel for better performance
    final installmentsFuture = _installmentRepository.getAllInstallments(userId);
    
    // Instead of using getAllPayments (which is inefficient), 
    // we'll collect payments from installments in parallel
    final installments = await installmentsFuture;
    
    // Get all payments for all installments in parallel
    final paymentsFutures = installments.map((installment) async {
      try {
        return await _installmentRepository.getPaymentsByInstallmentId(installment.id);
      } catch (e) {
        // If individual installment fails, return empty list to avoid breaking the entire analytics
        return <InstallmentPayment>[];
      }
    });
    
    final allPaymentsLists = await Future.wait(paymentsFutures);
    final payments = allPaymentsLists.expand((list) => list).toList();

    final analyticsData = AnalyticsData(
      keyMetrics: _calculateKeyMetrics(installments, payments),
      totalSales: _calculateTotalSales(payments),
      installmentStatus: _calculateInstallmentStatus(installments, payments),
      installmentDetails: _calculateInstallmentDetails(installments, payments),
    );

    // Cache the result for 1 minute (analytics change frequently)
    _cache.set(cacheKey, analyticsData, duration: const Duration(minutes: 1));

    return analyticsData;
  }

  KeyMetricsData _calculateKeyMetrics(List<Installment> installments, List<InstallmentPayment> payments) {
    final now = DateTime.now();
    final last28DaysStart = now.subtract(const Duration(days: 28));
    final previous28DaysStart = now.subtract(const Duration(days: 56));

    // Revenue
    final currentRevenue = payments
        .where((p) => p.isPaid && p.paidDate!.isAfter(last28DaysStart))
        .fold<double>(0, (sum, p) => sum + p.expectedAmount);
    final previousRevenue = payments
        .where((p) => p.isPaid && p.paidDate!.isAfter(previous28DaysStart) && p.paidDate!.isBefore(last28DaysStart))
        .fold<double>(0, (sum, p) => sum + p.expectedAmount);
    final revenueChange = previousRevenue == 0 ? null : ((currentRevenue - previousRevenue) / previousRevenue) * 100;

    // New Installments
    final currentNewInstallments = installments.where((i) => i.createdAt.isAfter(last28DaysStart)).length;
    final previousNewInstallments = installments.where((i) => i.createdAt.isAfter(previous28DaysStart) && i.createdAt.isBefore(last28DaysStart)).length;
    final newInstallmentsChange = previousNewInstallments == 0 ? null : ((currentNewInstallments - previousNewInstallments) / previousNewInstallments.toDouble()) * 100;

    // Collection Rate - percentage of due payments that were collected
    final currentDuePayments = payments.where((p) => p.dueDate.isAfter(last28DaysStart) && p.dueDate.isBefore(now)).toList();
    final currentCollectedFromDue = currentDuePayments.where((p) => p.isPaid).fold<double>(0, (sum, p) => sum + p.expectedAmount);
    final currentTotalDue = currentDuePayments.fold<double>(0, (sum, p) => sum + p.expectedAmount);
    final currentCollectionRate = currentTotalDue > 0 ? (currentCollectedFromDue / currentTotalDue) * 100 : 0.0;
    
    final previousDuePayments = payments.where((p) => p.dueDate.isAfter(previous28DaysStart) && p.dueDate.isBefore(last28DaysStart)).toList();
    final previousCollectedFromDue = previousDuePayments.where((p) => p.isPaid).fold<double>(0, (sum, p) => sum + p.expectedAmount);
    final previousTotalDue = previousDuePayments.fold<double>(0, (sum, p) => sum + p.expectedAmount);
    final previousCollectionRate = previousTotalDue > 0 ? (previousCollectedFromDue / previousTotalDue) * 100 : 0.0;
    final collectionRateChange = previousCollectionRate > 0 ? ((currentCollectionRate - previousCollectionRate) / previousCollectionRate) * 100 : null;

    // Portfolio Growth - new business value minus collections in the period
    final currentNewBusinessValue = installments
        .where((i) => i.createdAt.isAfter(last28DaysStart))
        .fold<double>(0, (sum, i) => sum + i.installmentPrice);
    final currentPortfolioGrowth = currentNewBusinessValue - currentRevenue;
    
    final previousNewBusinessValue = installments
        .where((i) => i.createdAt.isAfter(previous28DaysStart) && i.createdAt.isBefore(last28DaysStart))
        .fold<double>(0, (sum, i) => sum + i.installmentPrice);
    final previousPortfolioGrowth = previousNewBusinessValue - previousRevenue;
    final portfolioGrowthChange = previousPortfolioGrowth != 0 ? ((currentPortfolioGrowth - previousPortfolioGrowth) / previousPortfolioGrowth.abs()) * 100 : null;

    return KeyMetricsData(
      totalRevenue: currentRevenue,
      totalRevenueChange: revenueChange,
      totalRevenueChartData: _generateChartData(payments.where((p) => p.isPaid).map((p) => MapEntry(p.paidDate!, p.expectedAmount)).toList()),
      newInstallments: currentNewInstallments,
      newInstallmentsChange: newInstallmentsChange,
      newInstallmentsChartData: _generateChartData(installments.map((i) => MapEntry(i.createdAt, 1.0)).toList()),
      collectionRate: currentCollectionRate,
      collectionRateChange: collectionRateChange,
      collectionRateChartData: _generateCollectionRateChartData(payments),
      portfolioGrowth: currentPortfolioGrowth,
      portfolioGrowthChange: portfolioGrowthChange,
      portfolioGrowthChartData: _generatePortfolioGrowthChartData(installments, payments),
    );
  }

  List<FlSpot> _generateChartData(List<MapEntry<DateTime?, double>> entries) {
    if (entries.isEmpty) {
      return [];
    }
    final now = DateTime.now();
    final last28DaysStart = now.subtract(const Duration(days: 28));
    final dailyData = List.filled(28, 0.0);

    for (final entry in entries) {
      if (entry.key != null && entry.key!.isAfter(last28DaysStart)) {
        final dayIndex = 27 - now.difference(entry.key!).inDays;
        if (dayIndex >= 0 && dayIndex < 28) {
          dailyData[dayIndex] += entry.value;
        }
      }
    }
    
    final maxValue = dailyData.fold<double>(0.0, (max, val) => val > max ? val : max);
    
    return List.generate(28, (index) {
      final value = dailyData[index];
      // Normalize to a 0-10 scale for the chart
      final normalizedValue = maxValue == 0 ? 0.0 : (value / maxValue) * 10;
      return FlSpot(index.toDouble(), normalizedValue);
    });
  }

  List<FlSpot> _generateCollectionRateChartData(List<InstallmentPayment> payments) {
    final now = DateTime.now();
    final last28DaysStart = now.subtract(const Duration(days: 28));
    
    return List.generate(28, (index) {
      final dayDate = last28DaysStart.add(Duration(days: index));
      final nextDay = dayDate.add(const Duration(days: 1));
      
      // Get payments due on this specific day
      final dueOnDay = payments.where((p) => 
        p.dueDate.isAfter(dayDate.subtract(const Duration(days: 1))) && 
        p.dueDate.isBefore(nextDay)
      ).toList();
      
      if (dueOnDay.isEmpty) {
        return FlSpot(index.toDouble(), 0.0); // No payments due = 0 on chart
      }
      
      final totalDue = dueOnDay.fold<double>(0, (sum, p) => sum + p.expectedAmount);
      final collected = dueOnDay.where((p) => p.isPaid).fold<double>(0, (sum, p) => sum + p.expectedAmount);
      final collectionRate = totalDue > 0 ? (collected / totalDue) * 100 : 0.0;
      
      // Normalize to 0-10 scale (collection rate is already 0-100%)
      final normalizedValue = collectionRate / 10; // 100% = 10, 50% = 5, etc.
      return FlSpot(index.toDouble(), normalizedValue.clamp(0.0, 10.0));
    });
  }

  List<FlSpot> _generatePortfolioGrowthChartData(List<Installment> installments, List<InstallmentPayment> payments) {
    final now = DateTime.now();
    final last28DaysStart = now.subtract(const Duration(days: 28));
    final dailyGrowth = List.filled(28, 0.0);

    // Add new business value for each day
    for (final installment in installments) {
      if (installment.createdAt.isAfter(last28DaysStart)) {
        final dayIndex = 27 - now.difference(installment.createdAt).inDays;
        if (dayIndex >= 0 && dayIndex < 28) {
          dailyGrowth[dayIndex] += installment.installmentPrice;
        }
      }
    }

    // Subtract collections for each day
    for (final payment in payments) {
      if (payment.isPaid && payment.paidDate != null && payment.paidDate!.isAfter(last28DaysStart)) {
        final dayIndex = 27 - now.difference(payment.paidDate!).inDays;
        if (dayIndex >= 0 && dayIndex < 28) {
          dailyGrowth[dayIndex] -= payment.expectedAmount;
        }
      }
    }

    // Find the maximum absolute value for normalization (same as other charts)
    final maxAbsValue = dailyGrowth.fold<double>(0.0, (max, val) => val.abs() > max ? val.abs() : max);

    return List.generate(28, (index) {
      final value = dailyGrowth[index];
      if (maxAbsValue == 0) return FlSpot(index.toDouble(), 0.0);
      
      // Normalize to 0-10 scale like other charts, using absolute value
      final normalizedValue = (value.abs() / maxAbsValue) * 10;
      return FlSpot(index.toDouble(), normalizedValue.clamp(0.0, 10.0));
    });
  }

  TotalSalesData _calculateTotalSales(List<InstallmentPayment> payments) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final startOfWeek = today.subtract(Duration(days: today.weekday - 1));

    List<double> weeklySales = List.filled(7, 0.0);
    List<double> lastWeekSales = List.filled(7, 0.0);

    final paidPayments = payments.where((p) => p.isPaid && p.paidDate != null);

    for (final p in paidPayments) {
      final paidDate = DateTime(p.paidDate!.year, p.paidDate!.month, p.paidDate!.day);
      
      // Bucket into current week (Mon-Sun)
      if (paidDate.isAfter(startOfWeek.subtract(const Duration(days: 1))) && paidDate.isBefore(startOfWeek.add(const Duration(days: 7)))) {
         weeklySales[paidDate.weekday - 1] += p.expectedAmount;
      } 
      // Bucket into previous week
      else if (paidDate.isAfter(startOfWeek.subtract(const Duration(days: 8))) && paidDate.isBefore(startOfWeek)) {
        lastWeekSales[paidDate.weekday - 1] += p.expectedAmount;
      }
    }

    final currentWeekTotal = weeklySales.reduce((a, b) => a + b);
    final averageSales = currentWeekTotal / 7;

    final lastWeekTotal = lastWeekSales.reduce((a, b) => a + b);
    final lastWeekAverage = lastWeekTotal / 7;

    final percentageChange = lastWeekAverage > 0
        ? ((averageSales - lastWeekAverage) / lastWeekAverage) * 100
        : null;

    return TotalSalesData(
      weeklySales: weeklySales,
      averageSales: averageSales,
      percentageChange: percentageChange,
    );
  }

  InstallmentStatusData _calculateInstallmentStatus(List<Installment> installments, List<InstallmentPayment> allPayments) {
    int overdueCount = 0;
    int dueToPayCount = 0;
    int upcomingCount = 0;
    int paidCount = 0;

    for (final installment in installments) {
      final installmentPayments = allPayments.where((p) => p.installmentId == installment.id).toList();
      if (installmentPayments.isEmpty) continue;

      final isOverdue = installmentPayments.any((p) => p.isOverdue);
      final allPaid = installmentPayments.every((p) => p.isPaid);
      final isDue = installmentPayments.any((p) => p.isDue);

      if (isOverdue) {
        overdueCount++;
      } else if (allPaid) {
        paidCount++;
      } else if (isDue) {
        dueToPayCount++;
      } else {
        // If not overdue, not all paid, and not due, it must be upcoming
        upcomingCount++;
      }
    }

    return InstallmentStatusData(
      overdueCount: overdueCount,
      dueToPayCount: dueToPayCount,
      upcomingCount: upcomingCount,
      paidCount: paidCount,
    );
  }

  InstallmentDetailsData _calculateInstallmentDetails(List<Installment> installments, List<InstallmentPayment> payments) {
    final activeInstallments = installments
        .where((i) => payments.any((p) => p.installmentId == i.id && !p.isPaid))
        .length;

    // Total portfolio - all unpaid payments
    final totalPortfolio = payments.where((p) => !p.isPaid).fold<double>(0, (sum, p) => sum + p.expectedAmount);

    // Total overdue - all overdue payments
    final totalOverdue = payments.where((p) => p.isOverdue).fold<double>(0, (sum, p) => sum + p.expectedAmount);

    final averageInstallmentValue = installments.isEmpty
        ? 0.0
        : installments.fold<double>(0, (sum, i) => sum + i.installmentPrice) / installments.length;
        
    final averageTerm = installments.isEmpty
        ? 0.0
        : installments.fold<double>(0, (sum, i) => sum + i.termMonths) / installments.length;

    // Total installment value - sum of all installment prices (total business volume)
    final totalInstallmentValue = installments.fold<double>(0, (sum, i) => sum + i.installmentPrice);
        
    final upcomingRevenue30Days = payments
        .where((p) => !p.isPaid && p.dueDate.isAfter(DateTime.now()) && p.dueDate.isBefore(DateTime.now().add(const Duration(days: 30))))
        .fold<double>(0, (sum, p) => sum + p.expectedAmount);

    return InstallmentDetailsData(
      activeInstallments: activeInstallments,
      totalPortfolio: totalPortfolio,
      totalOverdue: totalOverdue,
      averageInstallmentValue: averageInstallmentValue.toDouble(),
      averageTerm: averageTerm.toDouble(),
      totalInstallmentValue: totalInstallmentValue,
      upcomingRevenue30Days: upcomingRevenue30Days,
    );
  }
} 