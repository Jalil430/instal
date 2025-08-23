class Wallet {
  final String id;
  final String userId;
  final String name;
  final WalletType type;
  final String currency;
  final WalletStatus status;
  final bool requireNonNegative;
  final bool allowPartialAllocation;

  // Investor-specific fields
  final double? investmentAmount;
  final double? investorPercentage;
  final double? userPercentage;
  final DateTime? investmentReturnDate;

  final DateTime createdAt;
  final DateTime updatedAt;

  const Wallet({
    required this.id,
    required this.userId,
    required this.name,
    required this.type,
    this.currency = 'RUB',
    this.status = WalletStatus.active,
    this.requireNonNegative = true,
    this.allowPartialAllocation = true,
    this.investmentAmount,
    this.investorPercentage,
    this.userPercentage,
    this.investmentReturnDate,
    required this.createdAt,
    required this.updatedAt,
  });

  Wallet copyWith({
    String? id,
    String? userId,
    String? name,
    WalletType? type,
    String? currency,
    WalletStatus? status,
    bool? requireNonNegative,
    bool? allowPartialAllocation,
    double? investmentAmount,
    double? investorPercentage,
    double? userPercentage,
    DateTime? investmentReturnDate,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return Wallet(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      name: name ?? this.name,
      type: type ?? this.type,
      currency: currency ?? this.currency,
      status: status ?? this.status,
      requireNonNegative: requireNonNegative ?? this.requireNonNegative,
      allowPartialAllocation: allowPartialAllocation ?? this.allowPartialAllocation,
      investmentAmount: investmentAmount ?? this.investmentAmount,
      investorPercentage: investorPercentage ?? this.investorPercentage,
      userPercentage: userPercentage ?? this.userPercentage,
      investmentReturnDate: investmentReturnDate ?? this.investmentReturnDate,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  bool get isInvestorWallet => type == WalletType.investor;
  bool get isPersonalWallet => type == WalletType.personal;
  bool get isActive => status == WalletStatus.active;

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is Wallet && other.id == id;
  }

  @override
  int get hashCode => id.hashCode;

  @override
  String toString() {
    return 'Wallet(id: $id, name: $name, type: $type, status: $status)';
  }
}

enum WalletType {
  personal,
  investor,
}

enum WalletStatus {
  active,
  archived,
}
