class InstallmentPayment {
  final String id;
  final String installmentId;
  final int paymentNumber; // 0 for down payment, 1-n for monthly payments
  final DateTime dueDate;
  final double expectedAmount;
  final double paidAmount;
  final String status; // оплачено, предстоящий, к оплате, просрочено
  final DateTime? paidDate;
  final DateTime createdAt;
  final DateTime updatedAt;

  const InstallmentPayment({
    required this.id,
    required this.installmentId,
    required this.paymentNumber,
    required this.dueDate,
    required this.expectedAmount,
    required this.paidAmount,
    required this.status,
    this.paidDate,
    required this.createdAt,
    required this.updatedAt,
  });

  InstallmentPayment copyWith({
    String? id,
    String? installmentId,
    int? paymentNumber,
    DateTime? dueDate,
    double? expectedAmount,
    double? paidAmount,
    String? status,
    DateTime? paidDate,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return InstallmentPayment(
      id: id ?? this.id,
      installmentId: installmentId ?? this.installmentId,
      paymentNumber: paymentNumber ?? this.paymentNumber,
      dueDate: dueDate ?? this.dueDate,
      expectedAmount: expectedAmount ?? this.expectedAmount,
      paidAmount: paidAmount ?? this.paidAmount,
      status: status ?? this.status,
      paidDate: paidDate ?? this.paidDate,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  bool get isDownPayment => paymentNumber == 0;
  
  bool get isPaid => status == 'оплачено';
  
  bool get isOverdue => status == 'просрочено';
  
  bool get isDue => status == 'к оплате';
  
  bool get isUpcoming => status == 'предстоящий';

  String get paymentLabel {
    if (isDownPayment) {
      return 'Первоначальный взнос';
    }
    return 'Месяц $paymentNumber';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is InstallmentPayment && other.id == id;
  }

  @override
  int get hashCode => id.hashCode;

  @override
  String toString() {
    return 'InstallmentPayment(id: $id, paymentNumber: $paymentNumber, status: $status)';
  }
} 