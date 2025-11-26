import 'package:fl_chart/fl_chart.dart';

class AnalyticsData {
  final KeyMetricsData keyMetrics;
  final TotalSalesData totalSales;
  final InstallmentStatusData installmentStatus;
  final InstallmentDetailsData installmentDetails;
  final ProfitAnalyticsData profitAnalytics;

  AnalyticsData({
    required this.keyMetrics,
    required this.totalSales,
    required this.installmentStatus,
    required this.installmentDetails,
    required this.profitAnalytics,
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
  final double totalCashPrice;
  final double totalOverdue;
  final double averageInstallmentValue;
  final double averageTerm;
  final double totalInstallmentValue;
  final double upcomingRevenue30Days;

  InstallmentDetailsData({
    required this.activeInstallments,
    required this.totalPortfolio,
    required this.totalCashPrice,
    required this.totalOverdue,
    required this.averageInstallmentValue,
    required this.averageTerm,
    required this.totalInstallmentValue,
    required this.upcomingRevenue30Days,
  });
}

class ProfitAnalyticsData {
  final double profitNext30Days;
  final double profitNext90Days;
  final double profitNext365Days;
  final double profitEarnedToDate;
  final double profitOverdue;
  final double totalRemainingProfit;
  final List<PaymentProfitItem> upcomingPayments;

  ProfitAnalyticsData({
    required this.profitNext30Days,
    required this.profitNext90Days,
    required this.profitNext365Days,
    required this.profitEarnedToDate,
    required this.profitOverdue,
    required this.totalRemainingProfit,
    required this.upcomingPayments,
  });
}

class PaymentProfitItem {
  final String installmentId;
  final String? clientName;
  final String? productName;
  final int? paymentNumber;
  final DateTime? dueDate;
  final double paymentAmount;
  final double profitAmount;

  PaymentProfitItem({
    required this.installmentId,
    this.clientName,
    this.productName,
    this.paymentNumber,
    this.dueDate,
    required this.paymentAmount,
    required this.profitAmount,
  });
}
