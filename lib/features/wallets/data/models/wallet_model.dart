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
  final double? investorPercentage;
  final double? userPercentage;
  final DateTime? investmentReturnDate;
  final DateTime createdAt;
  final DateTime updatedAt;

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
    this.investorPercentage,
    this.userPercentage,
    this.investmentReturnDate,
    required this.createdAt,
    required this.updatedAt,
  });

  factory WalletModel.fromJson(Map<String, dynamic> json) {
    return WalletModel(
      id: json['id'] as String,
      userId: json['user_id'] as String,
      name: json['name'] as String,
      type: json['type'] as String,
      currency: json['currency'] as String,
      status: json['status'] as String,
      requireNonNegative: json['require_nonnegative'] as bool? ?? true,
      allowPartialAllocation: json['allow_partial_allocation'] as bool? ?? true,
      investmentAmount: json['investment_amount'] != null ? (json['investment_amount'] as num).toDouble() : null,
      investorPercentage: json['investor_percentage'] != null ? (json['investor_percentage'] as num).toDouble() : null,
      userPercentage: json['user_percentage'] != null ? (json['user_percentage'] as num).toDouble() : null,
      investmentReturnDate: json['investment_return_date'] != null ? DateTime.parse(json['investment_return_date'] as String) : null,
      createdAt: DateTime.parse(json['created_at'] as String),
      updatedAt: DateTime.parse(json['updated_at'] as String),
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
      'investment_amount': investmentAmount,
      'investor_percentage': investorPercentage,
      'user_percentage': userPercentage,
      'investment_return_date': investmentReturnDate?.toIso8601String(),
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
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
      investorPercentage: wallet.investorPercentage,
      userPercentage: wallet.userPercentage,
      investmentReturnDate: wallet.investmentReturnDate,
      createdAt: wallet.createdAt,
      updatedAt: wallet.updatedAt,
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
