import '../../domain/entities/installment.dart';

class InstallmentModel extends Installment {
  // Optimized fields from database
  final String? clientName;
  final String? investorName;
  final double? paidAmount;
  final double? remainingAmount;
  final DateTime? nextPaymentDate;
  final double? nextPaymentAmount;
  final String? paymentStatus;
  final int? overdueCount;
  final int? totalPayments;
  final int? paidPayments;
  final DateTime? lastPaymentDate;

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
    // Optimized fields
    this.clientName,
    this.investorName,
    this.paidAmount,
    this.remainingAmount,
    this.nextPaymentDate,
    this.nextPaymentAmount,
    this.paymentStatus,
    this.overdueCount,
    this.totalPayments,
    this.paidPayments,
    this.lastPaymentDate,
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
      downPaymentDate: _parseDate(map['down_payment_date']),
      installmentStartDate: _parseDate(map['installment_start_date']),
      installmentEndDate: _parseDate(map['installment_end_date']),
      createdAt: _parseDateTime(map['created_at']),
      updatedAt: _parseDateTime(map['updated_at']),
    );
  }

  // Factory for optimized API response with pre-calculated fields
  factory InstallmentModel.fromMapOptimized(Map<String, dynamic> map) {
    return InstallmentModel(
      id: map['id'] as String,
      userId: map['user_id'] as String,
      clientId: map['client_id'] as String,
      investorId: map['investor_id'] as String,
      productName: map['product_name'] as String,
      cashPrice: (map['cash_price'] as num).toDouble(),
      installmentPrice: (map['installment_price'] as num).toDouble(),
      termMonths: map['term_months'] as int,
      downPayment: (map['down_payment'] as num).toDouble(),
      monthlyPayment: (map['monthly_payment'] as num).toDouble(),
      downPaymentDate: _parseDate(map['down_payment_date']),
      installmentStartDate: _parseDate(map['installment_start_date']),
      installmentEndDate: _parseDate(map['installment_end_date']),
      createdAt: _parseDateTime(map['created_at']),
      updatedAt: _parseDateTime(map['updated_at']),
      // Optimized pre-calculated fields
      clientName: map['client_name'] as String?,
      investorName: map['investor_name'] as String?,
      paidAmount: map['paid_amount'] != null ? (map['paid_amount'] as num).toDouble() : null,
      remainingAmount: map['remaining_amount'] != null ? (map['remaining_amount'] as num).toDouble() : null,
      nextPaymentDate: _parseDateNullable(map['next_payment_date']),
      nextPaymentAmount: map['next_payment_amount'] != null ? (map['next_payment_amount'] as num).toDouble() : null,
      paymentStatus: map['payment_status'] as String?,
      overdueCount: map['overdue_count'] as int?,
      totalPayments: map['total_payments'] as int?,
      paidPayments: map['paid_payments'] as int?,
      lastPaymentDate: _parseDateNullable(map['last_payment_date']),
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

  // For API requests, we need to format data properly
  Map<String, dynamic> toApiMap() {
    return {
      'user_id': userId,
      'client_id': clientId,
      'investor_id': investorId,
      'product_name': productName,
      'cash_price': cashPrice,
      'installment_price': installmentPrice,
      'term_months': termMonths,
      'down_payment': downPayment,
      'monthly_payment': monthlyPayment,
      'down_payment_date': _formatDate(downPaymentDate),
      'installment_start_date': _formatDate(installmentStartDate),
      'installment_end_date': _formatDate(installmentEndDate),
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
    if (value == null) {
      throw ArgumentError('Date value cannot be null');
    }
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

  static DateTime? _parseDateNullable(dynamic value) {
    if (value == null) {
      return null;
    }
    if (value is int) {
      // Local database format (milliseconds since epoch)
      return DateTime.fromMillisecondsSinceEpoch(value);
    } else if (value is String) {
      // API format (YYYY-MM-DD)
      return DateTime.parse(value);
    } else {
      return null;
    }
  }

  static String _formatDate(DateTime date) {
    return '${date.year.toString().padLeft(4, '0')}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
  }

  @override
  String toString() {
    return 'InstallmentModel(id: $id, productName: $productName, clientId: $clientId)';
  }
} 