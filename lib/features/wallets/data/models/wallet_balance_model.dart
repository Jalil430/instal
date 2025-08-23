import '../../domain/entities/wallet_balance.dart';

class WalletBalanceModel {
  final String walletId;
  final String userId;
  final int balanceMinorUnits;
  final int version;
  final DateTime updatedAt;

  const WalletBalanceModel({
    required this.walletId,
    required this.userId,
    required this.balanceMinorUnits,
    required this.version,
    required this.updatedAt,
  });

  factory WalletBalanceModel.fromJson(Map<String, dynamic> json) {
    return WalletBalanceModel(
      walletId: json['wallet_id'] as String,
      userId: json['user_id'] as String,
      balanceMinorUnits: (json['balance_minor_units'] as num).toInt(),
      version: (json['version'] as num).toInt(),
      updatedAt: DateTime.parse(json['updated_at'] as String),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'wallet_id': walletId,
      'user_id': userId,
      'balance_minor_units': balanceMinorUnits,
      'version': version,
      'updated_at': updatedAt.toIso8601String(),
    };
  }

  WalletBalance toEntity() {
    return WalletBalance(
      walletId: walletId,
      userId: userId,
      balanceMinorUnits: balanceMinorUnits,
      version: version,
      updatedAt: updatedAt,
    );
  }

  static WalletBalanceModel fromEntity(WalletBalance balance) {
    return WalletBalanceModel(
      walletId: balance.walletId,
      userId: balance.userId,
      balanceMinorUnits: balance.balanceMinorUnits,
      version: balance.version,
      updatedAt: balance.updatedAt,
    );
  }
}
