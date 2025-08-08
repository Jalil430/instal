import '../../domain/entities/subscription_state.dart';

abstract class SubscriptionLocalDataSource {
  /// Caches the subscription state for a user
  Future<void> cacheSubscriptionState(String userId, SubscriptionState state);

  /// Gets the cached subscription state for a user
  /// Returns null if no cached state exists or if cache has expired
  Future<SubscriptionState?> getCachedSubscriptionState(String userId);

  /// Clears the cached subscription state for a user
  Future<void> clearSubscriptionCache(String userId);

  /// Clears all cached subscription data
  Future<void> clearAllCache();
}