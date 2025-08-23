class InvestmentSummary {
  final String walletId;
  final int totalInvestedMinorUnits;
  final int currentBalanceMinorUnits;
  final int totalAllocatedMinorUnits;
  final int expectedReturnsMinorUnits;
  final int dueAmountMinorUnits;
  final DateTime? returnDueDate;
  final double profitPercentage;

  const InvestmentSummary({
    required this.walletId,
    required this.totalInvestedMinorUnits,
    required this.currentBalanceMinorUnits,
    required this.totalAllocatedMinorUnits,
    required this.expectedReturnsMinorUnits,
    required this.dueAmountMinorUnits,
    this.returnDueDate,
    required this.profitPercentage,
  });

  double get totalInvested => totalInvestedMinorUnits / 100.0;
  double get currentBalance => currentBalanceMinorUnits / 100.0;
  double get totalAllocated => totalAllocatedMinorUnits / 100.0;
  double get expectedReturns => expectedReturnsMinorUnits / 100.0;
  double get dueAmount => dueAmountMinorUnits / 100.0;

  double get totalWalletValue => currentBalance + totalAllocated;
  double get totalProfit => totalWalletValue - totalInvested;
  double get investorProfitShare => totalProfit > 0 ? (totalProfit * profitPercentage / 100) : 0;

  @override
  String toString() {
    return 'InvestmentSummary(walletId: $walletId, invested: ${totalInvested.toStringAsFixed(2)}, current: ${currentBalance.toStringAsFixed(2)}, profit: ${totalProfit.toStringAsFixed(2)})';
  }
}
