import '../../domain/entities/subscription.dart';

class SubscriptionModel extends Subscription {
  const SubscriptionModel({
    required super.code,
    required super.type,
    required super.duration,
    super.userTelegram,
    required super.amount,
    required super.createdDate,
    super.activatedDate,
    super.endDate,
    required super.status,
    super.activatedBy,
  });

  factory SubscriptionModel.fromJson(Map<String, dynamic> json) {
    DateTime? parseDate(dynamic v) {
      if (v == null) return null;
      if (v is String) return DateTime.parse(v).toUtc();
      return DateTime.parse(v.toString()).toUtc();
    }
    return SubscriptionModel(
      code: json['code'] as String,
      type: _parseSubscriptionType(json['subscription_type'] as String),
      duration: json['duration'] as String,
      userTelegram: json['user_telegram'] as String?,
      amount: (json['amount'] as num).toDouble(),
      createdDate: parseDate(json['created_date'])!,
      activatedDate: parseDate(json['activated_date']),
      endDate: parseDate(json['end_date']),
      status: _parseSubscriptionStatus(json['status'] as String),
      activatedBy: json['activated_by'] as String?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'code': code,
      'subscription_type': _subscriptionTypeToString(type),
      'duration': duration,
      'user_telegram': userTelegram,
      'amount': amount,
      'created_date': createdDate.toIso8601String(),
      'activated_date': activatedDate?.toIso8601String(),
      'end_date': endDate?.toIso8601String(),
      'status': _subscriptionStatusToString(status),
      'activated_by': activatedBy,
    };
  }

  static SubscriptionType _parseSubscriptionType(String type) {
    switch (type.toLowerCase()) {
      case 'trial':
        return SubscriptionType.trial;
      case 'basic':
        return SubscriptionType.basic;
      case 'pro':
        return SubscriptionType.pro;
      default:
        throw ArgumentError('Unknown subscription type: $type');
    }
  }

  static String _subscriptionTypeToString(SubscriptionType type) {
    switch (type) {
      case SubscriptionType.trial:
        return 'trial';
      case SubscriptionType.basic:
        return 'basic';
      case SubscriptionType.pro:
        return 'pro';
    }
  }

  static SubscriptionStatus _parseSubscriptionStatus(String status) {
    switch (status.toLowerCase()) {
      case 'unused':
        return SubscriptionStatus.unused;
      case 'active':
        return SubscriptionStatus.active;
      case 'expired':
        return SubscriptionStatus.expired;
      default:
        throw ArgumentError('Unknown subscription status: $status');
    }
  }

  static String _subscriptionStatusToString(SubscriptionStatus status) {
    switch (status) {
      case SubscriptionStatus.unused:
        return 'unused';
      case SubscriptionStatus.active:
        return 'active';
      case SubscriptionStatus.expired:
        return 'expired';
    }
  }

  factory SubscriptionModel.fromEntity(Subscription subscription) {
    return SubscriptionModel(
      code: subscription.code,
      type: subscription.type,
      duration: subscription.duration,
      userTelegram: subscription.userTelegram,
      amount: subscription.amount,
      createdDate: subscription.createdDate,
      activatedDate: subscription.activatedDate,
      endDate: subscription.endDate,
      status: subscription.status,
      activatedBy: subscription.activatedBy,
    );
  }
}