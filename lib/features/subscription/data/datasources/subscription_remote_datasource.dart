import '../models/subscription_model.dart';

abstract class SubscriptionRemoteDataSource {
  /// Validates and activates a subscription code
  /// Returns the activated subscription with server-calculated dates
  Future<SubscriptionModel> validateCode(String code, String userId);

  /// Gets all subscription codes for a specific user
  /// Returns a list of subscriptions tied to the user ID
  Future<List<SubscriptionModel>> getUserSubscriptions(String userId);
}