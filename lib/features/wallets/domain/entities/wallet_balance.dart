class WalletBalance {
  final String walletId;
  final String userId;
  final int balanceMinorUnits; // kopecks
  final int version; // optimistic concurrency
  final DateTime updatedAt;
  // Aggregates (kopecks)
  final int totalAllocatedMinorUnits; // sum of remaining across linked installments
  final int dueToGetMinorUnits; // sum unpaid (expected - paid)
  final int expectedRevenueMinorUnits; // sum(profit) or investor share per backend
  final int paidAmountMinorUnits; // accumulated actual paid from installments

  const WalletBalance({
    required this.walletId,
    required this.userId,
    required this.balanceMinorUnits,
    required this.version,
    required this.updatedAt,
    this.totalAllocatedMinorUnits = 0,
    this.dueToGetMinorUnits = 0,
    this.expectedRevenueMinorUnits = 0,
    this.paidAmountMinorUnits = 0,
  });

  double get balance => balanceMinorUnits / 100.0; // Convert to rubles
  double get totalAllocated => totalAllocatedMinorUnits / 100.0;
  double get dueToGet => dueToGetMinorUnits / 100.0;
  double get expectedRevenue => expectedRevenueMinorUnits / 100.0;
  double get paidAmount => paidAmountMinorUnits / 100.0;

  WalletBalance copyWith({
    String? walletId,
    String? userId,
    int? balanceMinorUnits,
    int? version,
    DateTime? updatedAt,
    int? totalAllocatedMinorUnits,
    int? dueToGetMinorUnits,
    int? expectedRevenueMinorUnits,
    int? paidAmountMinorUnits,
  }) {
    return WalletBalance(
      walletId: walletId ?? this.walletId,
      userId: userId ?? this.userId,
      balanceMinorUnits: balanceMinorUnits ?? this.balanceMinorUnits,
      version: version ?? this.version,
      updatedAt: updatedAt ?? this.updatedAt,
      totalAllocatedMinorUnits: totalAllocatedMinorUnits ?? this.totalAllocatedMinorUnits,
      dueToGetMinorUnits: dueToGetMinorUnits ?? this.dueToGetMinorUnits,
      expectedRevenueMinorUnits: expectedRevenueMinorUnits ?? this.expectedRevenueMinorUnits,
      paidAmountMinorUnits: paidAmountMinorUnits ?? this.paidAmountMinorUnits,
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is WalletBalance && other.walletId == walletId && other.version == version;
  }

  @override
  int get hashCode => walletId.hashCode ^ version.hashCode;

  @override
  String toString() {
    return 'WalletBalance(walletId: $walletId, balance: ${balance.toStringAsFixed(2)} RUB, version: $version)';
  }
}
