import '../entities/subscription.dart';
import '../entities/subscription_state.dart';

abstract class SubscriptionRepository {
  /// Validates and activates a subscription code for the given user
  /// Throws an exception if the code is invalid, already used, or expired
  Future<Subscription> validateSubscriptionCode(String code, String userId);

  /// Checks the current subscription status for a user
  /// Returns the subscription state including all user subscriptions and current status
  Future<SubscriptionState> checkSubscriptionStatus(String userId);
}