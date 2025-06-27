import 'package:fl_chart/fl_chart.dart';

class AnalyticsData {
  final KeyMetricsData keyMetrics;
  final TotalSalesData totalSales;
  final InstallmentStatusData installmentStatus;
  final InstallmentDetailsData installmentDetails;

  AnalyticsData({
    required this.keyMetrics,
    required this.totalSales,
    required this.installmentStatus,
    required this.installmentDetails,
  });
}

class KeyMetricsData {
  final double totalRevenue;
  final double? totalRevenueChange;
  final List<FlSpot> totalRevenueChartData;
  final int newInstallments;
  final double? newInstallmentsChange;
  final List<FlSpot> newInstallmentsChartData;
  final double outstandingPortfolio;
  final double? outstandingPortfolioChange;
  final List<FlSpot> outstandingPortfolioChartData;
  final double overdueDebt;
  final double? overdueDebtChange;
  final List<FlSpot> overdueDebtChartData;

  KeyMetricsData({
    required this.totalRevenue,
    this.totalRevenueChange,
    required this.totalRevenueChartData,
    required this.newInstallments,
    this.newInstallmentsChange,
    required this.newInstallmentsChartData,
    required this.outstandingPortfolio,
    this.outstandingPortfolioChange,
    required this.outstandingPortfolioChartData,
    required this.overdueDebt,
    this.overdueDebtChange,
    required this.overdueDebtChartData,
  });
}

class TotalSalesData {
  final List<double> weeklySales;
  final double averageSales;
  final double? percentageChange;

  TotalSalesData({
    required this.weeklySales,
    required this.averageSales,
    required this.percentageChange,
  });
}

class InstallmentStatusData {
  final int overdueCount;
  final int dueToPayCount;
  final int upcomingCount;
  final int paidCount;

  InstallmentStatusData({
    required this.overdueCount,
    required this.dueToPayCount,
    required this.upcomingCount,
    required this.paidCount,
  });
}

class InstallmentDetailsData {
  final int activeInstallments;
  final int overdueInstallments;
  final double averageInstallmentValue;
  final double averageTerm;
  final String topProduct;
  final double upcomingRevenue30Days;

  InstallmentDetailsData({
    required this.activeInstallments,
    required this.overdueInstallments,
    required this.averageInstallmentValue,
    required this.averageTerm,
    required this.topProduct,
    required this.upcomingRevenue30Days,
  });
} 