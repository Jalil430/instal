import '../../domain/entities/wallet_balance.dart';

class WalletBalanceModel {
  final String walletId;
  final String userId;
  final int balanceMinorUnits;
  final int version;
  final DateTime updatedAt;
  final int totalAllocatedMinorUnits;
  final int dueToGetMinorUnits;
  final int expectedRevenueMinorUnits;
  final int paidAmountMinorUnits;

  const WalletBalanceModel({
    required this.walletId,
    required this.userId,
    required this.balanceMinorUnits,
    required this.version,
    required this.updatedAt,
    this.totalAllocatedMinorUnits = 0,
    this.dueToGetMinorUnits = 0,
    this.expectedRevenueMinorUnits = 0,
    this.paidAmountMinorUnits = 0,
  });

  factory WalletBalanceModel.fromJson(Map<String, dynamic> json) {
    return WalletBalanceModel(
      walletId: json['wallet_id'] as String,
      userId: json['user_id'] as String,
      balanceMinorUnits: (json['balance_minor_units'] as num).toInt(),
      version: (json['version'] as num).toInt(),
      updatedAt: DateTime.parse(json['updated_at'] as String),
      totalAllocatedMinorUnits: (json['total_allocated_minor_units'] as num?)?.toInt() ?? 0,
      dueToGetMinorUnits: (json['due_to_get_minor_units'] as num?)?.toInt() ?? 0,
      expectedRevenueMinorUnits: (json['expected_revenue_minor_units'] as num?)?.toInt() ?? 0,
      paidAmountMinorUnits: (json['paid_amount_minor_units'] as num?)?.toInt() ?? 0,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'wallet_id': walletId,
      'user_id': userId,
      'balance_minor_units': balanceMinorUnits,
      'version': version,
      'updated_at': updatedAt.toIso8601String(),
      'total_allocated_minor_units': totalAllocatedMinorUnits,
      'due_to_get_minor_units': dueToGetMinorUnits,
      'expected_revenue_minor_units': expectedRevenueMinorUnits,
      'paid_amount_minor_units': paidAmountMinorUnits,
    };
  }

  WalletBalance toEntity() {
    return WalletBalance(
      walletId: walletId,
      userId: userId,
      balanceMinorUnits: balanceMinorUnits,
      version: version,
      updatedAt: updatedAt,
      totalAllocatedMinorUnits: totalAllocatedMinorUnits,
      dueToGetMinorUnits: dueToGetMinorUnits,
      expectedRevenueMinorUnits: expectedRevenueMinorUnits,
      paidAmountMinorUnits: paidAmountMinorUnits,
    );
  }

  static WalletBalanceModel fromEntity(WalletBalance balance) {
    return WalletBalanceModel(
      walletId: balance.walletId,
      userId: balance.userId,
      balanceMinorUnits: balance.balanceMinorUnits,
      version: balance.version,
      updatedAt: balance.updatedAt,
      totalAllocatedMinorUnits: balance.totalAllocatedMinorUnits,
      dueToGetMinorUnits: balance.dueToGetMinorUnits,
      expectedRevenueMinorUnits: balance.expectedRevenueMinorUnits,
      paidAmountMinorUnits: balance.paidAmountMinorUnits,
    );
  }
}
