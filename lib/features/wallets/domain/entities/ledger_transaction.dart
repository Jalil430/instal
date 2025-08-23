class LedgerTransaction {
  final String id;
  final String walletId;
  final String userId;
  final TransactionDirection direction;
  final int amountMinorUnits;
  final String currency;
  final TransactionType referenceType;
  final String? referenceId;
  final String? groupId;
  final String? correlationId;
  final String description;
  final String createdBy;
  final DateTime createdAt;

  const LedgerTransaction({
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

  double get amount => amountMinorUnits / 100.0;
  bool get isCredit => direction == TransactionDirection.credit;
  bool get isDebit => direction == TransactionDirection.debit;

  LedgerTransaction copyWith({
    String? id,
    String? walletId,
    String? userId,
    TransactionDirection? direction,
    int? amountMinorUnits,
    String? currency,
    TransactionType? referenceType,
    String? referenceId,
    String? groupId,
    String? correlationId,
    String? description,
    String? createdBy,
    DateTime? createdAt,
  }) {
    return LedgerTransaction(
      id: id ?? this.id,
      walletId: walletId ?? this.walletId,
      userId: userId ?? this.userId,
      direction: direction ?? this.direction,
      amountMinorUnits: amountMinorUnits ?? this.amountMinorUnits,
      currency: currency ?? this.currency,
      referenceType: referenceType ?? this.referenceType,
      referenceId: referenceId ?? this.referenceId,
      groupId: groupId ?? this.groupId,
      correlationId: correlationId ?? this.correlationId,
      description: description ?? this.description,
      createdBy: createdBy ?? this.createdBy,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is LedgerTransaction && other.id == id;
  }

  @override
  int get hashCode => id.hashCode;

  @override
  String toString() {
    return 'LedgerTransaction(id: $id, walletId: $walletId, direction: $direction, amount: ${amount.toStringAsFixed(2)} $currency, type: $referenceType)';
  }
}

enum TransactionDirection {
  credit,
  debit,
}

enum TransactionType {
  installment,
  adjustment,
  transfer,
  reversal,
  initial_investment,
  profit_distribution,
}
