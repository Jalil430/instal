import '../../domain/entities/installment_payment.dart';

class InstallmentPaymentModel extends InstallmentPayment {
  const InstallmentPaymentModel({
    required super.id,
    required super.installmentId,
    required super.paymentNumber,
    required super.dueDate,
    required super.expectedAmount,
    required super.paidAmount,
    required super.status,
    super.paidDate,
    required super.createdAt,
    required super.updatedAt,
  });

  factory InstallmentPaymentModel.fromMap(Map<String, dynamic> map) {
    return InstallmentPaymentModel(
      id: map['id'] as String,
      installmentId: map['installment_id'] as String,
      paymentNumber: map['payment_number'] as int,
      dueDate: DateTime.fromMillisecondsSinceEpoch(map['due_date'] as int),
      expectedAmount: map['expected_amount'] as double,
      paidAmount: map['paid_amount'] as double,
      status: map['status'] as String,
      paidDate: map['paid_date'] != null 
          ? DateTime.fromMillisecondsSinceEpoch(map['paid_date'] as int)
          : null,
      createdAt: DateTime.fromMillisecondsSinceEpoch(map['created_at'] as int),
      updatedAt: DateTime.fromMillisecondsSinceEpoch(map['updated_at'] as int),
    );
  }

  factory InstallmentPaymentModel.fromEntity(InstallmentPayment payment) {
    return InstallmentPaymentModel(
      id: payment.id,
      installmentId: payment.installmentId,
      paymentNumber: payment.paymentNumber,
      dueDate: payment.dueDate,
      expectedAmount: payment.expectedAmount,
      paidAmount: payment.paidAmount,
      status: payment.status,
      paidDate: payment.paidDate,
      createdAt: payment.createdAt,
      updatedAt: payment.updatedAt,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'installment_id': installmentId,
      'payment_number': paymentNumber,
      'due_date': dueDate.millisecondsSinceEpoch,
      'expected_amount': expectedAmount,
      'paid_amount': paidAmount,
      'status': status,
      'paid_date': paidDate?.millisecondsSinceEpoch,
      'created_at': createdAt.millisecondsSinceEpoch,
      'updated_at': updatedAt.millisecondsSinceEpoch,
    };
  }

  @override
  String toString() {
    return 'InstallmentPaymentModel(id: $id, paymentNumber: $paymentNumber, status: $status)';
  }
} 