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
  final double collectionRate;
  final double? collectionRateChange;
  final List<FlSpot> collectionRateChartData;
  final double portfolioGrowth;
  final double? portfolioGrowthChange;
  final List<FlSpot> portfolioGrowthChartData;

  KeyMetricsData({
    required this.totalRevenue,
    this.totalRevenueChange,
    required this.totalRevenueChartData,
    required this.newInstallments,
    this.newInstallmentsChange,
    required this.newInstallmentsChartData,
    required this.collectionRate,
    this.collectionRateChange,
    required this.collectionRateChartData,
    required this.portfolioGrowth,
    this.portfolioGrowthChange,
    required this.portfolioGrowthChartData,
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
  final double totalPortfolio;
  final double totalOverdue;
  final double averageInstallmentValue;
  final double averageTerm;
  final double totalInstallmentValue;
  final double upcomingRevenue30Days;

  InstallmentDetailsData({
    required this.activeInstallments,
    required this.totalPortfolio,
    required this.totalOverdue,
    required this.averageInstallmentValue,
    required this.averageTerm,
    required this.totalInstallmentValue,
    required this.upcomingRevenue30Days,
  });
} 