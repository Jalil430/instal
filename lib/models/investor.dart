class Investor {
  final String id;
  final String userId;
  final String fullName;
  final double investmentAmount;
  final double investorPercentage;
  final double userPercentage;
  final DateTime createdAt;

  Investor({
    required this.id,
    required this.userId,
    required this.fullName,
    required this.investmentAmount,
    required this.investorPercentage,
    required this.userPercentage,
    required this.createdAt,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'userId': userId,
      'fullName': fullName,
      'investmentAmount': investmentAmount,
      'investorPercentage': investorPercentage,
      'userPercentage': userPercentage,
      'createdAt': createdAt.toIso8601String(),
    };
  }

  factory Investor.fromMap(Map<String, dynamic> map) {
    return Investor(
      id: map['id'] as String,
      userId: map['userId'] as String,
      fullName: map['fullName'] as String,
      investmentAmount: (map['investmentAmount'] as num).toDouble(),
      investorPercentage: (map['investorPercentage'] as num).toDouble(),
      userPercentage: (map['userPercentage'] as num).toDouble(),
      createdAt: DateTime.parse(map['createdAt'] as String),
    );
  }

  Investor copyWith({
    String? id,
    String? userId,
    String? fullName,
    double? investmentAmount,
    double? investorPercentage,
    double? userPercentage,
    DateTime? createdAt,
  }) {
    return Investor(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      fullName: fullName ?? this.fullName,
      investmentAmount: investmentAmount ?? this.investmentAmount,
      investorPercentage: investorPercentage ?? this.investorPercentage,
      userPercentage: userPercentage ?? this.userPercentage,
      createdAt: createdAt ?? this.createdAt,
    );
  }
} 