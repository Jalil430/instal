import '../../domain/entities/ledger_transaction.dart';

class LedgerTransactionModel {
  final String id;
  final String walletId;
  final String userId;
  final String direction;
  final int amountMinorUnits;
  final String currency;
  final String referenceType;
  final String? referenceId;
  final String? groupId;
  final String? correlationId;
  final String description;
  final String createdBy;
  final DateTime createdAt;

  const LedgerTransactionModel({
    required this.id,
    required this.walletId,
    required this.userId,
    required this.direction,
    required this.amountMinorUnits,
    required this.currency,
    required this.referenceType,
    required this.description,
    required this.createdBy,
    required this.createdAt,
    this.referenceId,
    this.groupId,
    this.correlationId,
  });

  factory LedgerTransactionModel.fromJson(Map<String, dynamic> json) {
    return LedgerTransactionModel(
      id: json['id'] as String,
      walletId: json['wallet_id'] as String,
      userId: json['user_id'] as String,
      direction: json['direction'] as String,
      amountMinorUnits: (json['amount_minor_units'] as num).toInt(),
      currency: json['currency'] as String,
      referenceType: json['reference_type'] as String,
      referenceId: json['reference_id'] as String?,
      groupId: json['group_id'] as String?,
      correlationId: json['correlation_id'] as String?,
      description: json['description'] as String,
      createdBy: json['created_by'] as String,
      createdAt: DateTime.parse(json['created_at'] as String),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'wallet_id': walletId,
      'user_id': userId,
      'direction': direction,
      'amount_minor_units': amountMinorUnits,
      'currency': currency,
      'reference_type': referenceType,
      'reference_id': referenceId,
      'group_id': groupId,
      'correlation_id': correlationId,
      'description': description,
      'created_by': createdBy,
      'created_at': createdAt.toIso8601String(),
    };
  }

  LedgerTransaction toEntity() {
    return LedgerTransaction(
      id: id,
      walletId: walletId,
      userId: userId,
      direction: _parseDirection(direction),
      amountMinorUnits: amountMinorUnits,
      currency: currency,
      referenceType: _parseTransactionType(referenceType),
      referenceId: referenceId,
      groupId: groupId,
      correlationId: correlationId,
      description: description,
      createdBy: createdBy,
      createdAt: createdAt,
    );
  }

  static LedgerTransactionModel fromEntity(LedgerTransaction transaction) {
    return LedgerTransactionModel(
      id: transaction.id,
      walletId: transaction.walletId,
      userId: transaction.userId,
      direction: transaction.direction.name,
      amountMinorUnits: transaction.amountMinorUnits,
      currency: transaction.currency,
      referenceType: transaction.referenceType.name,
      referenceId: transaction.referenceId,
      groupId: transaction.groupId,
      correlationId: transaction.correlationId,
      description: transaction.description,
      createdBy: transaction.createdBy,
      createdAt: transaction.createdAt,
    );
  }

  static TransactionDirection _parseDirection(String direction) {
    switch (direction) {
      case 'credit':
        return TransactionDirection.credit;
      case 'debit':
        return TransactionDirection.debit;
      default:
        throw ArgumentError('Unknown transaction direction: $direction');
    }
  }

  static TransactionType _parseTransactionType(String type) {
    switch (type) {
      case 'installment':
        return TransactionType.installment;
      case 'adjustment':
        return TransactionType.adjustment;
      case 'transfer':
        return TransactionType.transfer;
      case 'reversal':
        return TransactionType.reversal;
      case 'initial_investment':
        return TransactionType.initial_investment;
      case 'profit_distribution':
        return TransactionType.profit_distribution;
      default:
        throw ArgumentError('Unknown transaction type: $type');
    }
  }
}
