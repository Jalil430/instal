import '../entities/subscription_state.dart';
import '../repositories/subscription_repository.dart';
import '../exceptions/subscription_exceptions.dart';

class CheckSubscriptionStatus {
  final SubscriptionRepository repository;

  const CheckSubscriptionStatus(this.repository);

  /// Checks the current subscription status for a user
  /// 
  /// Parameters:
  /// - [userId]: The ID of the user to check subscription status for
  /// 
  /// Returns the current subscription state including:
  /// - Whether the user has an active subscription
  /// - All subscription codes tied to the user
  /// - Current subscription type and end date
  /// - User subscription status (new, expired, or active)
  /// 
  /// The server determines expiration based on server-side time to prevent
  /// client-side time manipulation.
  /// 
  /// Throws:
  /// - [NetworkException] if there's a network error
  Future<SubscriptionState> call(String userId) async {
    if (userId.trim().isEmpty) {
      throw ArgumentError('User ID cannot be empty');
    }

    final state = await repository.checkSubscriptionStatus(userId);
    return state;
  }
}