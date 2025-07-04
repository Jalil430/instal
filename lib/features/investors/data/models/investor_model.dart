import '../../domain/entities/investor.dart';

class InvestorModel extends Investor {
  const InvestorModel({
    required super.id,
    required super.userId,
    required super.fullName,
    required super.investmentAmount,
    required super.investorPercentage,
    required super.userPercentage,
    required super.createdAt,
    required super.updatedAt,
  });

  factory InvestorModel.fromMap(Map<String, dynamic> map) {
    return InvestorModel(
      id: map['id'] as String,
      userId: map['user_id'] as String,
      fullName: map['full_name'] as String,
      investmentAmount: map['investment_amount'] as double,
      investorPercentage: map['investor_percentage'] as double,
      userPercentage: map['user_percentage'] as double,
      createdAt: _parseDateTime(map['created_at']),
      updatedAt: _parseDateTime(map['updated_at']),
    );
  }

  factory InvestorModel.fromEntity(Investor investor) {
    return InvestorModel(
      id: investor.id,
      userId: investor.userId,
      fullName: investor.fullName,
      investmentAmount: investor.investmentAmount,
      investorPercentage: investor.investorPercentage,
      userPercentage: investor.userPercentage,
      createdAt: investor.createdAt,
      updatedAt: investor.updatedAt,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'user_id': userId,
      'full_name': fullName,
      'investment_amount': investmentAmount,
      'investor_percentage': investorPercentage,
      'user_percentage': userPercentage,
      'created_at': createdAt.millisecondsSinceEpoch,
      'updated_at': updatedAt.millisecondsSinceEpoch,
    };
  }

  // For API requests, we need to format data properly
  Map<String, dynamic> toApiMap() {
    return {
      'user_id': userId,
      'full_name': fullName,
      'investment_amount': investmentAmount,
      'investor_percentage': investorPercentage,
      'user_percentage': userPercentage,
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

  @override
  String toString() {
    return 'InvestorModel(id: $id, fullName: $fullName, investmentAmount: $investmentAmount)';
  }
} 