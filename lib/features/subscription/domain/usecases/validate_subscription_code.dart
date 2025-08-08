import '../entities/subscription.dart';
import '../repositories/subscription_repository.dart';
import '../exceptions/subscription_exceptions.dart';

class ValidateSubscriptionCode {
  final SubscriptionRepository repository;

  const ValidateSubscriptionCode(this.repository);

  /// Validates and activates a subscription code for the given user
  /// 
  /// Parameters:
  /// - [code]: The subscription code to validate
  /// - [userId]: The ID of the user activating the code
  /// 
  /// Returns the activated subscription with server-calculated dates
  /// 
  /// Throws:
  /// - [InvalidCodeException] if the code doesn't exist or is malformed
  /// - [CodeAlreadyUsedException] if the code has already been activated
  /// - [ExpiredCodeException] if the code has expired
  /// - [NetworkException] if there's a network error
  Future<Subscription> call(String code, String userId) async {
    if (code.trim().isEmpty) {
      throw ArgumentError('Subscription code cannot be empty');
    }
    
    if (userId.trim().isEmpty) {
      throw ArgumentError('User ID cannot be empty');
    }

    return await repository.validateSubscriptionCode(code.trim(), userId);
  }
}