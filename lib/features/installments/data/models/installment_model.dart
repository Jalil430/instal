import '../../domain/entities/installment.dart';

class InstallmentModel extends Installment {
  const InstallmentModel({
    required super.id,
    required super.userId,
    required super.clientId,
    required super.investorId,
    required super.productName,
    required super.cashPrice,
    required super.installmentPrice,
    required super.termMonths,
    required super.downPayment,
    required super.monthlyPayment,
    required super.downPaymentDate,
    required super.installmentStartDate,
    required super.installmentEndDate,
    required super.createdAt,
    required super.updatedAt,
  });

  factory InstallmentModel.fromMap(Map<String, dynamic> map) {
    return InstallmentModel(
      id: map['id'] as String,
      userId: map['user_id'] as String,
      clientId: map['client_id'] as String,
      investorId: map['investor_id'] as String,
      productName: map['product_name'] as String,
      cashPrice: map['cash_price'] as double,
      installmentPrice: map['installment_price'] as double,
      termMonths: map['term_months'] as int,
      downPayment: map['down_payment'] as double,
      monthlyPayment: map['monthly_payment'] as double,
      downPaymentDate: DateTime.fromMillisecondsSinceEpoch(map['down_payment_date'] as int),
      installmentStartDate: DateTime.fromMillisecondsSinceEpoch(map['installment_start_date'] as int),
      installmentEndDate: DateTime.fromMillisecondsSinceEpoch(map['installment_end_date'] as int),
      createdAt: DateTime.fromMillisecondsSinceEpoch(map['created_at'] as int),
      updatedAt: DateTime.fromMillisecondsSinceEpoch(map['updated_at'] as int),
    );
  }

  factory InstallmentModel.fromEntity(Installment installment) {
    return InstallmentModel(
      id: installment.id,
      userId: installment.userId,
      clientId: installment.clientId,
      investorId: installment.investorId,
      productName: installment.productName,
      cashPrice: installment.cashPrice,
      installmentPrice: installment.installmentPrice,
      termMonths: installment.termMonths,
      downPayment: installment.downPayment,
      monthlyPayment: installment.monthlyPayment,
      downPaymentDate: installment.downPaymentDate,
      installmentStartDate: installment.installmentStartDate,
      installmentEndDate: installment.installmentEndDate,
      createdAt: installment.createdAt,
      updatedAt: installment.updatedAt,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'user_id': userId,
      'client_id': clientId,
      'investor_id': investorId,
      'product_name': productName,
      'cash_price': cashPrice,
      'installment_price': installmentPrice,
      'term_months': termMonths,
      'down_payment': downPayment,
      'monthly_payment': monthlyPayment,
      'down_payment_date': downPaymentDate.millisecondsSinceEpoch,
      'installment_start_date': installmentStartDate.millisecondsSinceEpoch,
      'installment_end_date': installmentEndDate.millisecondsSinceEpoch,
      'created_at': createdAt.millisecondsSinceEpoch,
      'updated_at': updatedAt.millisecondsSinceEpoch,
    };
  }

  @override
  String toString() {
    return 'InstallmentModel(id: $id, productName: $productName, clientId: $clientId)';
  }
} 