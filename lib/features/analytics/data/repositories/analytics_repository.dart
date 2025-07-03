import 'package:fl_chart/fl_chart.dart';
import 'package:instal_app/features/analytics/domain/entities/analytics_data.dart';
import 'package:instal_app/features/installments/domain/entities/installment.dart';
import 'package:instal_app/features/installments/domain/entities/installment_payment.dart';
import 'package:instal_app/features/installments/domain/repositories/installment_repository.dart';

class AnalyticsRepository {
  final InstallmentRepository _installmentRepository;

  AnalyticsRepository(this._installmentRepository);

  Future<AnalyticsData> getAnalyticsData(String userId) async {
    final installments = await _installmentRepository.getAllInstallments(userId);
    final payments = await _installmentRepository.getAllPayments(userId);

    return AnalyticsData(
      keyMetrics: _calculateKeyMetrics(installments, payments),
      totalSales: _calculateTotalSales(payments),
      installmentStatus: _calculateInstallmentStatus(installments, payments),
      installmentDetails: _calculateInstallmentDetails(installments, payments),
    );
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

    // Snapshot metrics (approximated for change)
    final outstandingPortfolio = payments.where((p) => !p.isPaid).fold<double>(0, (sum, p) => sum + p.expectedAmount);
    final overdueDebt = payments.where((p) => p.isOverdue).fold<double>(0, (sum, p) => sum + p.expectedAmount);

    final paidInLast28Days = payments.where((p) => p.isPaid && p.paidDate!.isAfter(last28DaysStart)).fold<double>(0, (sum, p) => sum + p.expectedAmount);
    final newInstallmentValueInLast28Days = installments.where((i) => i.createdAt.isAfter(last28DaysStart)).fold<double>(0, (sum, i) => sum + i.installmentPrice);
    
    final outstandingPortfolio28DaysAgo = outstandingPortfolio + paidInLast28Days - newInstallmentValueInLast28Days;
    final portfolioChange = outstandingPortfolio28DaysAgo == 0 ? null : ((outstandingPortfolio - outstandingPortfolio28DaysAgo) / outstandingPortfolio28DaysAgo) * 100;
    
    // For overdue debt, the approximation is more complex. Let's simplify and show the change in new overdue debt.
    final newOverdueLast28 = payments.where((p) => !p.isPaid && p.dueDate.isAfter(last28DaysStart)).fold<double>(0, (sum, p) => sum + p.expectedAmount);
    final newOverduePrevious28 = payments.where((p) => !p.isPaid && p.dueDate.isAfter(previous28DaysStart) && p.dueDate.isBefore(last28DaysStart)).fold<double>(0, (sum, p) => sum + p.expectedAmount);
    final overdueDebtChange = newOverduePrevious28 == 0 ? null : ((newOverdueLast28 - newOverduePrevious28) / newOverduePrevious28) * 100;


    return KeyMetricsData(
      totalRevenue: currentRevenue,
      totalRevenueChange: revenueChange,
      totalRevenueChartData: _generateChartData(payments.where((p) => p.isPaid).map((p) => MapEntry(p.paidDate!, p.expectedAmount)).toList()),
      newInstallments: currentNewInstallments,
      newInstallmentsChange: newInstallmentsChange,
      newInstallmentsChartData: _generateChartData(installments.map((i) => MapEntry(i.createdAt, 1.0)).toList()),
      outstandingPortfolio: outstandingPortfolio,
      outstandingPortfolioChange: portfolioChange,
      outstandingPortfolioChartData: _generateChartData(installments.map((i) => MapEntry(i.createdAt, i.installmentPrice)).toList()),
      overdueDebt: overdueDebt,
      overdueDebtChange: overdueDebtChange,
      overdueDebtChartData: _generateChartData(payments.where((p) => p.isOverdue).map((p) => MapEntry(p.dueDate, p.expectedAmount)).toList()),
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

    final overdueInstallments = installments
        .where((i) => payments.any((p) => p.installmentId == i.id && p.isOverdue))
        .length;

    final averageInstallmentValue = installments.isEmpty
        ? 0.0
        : installments.fold<double>(0, (sum, i) => sum + i.installmentPrice) / installments.length;
        
    final averageTerm = installments.isEmpty
        ? 0.0
        : installments.fold<double>(0, (sum, i) => sum + i.termMonths) / installments.length;

    final productCounts = <String, int>{};
    for (final i in installments) {
      productCounts[i.productName] = (productCounts[i.productName] ?? 0) + 1;
    }
    final topProduct = productCounts.isEmpty
        ? ''
        : productCounts.entries.reduce((a, b) => a.value > b.value ? a : b).key;
        
    final upcomingRevenue30Days = payments
        .where((p) => !p.isPaid && p.dueDate.isAfter(DateTime.now()) && p.dueDate.isBefore(DateTime.now().add(const Duration(days: 30))))
        .fold<double>(0, (sum, p) => sum + p.expectedAmount);

    return InstallmentDetailsData(
      activeInstallments: activeInstallments,
      overdueInstallments: overdueInstallments,
      averageInstallmentValue: averageInstallmentValue.toDouble(),
      averageTerm: averageTerm.toDouble(),
      topProduct: topProduct,
      upcomingRevenue30Days: upcomingRevenue30Days,
    );
  }
} 