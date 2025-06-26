class Investor {
  final String id;
  final String userId;
  final String fullName;
  final double investmentAmount;
  final double investorPercentage;
  final double userPercentage;
  final DateTime createdAt;
  final DateTime updatedAt;

  const Investor({
    required this.id,
    required this.userId,
    required this.fullName,
    required this.investmentAmount,
    required this.investorPercentage,
    required this.userPercentage,
    required this.createdAt,
    required this.updatedAt,
  });

  Investor copyWith({
    String? id,
    String? userId,
    String? fullName,
    double? investmentAmount,
    double? investorPercentage,
    double? userPercentage,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return Investor(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      fullName: fullName ?? this.fullName,
      investmentAmount: investmentAmount ?? this.investmentAmount,
      investorPercentage: investorPercentage ?? this.investorPercentage,
      userPercentage: userPercentage ?? this.userPercentage,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is Investor && other.id == id;
  }

  @override
  int get hashCode => id.hashCode;

  @override
  String toString() {
    return 'Investor(id: $id, fullName: $fullName, investmentAmount: $investmentAmount)';
  }
} 