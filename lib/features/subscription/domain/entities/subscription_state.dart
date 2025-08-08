import 'subscription.dart';

enum UserSubscriptionStatus { newUser, hasExpired, hasActive }

class SubscriptionState {
  final bool hasActiveSubscription;
  final List<Subscription> userSubscriptions;
  final SubscriptionType? currentType;
  final DateTime? currentEndDate;
  final UserSubscriptionStatus userStatus;

  const SubscriptionState({
    required this.hasActiveSubscription,
    required this.userSubscriptions,
    this.currentType,
    this.currentEndDate,
    required this.userStatus,
  });

  SubscriptionState copyWith({
    bool? hasActiveSubscription,
    List<Subscription>? userSubscriptions,
    SubscriptionType? currentType,
    DateTime? currentEndDate,
    UserSubscriptionStatus? userStatus,
  }) {
    return SubscriptionState(
      hasActiveSubscription: hasActiveSubscription ?? this.hasActiveSubscription,
      userSubscriptions: userSubscriptions ?? this.userSubscriptions,
      currentType: currentType ?? this.currentType,
      currentEndDate: currentEndDate ?? this.currentEndDate,
      userStatus: userStatus ?? this.userStatus,
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    
    return other is SubscriptionState &&
        other.hasActiveSubscription == hasActiveSubscription &&
        other.userSubscriptions == userSubscriptions &&
        other.currentType == currentType &&
        other.currentEndDate == currentEndDate &&
        other.userStatus == userStatus;
  }

  @override
  int get hashCode {
    return hasActiveSubscription.hashCode ^
        userSubscriptions.hashCode ^
        currentType.hashCode ^
        currentEndDate.hashCode ^
        userStatus.hashCode;
  }

  @override
  String toString() {
    return 'SubscriptionState(hasActiveSubscription: $hasActiveSubscription, userSubscriptions: $userSubscriptions, currentType: $currentType, currentEndDate: $currentEndDate, userStatus: $userStatus)';
  }
}