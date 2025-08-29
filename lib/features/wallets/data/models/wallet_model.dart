import '../../domain/entities/wallet.dart';

class WalletModel {
  final String id;
  final String userId;
  final String name;
  final String type;
  final String currency;
  final String status;
  final bool requireNonNegative;
  final bool allowPartialAllocation;
  final double? investmentAmount;
  final double? startingAmount;
  final double? investorPercentage;
  final double? userPercentage;
  final DateTime? investmentReturnDate;
  final DateTime createdAt;
  final DateTime updatedAt;
  final int? balanceMinorUnits;
  final double? balanceRubles;
  final int? balanceVersion;
  final DateTime? balanceUpdatedAt;

  const WalletModel({
    required this.id,
    required this.userId,
    required this.name,
    required this.type,
    required this.currency,
    required this.status,
    required this.requireNonNegative,
    required this.allowPartialAllocation,
    this.investmentAmount,
    this.startingAmount,
    this.investorPercentage,
    this.userPercentage,
    this.investmentReturnDate,
    required this.createdAt,
    required this.updatedAt,
    this.balanceMinorUnits,
    this.balanceRubles,
    this.balanceVersion,
    this.balanceUpdatedAt,
  });

  factory WalletModel.fromJson(Map<String, dynamic> json) {
    // The API handles type detection, so use the type field
    final walletType = json['type'] as String? ?? 'personal';

    return WalletModel(
      id: json['id'] as String? ?? '',
      userId: json['user_id'] as String? ?? '',
      name: json['name'] as String? ?? '',
      type: walletType,
      currency: json['currency'] as String? ?? 'RUB',
      status: json['status'] as String? ?? 'active',
      requireNonNegative: json['require_nonnegative'] as bool? ?? true,
      allowPartialAllocation: json['allow_partial_allocation'] as bool? ?? false,
      investmentAmount: json['investment_amount_minor_units'] != null ? ((json['investment_amount_minor_units'] as num).toDouble() / 100) : null,
      startingAmount: json['starting_amount_minor_units'] != null ? ((json['starting_amount_minor_units'] as num).toDouble() / 100) : null,
      investorPercentage: json['investor_percentage'] != null ? (json['investor_percentage'] as num).toDouble() : null,
      userPercentage: json['user_percentage'] != null ? (json['user_percentage'] as num).toDouble() : null,
      investmentReturnDate: json['investment_return_date'] != null && json['investment_return_date'] is String
          ? DateTime.parse(json['investment_return_date'] as String)
          : null,
      createdAt: json['created_at'] != null && json['created_at'] is String
          ? DateTime.parse(json['created_at'] as String)
          : DateTime.now(),
      updatedAt: json['updated_at'] != null && json['updated_at'] is String
          ? DateTime.parse(json['updated_at'] as String)
          : DateTime.now(),
      balanceMinorUnits: json['balance'] != null ? (json['balance']['balance_minor_units'] as num?)?.toInt() : null,
      balanceRubles: json['balance'] != null ? (json['balance']['balance_rubles'] as num?)?.toDouble() : null,
      balanceVersion: json['balance'] != null ? (json['balance']['version'] as num?)?.toInt() : null,
      balanceUpdatedAt: json['balance'] != null && json['balance']['updated_at'] != null && json['balance']['updated_at'] is String
          ? DateTime.parse(json['balance']['updated_at'] as String)
          : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'user_id': userId,
      'name': name,
      'type': type,
      'currency': currency,
      'status': status,
      'require_nonnegative': requireNonNegative,
      'allow_partial_allocation': allowPartialAllocation,
      'investment_amount_minor_units': investmentAmount != null ? (investmentAmount! * 100).toInt() : null,
      'starting_amount_minor_units': startingAmount != null ? (startingAmount! * 100).toInt() : null,
      'investor_percentage': investorPercentage,
      'user_percentage': userPercentage,
      'investment_return_date': investmentReturnDate?.toIso8601String(),
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
      'balance_minor_units': balanceMinorUnits,
      'balance_rubles': balanceRubles,
      'balance_version': balanceVersion,
      'balance_updated_at': balanceUpdatedAt?.toIso8601String(),
    };
  }

  Wallet toEntity() {
    return Wallet(
      id: id,
      userId: userId,
      name: name,
      type: _parseWalletType(type),
      currency: currency,
      status: _parseWalletStatus(status),
      requireNonNegative: requireNonNegative,
      allowPartialAllocation: allowPartialAllocation,
      investmentAmount: investmentAmount,
      startingAmount: startingAmount,
      investorPercentage: investorPercentage,
      userPercentage: userPercentage,
      investmentReturnDate: investmentReturnDate,
      createdAt: createdAt,
      updatedAt: updatedAt,
    );
  }

  static WalletModel fromEntity(Wallet wallet) {
    return WalletModel(
      id: wallet.id,
      userId: wallet.userId,
      name: wallet.name,
      type: wallet.type.name,
      currency: wallet.currency,
      status: wallet.status.name,
      requireNonNegative: wallet.requireNonNegative,
      allowPartialAllocation: wallet.allowPartialAllocation,
      investmentAmount: wallet.investmentAmount,
      startingAmount: wallet.startingAmount,
      investorPercentage: wallet.investorPercentage,
      userPercentage: wallet.userPercentage,
      investmentReturnDate: wallet.investmentReturnDate,
      createdAt: wallet.createdAt,
      updatedAt: wallet.updatedAt,
      balanceMinorUnits: null, // Balance information is not stored in the Wallet entity
      balanceRubles: null,
      balanceVersion: null,
      balanceUpdatedAt: null,
    );
  }

  static WalletType _parseWalletType(String type) {
    switch (type) {
      case 'personal':
        return WalletType.personal;
      case 'investor':
        return WalletType.investor;
      default:
        throw ArgumentError('Unknown wallet type: $type');
    }
  }

  static WalletStatus _parseWalletStatus(String status) {
    switch (status) {
      case 'active':
        return WalletStatus.active;
      case 'archived':
        return WalletStatus.archived;
      default:
        throw ArgumentError('Unknown wallet status: $status');
    }
  }
}
