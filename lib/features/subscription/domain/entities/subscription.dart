enum SubscriptionType { trial, basic, pro }

enum SubscriptionStatus { unused, active, expired }

class Subscription {
  final String code;
  final SubscriptionType type;
  final String duration;
  final String? userTelegram;
  final double amount;
  final DateTime createdDate;
  final DateTime? activatedDate;
  final DateTime? endDate;
  final SubscriptionStatus status;
  final String? activatedBy;

  const Subscription({
    required this.code,
    required this.type,
    required this.duration,
    this.userTelegram,
    required this.amount,
    required this.createdDate,
    this.activatedDate,
    this.endDate,
    required this.status,
    this.activatedBy,
  });

  Subscription copyWith({
    String? code,
    SubscriptionType? type,
    String? duration,
    String? userTelegram,
    double? amount,
    DateTime? createdDate,
    DateTime? activatedDate,
    DateTime? endDate,
    SubscriptionStatus? status,
    String? activatedBy,
  }) {
    return Subscription(
      code: code ?? this.code,
      type: type ?? this.type,
      duration: duration ?? this.duration,
      userTelegram: userTelegram ?? this.userTelegram,
      amount: amount ?? this.amount,
      createdDate: createdDate ?? this.createdDate,
      activatedDate: activatedDate ?? this.activatedDate,
      endDate: endDate ?? this.endDate,
      status: status ?? this.status,
      activatedBy: activatedBy ?? this.activatedBy,
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    
    return other is Subscription &&
        other.code == code &&
        other.type == type &&
        other.duration == duration &&
        other.userTelegram == userTelegram &&
        other.amount == amount &&
        other.createdDate == createdDate &&
        other.activatedDate == activatedDate &&
        other.endDate == endDate &&
        other.status == status &&
        other.activatedBy == activatedBy;
  }

  @override
  int get hashCode {
    return code.hashCode ^
        type.hashCode ^
        duration.hashCode ^
        userTelegram.hashCode ^
        amount.hashCode ^
        createdDate.hashCode ^
        activatedDate.hashCode ^
        endDate.hashCode ^
        status.hashCode ^
        activatedBy.hashCode;
  }

  @override
  String toString() {
    return 'Subscription(code: $code, type: $type, duration: $duration, userTelegram: $userTelegram, amount: $amount, createdDate: $createdDate, activatedDate: $activatedDate, endDate: $endDate, status: $status, activatedBy: $activatedBy)';
  }
}