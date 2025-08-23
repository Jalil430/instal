import '../../domain/entities/investment_summary.dart';

class InvestmentSummaryModel {
  final String walletId;
  final int totalInvestedMinorUnits;
  final int currentBalanceMinorUnits;
  final int totalAllocatedMinorUnits;
  final int expectedReturnsMinorUnits;
  final int dueAmountMinorUnits;
  final DateTime? returnDueDate;
  final double profitPercentage;

  const InvestmentSummaryModel({
    required this.walletId,
    required this.totalInvestedMinorUnits,
    required this.currentBalanceMinorUnits,
    required this.totalAllocatedMinorUnits,
    required this.expectedReturnsMinorUnits,
    required this.dueAmountMinorUnits,
    this.returnDueDate,
    required this.profitPercentage,
  });

  factory InvestmentSummaryModel.fromJson(Map<String, dynamic> json) {
    return InvestmentSummaryModel(
      walletId: json['wallet_id'] as String,
      totalInvestedMinorUnits: (json['total_invested_minor_units'] as num).toInt(),
      currentBalanceMinorUnits: (json['current_balance_minor_units'] as num).toInt(),
      totalAllocatedMinorUnits: (json['total_allocated_minor_units'] as num).toInt(),
      expectedReturnsMinorUnits: (json['expected_returns_minor_units'] as num).toInt(),
      dueAmountMinorUnits: (json['due_amount_minor_units'] as num).toInt(),
      returnDueDate: json['return_due_date'] != null ? DateTime.parse(json['return_due_date'] as String) : null,
      profitPercentage: (json['profit_percentage'] as num).toDouble(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'wallet_id': walletId,
      'total_invested_minor_units': totalInvestedMinorUnits,
      'current_balance_minor_units': currentBalanceMinorUnits,
      'total_allocated_minor_units': totalAllocatedMinorUnits,
      'expected_returns_minor_units': expectedReturnsMinorUnits,
      'due_amount_minor_units': dueAmountMinorUnits,
      'return_due_date': returnDueDate?.toIso8601String(),
      'profit_percentage': profitPercentage,
    };
  }

  InvestmentSummary toEntity() {
    return InvestmentSummary(
      walletId: walletId,
      totalInvestedMinorUnits: totalInvestedMinorUnits,
      currentBalanceMinorUnits: currentBalanceMinorUnits,
      totalAllocatedMinorUnits: totalAllocatedMinorUnits,
      expectedReturnsMinorUnits: expectedReturnsMinorUnits,
      dueAmountMinorUnits: dueAmountMinorUnits,
      returnDueDate: returnDueDate,
      profitPercentage: profitPercentage,
    );
  }

  static InvestmentSummaryModel fromEntity(InvestmentSummary summary) {
    return InvestmentSummaryModel(
      walletId: summary.walletId,
      totalInvestedMinorUnits: summary.totalInvestedMinorUnits,
      currentBalanceMinorUnits: summary.currentBalanceMinorUnits,
      totalAllocatedMinorUnits: summary.totalAllocatedMinorUnits,
      expectedReturnsMinorUnits: summary.expectedReturnsMinorUnits,
      dueAmountMinorUnits: summary.dueAmountMinorUnits,
      returnDueDate: summary.returnDueDate,
      profitPercentage: summary.profitPercentage,
    );
  }
}
