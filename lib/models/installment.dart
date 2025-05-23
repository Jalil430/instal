class Installment {
  final String id;
  final String userId;
  final String clientId;
  final String? investorId;
  final String productName;
  final double cashPrice;
  final double installmentPrice;
  final int term;
  final double downPayment;
  final double monthlyPayment;
  final DateTime downPaymentDate;
  final DateTime installmentStartDate;
  final DateTime installmentEndDate;
  final DateTime createdAt;

  Installment({
    required this.id,
    required this.userId,
    required this.clientId,
    this.investorId,
    required this.productName,
    required this.cashPrice,
    required this.installmentPrice,
    required this.term,
    required this.downPayment,
    required this.monthlyPayment,
    required this.downPaymentDate,
    required this.installmentStartDate,
    required this.installmentEndDate,
    required this.createdAt,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'userId': userId,
      'clientId': clientId,
      'investorId': investorId,
      'productName': productName,
      'cashPrice': cashPrice,
      'installmentPrice': installmentPrice,
      'term': term,
      'downPayment': downPayment,
      'monthlyPayment': monthlyPayment,
      'downPaymentDate': downPaymentDate.toIso8601String(),
      'installmentStartDate': installmentStartDate.toIso8601String(),
      'installmentEndDate': installmentEndDate.toIso8601String(),
      'createdAt': createdAt.toIso8601String(),
    };
  }

  factory Installment.fromMap(Map<String, dynamic> map) {
    return Installment(
      id: map['id'] as String,
      userId: map['userId'] as String,
      clientId: map['clientId'] as String,
      investorId: map['investorId'] as String?,
      productName: map['productName'] as String,
      cashPrice: (map['cashPrice'] as num).toDouble(),
      installmentPrice: (map['installmentPrice'] as num).toDouble(),
      term: map['term'] as int,
      downPayment: (map['downPayment'] as num).toDouble(),
      monthlyPayment: (map['monthlyPayment'] as num).toDouble(),
      downPaymentDate: DateTime.parse(map['downPaymentDate'] as String),
      installmentStartDate: DateTime.parse(map['installmentStartDate'] as String),
      installmentEndDate: DateTime.parse(map['installmentEndDate'] as String),
      createdAt: DateTime.parse(map['createdAt'] as String),
    );
  }

  Installment copyWith({
    String? id,
    String? userId,
    String? clientId,
    String? investorId,
    String? productName,
    double? cashPrice,
    double? installmentPrice,
    int? term,
    double? downPayment,
    double? monthlyPayment,
    DateTime? downPaymentDate,
    DateTime? installmentStartDate,
    DateTime? installmentEndDate,
    DateTime? createdAt,
  }) {
    return Installment(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      clientId: clientId ?? this.clientId,
      investorId: investorId ?? this.investorId,
      productName: productName ?? this.productName,
      cashPrice: cashPrice ?? this.cashPrice,
      installmentPrice: installmentPrice ?? this.installmentPrice,
      term: term ?? this.term,
      downPayment: downPayment ?? this.downPayment,
      monthlyPayment: monthlyPayment ?? this.monthlyPayment,
      downPaymentDate: downPaymentDate ?? this.downPaymentDate,
      installmentStartDate: installmentStartDate ?? this.installmentStartDate,
      installmentEndDate: installmentEndDate ?? this.installmentEndDate,
      createdAt: createdAt ?? this.createdAt,
    );
  }
} 