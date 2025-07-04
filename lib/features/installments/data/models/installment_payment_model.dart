import '../../domain/entities/installment_payment.dart';

class InstallmentPaymentModel extends InstallmentPayment {
  const InstallmentPaymentModel({
    required super.id,
    required super.installmentId,
    required super.paymentNumber,
    required super.dueDate,
    required super.expectedAmount,
    required super.isPaid,
    super.paidDate,
    required super.createdAt,
    required super.updatedAt,
  });

  factory InstallmentPaymentModel.fromMap(Map<String, dynamic> map) {
    return InstallmentPaymentModel(
      id: map['id'] as String,
      installmentId: map['installment_id'] as String,
      paymentNumber: map['payment_number'] as int,
      dueDate: _parseDate(map['due_date']),
      expectedAmount: map['expected_amount'] as double,
      isPaid: _parseBool(map['is_paid']),
      paidDate: map['paid_date'] != null ? _parseDate(map['paid_date']) : null,
      createdAt: _parseDateTime(map['created_at']),
      updatedAt: _parseDateTime(map['updated_at']),
    );
  }

  factory InstallmentPaymentModel.fromEntity(InstallmentPayment payment) {
    return InstallmentPaymentModel(
      id: payment.id,
      installmentId: payment.installmentId,
      paymentNumber: payment.paymentNumber,
      dueDate: payment.dueDate,
      expectedAmount: payment.expectedAmount,
      isPaid: payment.isPaid,
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
      'is_paid': isPaid ? 1 : 0,
      'paid_date': paidDate?.millisecondsSinceEpoch,
      'created_at': createdAt.millisecondsSinceEpoch,
      'updated_at': updatedAt.millisecondsSinceEpoch,
    };
  }

  static DateTime _parseDateTime(dynamic value) {
    if (value is int) {
      // Local database format (milliseconds since epoch)
      return DateTime.fromMillisecondsSinceEpoch(value);
    } else if (value is String) {
      // API format (ISO string)
      return DateTime.parse(value);
    } else {
      throw ArgumentError('Invalid datetime format: $value');
    }
  }

  static DateTime _parseDate(dynamic value) {
    if (value is int) {
      // Local database format (milliseconds since epoch)
      return DateTime.fromMillisecondsSinceEpoch(value);
    } else if (value is String) {
      // API format (YYYY-MM-DD)
      return DateTime.parse(value);
    } else {
      throw ArgumentError('Invalid date format: $value');
    }
  }

  static bool _parseBool(dynamic value) {
    if (value is bool) {
      return value;
    } else if (value is int) {
      // Local database format (1 or 0)
      return value == 1;
    } else {
      throw ArgumentError('Invalid boolean format: $value');
    }
  }

  @override
  String toString() {
    return 'InstallmentPaymentModel(id: $id, paymentNumber: $paymentNumber, isPaid: $isPaid, status: $status)';
  }
} 