class Installment {
  final String id;
  final String userId;
  final String clientId;
  final String investorId;
  final String productName;
  final double cashPrice;
  final double installmentPrice;
  final int termMonths;
  final double downPayment;
  final double monthlyPayment;
  final DateTime downPaymentDate;
  final DateTime installmentStartDate;
  final DateTime installmentEndDate;
  final DateTime createdAt;
  final DateTime updatedAt;
  final int? installmentNumber;

  const Installment({
    required this.id,
    required this.userId,
    required this.clientId,
    required this.investorId,
    required this.productName,
    required this.cashPrice,
    required this.installmentPrice,
    required this.termMonths,
    required this.downPayment,
    required this.monthlyPayment,
    required this.downPaymentDate,
    required this.installmentStartDate,
    required this.installmentEndDate,
    this.installmentNumber,
    required this.createdAt,
    required this.updatedAt,
  });

  Installment copyWith({
    String? id,
    String? userId,
    String? clientId,
    String? investorId,
    String? productName,
    double? cashPrice,
    double? installmentPrice,
    int? termMonths,
    double? downPayment,
    double? monthlyPayment,
    DateTime? downPaymentDate,
    DateTime? installmentStartDate,
    DateTime? installmentEndDate,
    int? installmentNumber,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return Installment(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      clientId: clientId ?? this.clientId,
      investorId: investorId ?? this.investorId,
      productName: productName ?? this.productName,
      cashPrice: cashPrice ?? this.cashPrice,
      installmentPrice: installmentPrice ?? this.installmentPrice,
      termMonths: termMonths ?? this.termMonths,
      downPayment: downPayment ?? this.downPayment,
      monthlyPayment: monthlyPayment ?? this.monthlyPayment,
      downPaymentDate: downPaymentDate ?? this.downPaymentDate,
      installmentStartDate: installmentStartDate ?? this.installmentStartDate,
      installmentEndDate: installmentEndDate ?? this.installmentEndDate,
      installmentNumber: installmentNumber ?? this.installmentNumber,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is Installment && other.id == id;
  }

  @override
  int get hashCode => id.hashCode;

  @override
  String toString() {
    return 'Installment(id: $id, productName: $productName, clientId: $clientId)';
  }
} 