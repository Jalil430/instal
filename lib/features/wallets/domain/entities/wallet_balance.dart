class WalletBalance {
  final String walletId;
  final String userId;
  final int balanceMinorUnits; // Balance in kopecks (RUB) or smallest currency unit
  final int version; // For optimistic concurrency control
  final DateTime updatedAt;

  const WalletBalance({
    required this.walletId,
    required this.userId,
    required this.balanceMinorUnits,
    required this.version,
    required this.updatedAt,
  });

  double get balance => balanceMinorUnits / 100.0; // Convert to rubles

  WalletBalance copyWith({
    String? walletId,
    String? userId,
    int? balanceMinorUnits,
    int? version,
    DateTime? updatedAt,
  }) {
    return WalletBalance(
      walletId: walletId ?? this.walletId,
      userId: userId ?? this.userId,
      balanceMinorUnits: balanceMinorUnits ?? this.balanceMinorUnits,
      version: version ?? this.version,
      updatedAt: updatedAt ?? this.updatedAt,
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
