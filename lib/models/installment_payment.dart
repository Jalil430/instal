enum PaymentStatus {
  paid('оплачено'),
  upcoming('предстоящий'),
  due('к оплате'),
  overdue('просрочено');

  final String label;
  const PaymentStatus(this.label);

  static PaymentStatus fromString(String status) {
    return PaymentStatus.values.firstWhere(
      (e) => e.label == status,
      orElse: () => PaymentStatus.upcoming,
    );
  }
}

class InstallmentPayment {
  final String id;
  final String installmentId;
  final int paymentNumber;
  final DateTime dueDate;
  final double expectedAmount;
  final double paidAmount;
  final PaymentStatus status;
  final DateTime? paidDate;

  InstallmentPayment({
    required this.id,
    required this.installmentId,
    required this.paymentNumber,
    required this.dueDate,
    required this.expectedAmount,
    required this.paidAmount,
    required this.status,
    this.paidDate,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'installmentId': installmentId,
      'paymentNumber': paymentNumber,
      'dueDate': dueDate.toIso8601String(),
      'expectedAmount': expectedAmount,
      'paidAmount': paidAmount,
      'status': status.label,
      'paidDate': paidDate?.toIso8601String(),
    };
  }

  factory InstallmentPayment.fromMap(Map<String, dynamic> map) {
    return InstallmentPayment(
      id: map['id'] as String,
      installmentId: map['installmentId'] as String,
      paymentNumber: map['paymentNumber'] as int,
      dueDate: DateTime.parse(map['dueDate'] as String),
      expectedAmount: (map['expectedAmount'] as num).toDouble(),
      paidAmount: (map['paidAmount'] as num).toDouble(),
      status: PaymentStatus.fromString(map['status'] as String),
      paidDate: map['paidDate'] != null ? DateTime.parse(map['paidDate'] as String) : null,
    );
  }

  InstallmentPayment copyWith({
    String? id,
    String? installmentId,
    int? paymentNumber,
    DateTime? dueDate,
    double? expectedAmount,
    double? paidAmount,
    PaymentStatus? status,
    DateTime? paidDate,
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
    );
  }

  String get displayName {
    return paymentNumber == 0 ? 'Down Payment' : 'Month $paymentNumber';
  }

  bool get isOverdue {
    if (status == PaymentStatus.paid) return false;
    final now = DateTime.now();
    final daysDifference = now.difference(dueDate).inDays;
    return daysDifference > 2;
  }

  bool get isDue {
    if (status == PaymentStatus.paid) return false;
    final now = DateTime.now();
    final daysDifference = now.difference(dueDate).inDays;
    return daysDifference >= 0 && daysDifference <= 2;
  }
} 