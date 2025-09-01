class InstallmentPayment {
  final String id;
  final String installmentId;
  final int paymentNumber; // 0 for down payment, 1-n for monthly payments
  final DateTime dueDate;
  final double expectedAmount;
  final double paidAmount; // accumulated actual paid for this payment
  final bool isPaid;
  final DateTime? paidDate;
  final DateTime createdAt;
  final DateTime updatedAt;

  const InstallmentPayment({
    required this.id,
    required this.installmentId,
    required this.paymentNumber,
    required this.dueDate,
    required this.expectedAmount,
    this.paidAmount = 0.0,
    required this.isPaid,
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
    bool? isPaid,
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
      isPaid: isPaid ?? this.isPaid,
      paidDate: paidDate ?? this.paidDate,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  bool get isDownPayment => paymentNumber == 0;
  
  /// Dynamically calculated status based on current date and payment state
  String get status {
    // If payment is paid
    if (isPaid) {
      return 'оплачено';
    }
    
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final due = DateTime(dueDate.year, dueDate.month, dueDate.day);
    
    // Calculate days difference
    final daysDifference = today.difference(due).inDays;
    
    if (daysDifference > 0) {
      // Even 1 day overdue is considered late
      return 'просрочено';
    } else if (daysDifference == 0) {
      // Due today only
      return 'к оплате';
    } else {
      // Future payment
      return 'предстоящий';
    }
  }
  
  bool get isOverdue => status == 'просрочено';
  
  bool get isDue => status == 'к оплате';
  
  bool get isUpcoming => status == 'предстоящий';

  // paidAmount now comes from backend and accumulates actuals

  String get paymentLabel {
    if (isDownPayment) {
      return 'Первоначальный взнос';
    }
    return 'Месяц $paymentNumber';
  }

  @override
  String toString() {
    return 'InstallmentPayment(id: $id, paymentNumber: $paymentNumber, isPaid: $isPaid, status: $status)';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
  
    return other is InstallmentPayment &&
      other.id == id &&
      other.installmentId == installmentId &&
      other.paymentNumber == paymentNumber &&
      other.dueDate == dueDate &&
      other.expectedAmount == expectedAmount &&
      other.paidAmount == paidAmount &&
      other.isPaid == isPaid &&
      other.paidDate == paidDate &&
      other.createdAt == createdAt &&
      other.updatedAt == updatedAt;
  }

  @override
  int get hashCode {
    return id.hashCode ^
      installmentId.hashCode ^
      paymentNumber.hashCode ^
      dueDate.hashCode ^
      expectedAmount.hashCode ^
      paidAmount.hashCode ^
      isPaid.hashCode ^
      paidDate.hashCode ^
      createdAt.hashCode ^
      updatedAt.hashCode;
  }
}
